@preconcurrency import AppKit
@preconcurrency import ApplicationServices
@preconcurrency import CoreGraphics
@preconcurrency import ServiceManagement

@MainActor
private final class OverlayWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

private func openPlaneCommandTabEventTapCallback(
  proxy: CGEventTapProxy,
  type: CGEventType,
  event: CGEvent,
  userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let userInfo else { return Unmanaged.passUnretained(event) }
  let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()

  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    MainActor.assumeIsolated { appDelegate.reenableCommandTabEventTap() }
    return Unmanaged.passUnretained(event)
  }

  if MainActor.assumeIsolated({ OverviewShortcutController.shared.isRecording }) {
    return Unmanaged.passUnretained(event)
  }
  MainActor.assumeIsolated { appDelegate.handleRightCommand(type: type, event: event) }
  guard UserDefaults.standard.bool(forKey: OpenPlanePreferences.useCommandTabShortcut),
    ShortcutMatcher.isCommandTab(
    keyCode: event.getIntegerValueField(.keyboardEventKeycode),
    flags: event.flags
  ) else { return Unmanaged.passUnretained(event) }

  if type == .keyDown,
    event.getIntegerValueField(.keyboardEventAutorepeat) == 0
  {
    MainActor.assumeIsolated { appDelegate.handleShortcut() }
  }
  return nil
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, CanvasViewDelegate {
  private let windowService = WindowService()
  private let previewCache = PreviewCache()
  private let canvasView = CanvasView(frame: .zero)
  private lazy var workspaceView = CanvasWorkspaceView(canvas: canvasView)
  private let permissionView = PermissionView(frame: .zero)

  private var overlayWindow: NSWindow!
  private var nodesByID: [CGWindowID: WindowNode] = [:]
  private var stateMachine = CanvasStateMachine()
  private var lastOverviewCamera = CameraState()
  private var pendingLaunchesByBundle: [String: PendingLaunch] = [:]
  private let closeDialogObserver = CloseDialogObserver()
  private var closeDialogTask: Task<Void, Never>?
  private var pendingQuitSuppressions: [pid_t: PendingQuitWindowSuppression] = [:]
  private var requestedLaunchAnchors: [String: CGPoint] = [:]
  private var lastFocusedByBundle: [String: CGWindowID] = [:]
  private let windowFocusObserver = WindowFocusObserver()
  private var overviewGeneration = 0
  private var inventoryTracker = WindowInventoryTracker()
  private var isReconcilingWindows = false
  private var requestedCloseIDs: Set<CGWindowID> = [] {
    didSet { canvasView.closingWindowIDs = requestedCloseIDs }
  }
  private var confirmedClosedIDs: Set<CGWindowID> = []
  private let closedWindowProbe = ClosedWindowProbe()
  private var closeRefreshTask: Task<Void, Never>?
  private var didInitialLayout = false
  private var isReturning = false
  private var isDismissing = false
  private var isOpeningCanvas = false
  private var overviewReturnWindowID: CGWindowID?
  private var overviewReturnBundleIdentifier: String?
  private var lastActualWindowID: CGWindowID?
  private var activatedFocusWindowID: CGWindowID?

  private var inventoryTask: Task<Void, Never>?
  private var previewTask: Task<Void, Never>?
  private var previewScheduler = PreviewRefreshScheduler()
  private var permissionTimer: Timer?
  private var globalSwipeMonitor: Any?
  private var localKeyMonitor: Any?
  private var rightCommandTap = RightCommandTap()
  private var rightCommandQueue = ToggleParityQueue()
  private var chromeTabTask: Task<Void, Never>?
  private var commandTabEventTap: CFMachPort?
  private var commandTabRunLoopSource: CFRunLoopSource?

  func applicationDidFinishLaunching(_ notification: Notification) {
    buildMenu()
    buildOverlayWindow()
    configurePermissionView()
    windowFocusObserver.onFocus = { [weak self] id in
      self?.lastActualWindowID = id
      self?.canvasView.recentWindows.used(id)
    }
    canvasView.onModeChange = { [weak self] in
      self?.overviewGeneration += 1
    }
    observeWorkspace()
    windowFocusObserver.observeFrontmost()
    installShortcut()

    if UserDefaults.standard.bool(forKey: "didCompleteOnboarding")
      && permissionState.requiredAccessGranted
    {
      canvasView.showLaunchSplash(for: 2.5)
      showCanvas()
    } else {
      showPermissions()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    if stateMachine.mode != .overview {
      canvasView.camera = lastOverviewCamera
    }
    canvasView.persistState()
    stopCanvasLoops()
    permissionTimer?.invalidate()
    OverviewShortcutController.shared.stop()
    if let globalSwipeMonitor { NSEvent.removeMonitor(globalSwipeMonitor) }
    globalSwipeMonitor = nil
    if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
    removeCommandTabEventTap()
    closeDialogTask?.cancel()
    windowFocusObserver.stop()
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    guard overlayWindow != nil, !overlayWindow.isVisible else { return }
    showCanvas()
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showCanvas()
    return true
  }

  func canvasViewDidCancelFocusTransition(_ canvasView: CanvasView) {
    guard case .focusing = stateMachine.mode else { return }
    activatedFocusWindowID = nil
    stateMachine.returnToOverview()
    overlayWindow.alphaValue = 1
    overlayWindow.makeKeyAndOrderFront(nil)
    overlayWindow.makeFirstResponder(canvasView)
    NSApp.activate(ignoringOtherApps: true)
    startCanvasLoops()
    DispatchQueue.main.async { [weak self] in self?.drainRightCommandQueue() }
  }

  func canvasView(_ canvasView: CanvasView, didRequestFocus node: WindowNode) {
    focus(node)
  }

  func canvasView(_ canvasView: CanvasView, didRequestQuit node: WindowNode) {
    trackClosingWindows(Set(nodesByID.values.filter { $0.processID == node.processID }.map(\.id)))
    revealCloseConfirmation(for: node.processID)
    pendingQuitSuppressions[node.processID] = PendingQuitWindowSuppression(
      knownWindowIDs: Set(nodesByID.values.lazy.filter { $0.processID == node.processID }.map(\.id)),
      deadline: Date().addingTimeInterval(5)
    )
    guard NSRunningApplication(processIdentifier: node.processID)?.terminate() == true else {
      pendingQuitSuppressions[node.processID] = nil
      canvasView.statusMessage = "Couldn’t close \(node.applicationName)"
      return
    }
    canvasView.statusMessage = nil
  }

  func canvasView(
    _ canvasView: CanvasView,
    didRequestLaunch bundleIdentifier: String,
    applicationName: String,
    at anchor: CGPoint
  ) {
    guard
      let applicationURL = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: bundleIdentifier
      ),
      FileManager.default.fileExists(atPath: applicationURL.path)
    else {
      canvasView.showLaunchError(for: bundleIdentifier, message: "App unavailable")
      return
    }

    // A running app can have no windows. Reopen it and wait for a real window
    // before hiding the canvas; activation alone only changes the menu bar.
    requestedLaunchAnchors[bundleIdentifier] = anchor
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    configuration.addsToRecentItems = false
    NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) {
      [weak self] application, error in
      Task { @MainActor in
        guard let self else { return }
        if let error {
          self.requestedLaunchAnchors[bundleIdentifier] = nil
          canvasView.showLaunchError(
            for: bundleIdentifier,
            message: "Couldn’t open \(applicationName): \(error.localizedDescription)"
          )
        } else if let application {
          if let node = self.nodesByID.values.first(where: {
            $0.bundleIdentifier == bundleIdentifier
          }) {
            self.requestedLaunchAnchors[bundleIdentifier] = nil
            self.focus(node)
          } else {
            self.beginPendingLaunch(for: application, anchor: anchor)
          }
        }
      }
    }
  }

  func canvasView(_ canvasView: CanvasView, didRequestCloseWindow id: CGWindowID) {
    if let node = nodesByID[id] { revealCloseConfirmation(for: node.processID) }
    trackClosingWindows([id])
  }

  private func trackClosingWindows(_ ids: Set<CGWindowID>) {
    requestedCloseIDs.formUnion(ids)
    closeRefreshTask?.cancel()
    closeRefreshTask = Task { [weak self] in
      for _ in 0..<50 {
        guard let self, !Task.isCancelled else { return }
        let references = requestedCloseIDs.compactMap { id -> ClosingWindowReference? in
          guard let node = nodesByID[id], let element = node.accessibilityElement else { return nil }
          return ClosingWindowReference(id: id, processID: node.processID, element: element)
        }
        let removed = await closedWindowProbe.confirmedClosed(references)
        guard !Task.isCancelled else { return }
        if !removed.isEmpty {
          confirmedClosedIDs.formUnion(removed)
          requestedCloseIDs.subtract(removed)
          for id in removed { nodesByID[id] = nil }
          publishNodes()
          canvasView.applyPreviewSizePreference(fitAll: false)
        }
        if requestedCloseIDs.isEmpty { break }
        try? await Task.sleep(for: .milliseconds(100))
      }
      guard let self, !Task.isCancelled else { return }
      requestedCloseIDs.removeAll()
      closeRefreshTask = nil
    }
  }

  private func revealCloseConfirmation(for processID: pid_t) {
    closeDialogTask?.cancel()
    let generation = overviewGeneration
    closeDialogTask = Task { [weak self] in
      for _ in 0..<20 {
        guard let self, !Task.isCancelled, generation == overviewGeneration,
          isShowingCanvas, stateMachine.mode == .overview else { return }
        let hasDialog = await closeDialogObserver.state(processID: processID)
        guard !Task.isCancelled, generation == overviewGeneration,
          isShowingCanvas, stateMachine.mode == .overview else { return }
        if hasDialog == .present, let application = NSRunningApplication(processIdentifier: processID) {
          overviewGeneration += 1
          canvasView.cancelLayoutAnimation()
          stopCanvasLoops()
          overlayWindow.orderOut(nil)
          application.activate(options: [])
          let returnGeneration = overviewGeneration
          var absentChecks = 0
          while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, overviewGeneration == returnGeneration,
              !isShowingCanvas else { return }
            let running = NSRunningApplication(processIdentifier: processID)
            let dialogState = await closeDialogObserver.state(processID: processID)
            guard !Task.isCancelled, overviewGeneration == returnGeneration,
              !isShowingCanvas else { return }
            if running?.isTerminated != false {
              absentChecks = 2
            } else {
              let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
              guard frontmost == processID || frontmost == ProcessInfo.processInfo.processIdentifier else { return }
              absentChecks = dialogState == .absent ? absentChecks + 1 : 0
            }
            if absentChecks >= 2 {
              await reconcileWindows(allowHidden: true)
              guard !Task.isCancelled, overviewGeneration == returnGeneration,
                !isShowingCanvas else { return }
              showCanvas()
              return
            }
          }
          return
        }
        try? await Task.sleep(for: .milliseconds(150))
      }
    }
  }

  func canvasView(_ canvasView: CanvasView, setCommandTabShortcut enabled: Bool) -> Bool {
    configureCommandTabEventTap(enabled: enabled)
  }

  func canvasView(_ canvasView: CanvasView, setRightCommandShortcut enabled: Bool) -> Bool {
    let old = UserDefaults.standard.bool(forKey: "useRightCommandShortcut")
    UserDefaults.standard.set(enabled, forKey: "useRightCommandShortcut")
    let success = configureCommandTabEventTap(enabled:
      UserDefaults.standard.bool(forKey: OpenPlanePreferences.useCommandTabShortcut))
    if !success { UserDefaults.standard.set(old, forKey: "useRightCommandShortcut") }
    return success
  }

  fileprivate func handleRightCommand(type: CGEventType, event: CGEvent) {
    guard UserDefaults.standard.bool(forKey: "useRightCommandShortcut") else { return }
    if rightCommandTap.handle(type: type,
      keyCode: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags) {
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        rightCommandQueue.recordPress()
        drainRightCommandQueue()
      }
    }
  }

  private func drainRightCommandQueue() {
    let focusing: Bool
    if case .focusing = stateMachine.mode { focusing = true } else { focusing = false }
    guard rightCommandQueue.consume(isTransitioning:
      focusing || isOpeningCanvas || isReturning || isDismissing) else { return }
    if isShowingCanvas { returnToOverviewOrigin() }
    else { handleShortcut() }
  }

  func canvasView(_ canvasView: CanvasView, setPrivateBrowserPreviews enabled: Bool) {
    for node in nodesByID.values where node.isPrivateBrowsing
      || BrowserPrivacy.isBrowser(bundleIdentifier: node.bundleIdentifier, applicationName: node.applicationName) {
      if enabled {
        guard node.previewState == .redacted else { continue }
        node.previewState = .loading
        canvasView.setNeedsDisplay(for: [node.id])
      } else {
        redactPrivatePreview(node)
      }
    }
  }

  @objc private func showCanvasFromMenu() {
    showCanvas()
  }

  private var mainScreen: NSScreen { NSScreen.main ?? NSScreen.screens[0] }

  private var permissionState: PermissionState {
    let loginStatus = SMAppService.mainApp.status
    return PermissionState(
      screenRecording: CGPreflightScreenCaptureAccess(),
      accessibility: AXIsProcessTrusted(),
      loginItem: loginStatus == .enabled,
      loginRequiresApproval: loginStatus == .requiresApproval
    )
  }

  private func buildMenu() {
    let mainMenu = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    let showItem = NSMenuItem(
      title: "Show OpenPlane", action: #selector(showCanvasFromMenu), keyEquivalent: "")
    showItem.target = self
    appMenu.addItem(showItem)
    appMenu.addItem(.separator())
    let quitItem = NSMenuItem(
      title: "Quit OpenPlane", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    quitItem.target = NSApp
    appMenu.addItem(quitItem)
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)
    let editItem = NSMenuItem()
    editItem.title = "Edit"
    let editMenu = NSMenu(title: "Edit")
    for (title, action, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
      ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
      editMenu.addItem(NSMenuItem(title: title, action: NSSelectorFromString(action), keyEquivalent: key))
    }
    editItem.submenu = editMenu
    mainMenu.addItem(editItem)
    NSApp.mainMenu = mainMenu
  }

  private func buildOverlayWindow() {
    overlayWindow = OverlayWindow(
      contentRect: mainScreen.frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false,
      screen: mainScreen
    )
    overlayWindow.backgroundColor = .clear
    overlayWindow.isOpaque = false
    overlayWindow.hasShadow = false
    overlayWindow.acceptsMouseMovedEvents = true
    overlayWindow.animationBehavior = .none
    overlayWindow.level = .floating
    overlayWindow.collectionBehavior = [
      .moveToActiveSpace, .fullScreenAuxiliary, .stationary, .ignoresCycle,
    ]
    overlayWindow.title = "OpenPlane"
    overlayWindow.isReleasedWhenClosed = false
    canvasView.delegate = self
  }

  private func configurePermissionView() {
    permissionView.requestScreenRecording = { [weak self] in
      guard let self else { return }
      let granted = CGRequestScreenCaptureAccess()
      if !granted {
        openPrivacyPane("Privacy_ScreenCapture")
      }
      refreshPermissionsSoon()
    }
    permissionView.requestAccessibility = { [weak self] in
      guard let self else { return }
      let options =
        [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
      let granted = AXIsProcessTrustedWithOptions(options)
      if !granted {
        openPrivacyPane("Privacy_Accessibility")
      }
      refreshPermissionsSoon()
    }
    permissionView.enableLoginItem = { [weak self] in
      guard let self else { return }
      if SMAppService.mainApp.status == .requiresApproval {
        SMAppService.openSystemSettingsLoginItems()
      } else {
        do {
          try SMAppService.mainApp.register()
          permissionView.show(error: nil)
        } catch {
          permissionView.show(error: error.localizedDescription)
        }
      }
      refreshPermissionView()
    }
    permissionView.continueAction = { [weak self] in
      guard let self, permissionState.requiredAccessGranted else { return }
      UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
      permissionTimer?.invalidate()
      installShortcut()
      showCanvas()
    }
  }

  private func showPermissions() {
    stopCanvasLoops()
    configureWindowForOnboarding()
    overlayWindow.contentView = permissionView
    refreshPermissionView()
    overlayWindow.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    permissionTimer?.invalidate()
    permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.refreshPermissionView() }
    }
  }

  private func refreshPermissionView() {
    permissionView.update(permissionState)
  }

  private func refreshPermissionsSoon() {
    refreshPermissionView()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      self?.refreshPermissionView()
    }
  }

  private func openPrivacyPane(_ pane: String) {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
      ),
      NSWorkspace.shared.open(url)
    else {
      permissionView.show(error: "Open System Settings → Privacy & Security to grant access.")
      return
    }
    permissionView.show(error: nil)
  }

  private func configureWindowForOnboarding() {
    overlayWindow.level = .normal
    overlayWindow.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
    overlayWindow.titleVisibility = .hidden
    overlayWindow.titlebarAppearsTransparent = true
    overlayWindow.isMovable = true
    overlayWindow.isMovableByWindowBackground = true
    overlayWindow.collectionBehavior = [.moveToActiveSpace]

    let available = mainScreen.visibleFrame
    let size = CGSize(width: min(700, available.width), height: min(610, available.height))
    let frame = CGRect(
      x: available.midX - size.width / 2,
      y: available.midY - size.height / 2,
      width: size.width,
      height: size.height
    )
    overlayWindow.setFrame(frame, display: true)
  }

  private func configureWindowForCanvas() {
    overlayWindow.styleMask = .borderless
    overlayWindow.titleVisibility = .hidden
    overlayWindow.titlebarAppearsTransparent = false
    overlayWindow.isMovable = false
    overlayWindow.isMovableByWindowBackground = false
    overlayWindow.level = .floating
    overlayWindow.collectionBehavior = [
      .moveToActiveSpace, .fullScreenAuxiliary, .stationary, .ignoresCycle,
    ]
    overlayWindow.setFrame(mainScreen.frame, display: true)
  }

  private func rememberOverviewOrigin() {
    let application = NSWorkspace.shared.frontmostApplication
    if let application, application.processIdentifier != ProcessInfo.processInfo.processIdentifier {
      overviewReturnBundleIdentifier = application.bundleIdentifier
      overviewReturnWindowID = windowService.frontmostWindowID(among:
        nodesByID.values.filter { $0.processID == application.processIdentifier })
    } else if let id = lastActualWindowID, let node = nodesByID[id] {
      overviewReturnWindowID = id
      overviewReturnBundleIdentifier = node.bundleIdentifier
    }
  }

  func canvasViewDidRequestReturnToOrigin(_ canvasView: CanvasView) {
    returnToOverviewOrigin()
  }

  private func returnToOverviewOrigin() {
    guard isShowingCanvas, stateMachine.mode == .overview else { return }
    let target = overviewReturnWindowID.flatMap { nodesByID[$0] }
      ?? overviewReturnBundleIdentifier.flatMap { preferredNode(for: $0) }
    guard let target else {
      canvasView.statusMessage = "The previous window is no longer open"
      return
    }
    canvasView.cancelLayoutAnimation()
    canvasView.dismissSearch()
    focus(target)
  }

  private func showCanvas() {
    guard !isOpeningCanvas else { return }
    guard permissionState.requiredAccessGranted else {
      showPermissions()
      return
    }
    permissionTimer?.invalidate()
    if !isShowingCanvas { rememberOverviewOrigin() }
    if canvasView.usesAutomaticLayout {
      if isShowingCanvas {
        overlayWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return
      }
      windowFocusObserver.recordFrontmost()
      isOpeningCanvas = true
      overviewGeneration += 1
      let generation = overviewGeneration
      configureWindowForCanvas()
      overlayWindow.contentView = workspaceView
      canvasView.closeCatalog()
      canvasView.cancelLayoutAnimation()
      stateMachine.returnToOverview()
      Task { [weak self] in
        guard let self else { return }
        await reconcileWindows(allowHidden: true)
        guard overviewGeneration == generation, isOpeningCanvas else { return }
        canvasView.prepareChronologicalOverview()
        let desktopTop = NSScreen.screens.first?.frame.maxY ?? mainScreen.frame.maxY
        let starts = Dictionary(uniqueKeysWithValues: nodesByID.values.map { node in
          (node.id, CGRect(x: node.sourceFrame.minX - mainScreen.frame.minX,
            y: desktopTop - node.sourceFrame.maxY - mainScreen.frame.minY,
            width: node.sourceFrame.width, height: node.sourceFrame.height))
        })
        canvasView.layoutSubtreeIfNeeded()
        let frontToBack = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
          kCGNullWindowID) as? [[String: Any]] ?? []).compactMap {
            ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value
          }.filter { starts[$0] != nil }
        canvasView.animateOverviewEntry(from: starts, frontToBack: frontToBack,
          duration: OpenPlanePreferences.transitionDuration(0.45))
        overlayWindow.alphaValue = 1
        overlayWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isOpeningCanvas = false
        startCanvasLoops()
        drainRightCommandQueue()
      }
      return
    }
    configureWindowForCanvas()
    overlayWindow.contentView = workspaceView

    switch stateMachine.mode {
    case .working(let id):
      returnFromWorkingWindow(id: id)
    case .overview:
      overlayWindow.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      startCanvasLoops()
    case .focusing:
      break
    }
  }

  private func dismissCanvas() {
    if isOpeningCanvas {
      overviewGeneration += 1
      isOpeningCanvas = false
      drainRightCommandQueue()
      return
    }
    guard isShowingCanvas, !isDismissing else { return }
    overviewGeneration += 1
    canvasView.dismissSettings()
    isDismissing = true
    stopCanvasLoops()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.2
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      overlayWindow.animator().alphaValue = 0
    } completionHandler: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.overlayWindow.orderOut(nil)
        self.overlayWindow.alphaValue = 1
        self.isDismissing = false
        NSApp.hide(nil)
        self.drainRightCommandQueue()
      }
    }
  }

  private func returnFromWorkingWindow(id: CGWindowID) {
    guard !isReturning else { return }
    isReturning = true
    stopCanvasLoops()
    Task { [weak self] in
      guard let self else { return }
      let node = nodesByID[id]
      var target = lastOverviewCamera
      if let node {
        canvasView.selectedWindowID = node.id
        if shouldRedactPrivatePreview(node) {
          redactPrivatePreview(node)
        } else {
          node.previewState = .loading
          canvasView.setNeedsDisplay(for: [node.id])
          do {
            let preview = try await windowService.capture(window: node.captureWindow)
            applyFreshPreview(preview, to: node)
          } catch WindowCaptureError.privateBrowsing {
            redactPrivatePreview(node)
          } catch {
            node.previewState = .failed
          }
        }
        if let geometry = windowService.geometry(of: node, on: mainScreen) {
          node.sourceFrame.size = geometry.size
          canvasView.applyPreviewSizePreference(fitAll: false)
          canvasView.camera = cameraAligning(node, with: geometry)
        }
        target.center = CGPoint(x: node.worldFrame.midX, y: node.worldFrame.midY)
        target.zoom = min(target.zoom, 0.78)
      }

      overlayWindow.alphaValue = 1
      overlayWindow.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      canvasView.animateCamera(to: target, duration: OpenPlanePreferences.transitionDuration(0.35)) { [weak self] in
        guard let self else { return }
        stateMachine.returnToOverview()
        lastOverviewCamera = target
        startCanvasLoops()
        isReturning = false
        drainRightCommandQueue()
      }
    }
  }

  private func focus(_ node: WindowNode) {
    canvasView.dismissSettings()
    canvasView.revealCatalogWindowForFocus(node.id)
    guard stateMachine.beginFocus(on: node.id) else { return }
    activatedFocusWindowID = nil
    canvasView.selectedWindowID = node.id
    lastOverviewCamera = canvasView.camera
    lastFocusedByBundle[node.bundleIdentifier] = node.id
    stopCanvasLoops()
    guard windowService.prepareForFocus(node) else {
      overlayWindow.orderOut(nil)
      windowService.activate(node)
      stateMachine.completeFocus(on: node.id)
      drainRightCommandQueue()
      return
    }

    let target =
      windowService.geometry(of: node, on: mainScreen).map {
        cameraAligning(node, with: $0)
      }
      ?? CameraState(
        center: CGPoint(x: node.worldFrame.midX, y: node.worldFrame.midY),
        zoom: min(
          node.sourceFrame.width / node.worldFrame.width,
          node.sourceFrame.height / node.worldFrame.height
        )
      )
    // Keep the real window fully covered until the preview reaches its exact frame.
    // The final phase crossfades two already aligned representations.
    let duration = OpenPlanePreferences.transitionDuration(0.6)
    let cameraCompletionFraction: CGFloat = 7 / 12
    let activationLeadFraction: CGFloat = 0.04
    overlayWindow.alphaValue = 1
    canvasView.animateCamera(
      to: target,
      tracking: CGPoint(x: node.worldFrame.midX, y: node.worldFrame.midY),
      isolating: node.id,
      duration: duration,
      cameraCompletionFraction: cameraCompletionFraction,
      progressHandler: { [weak self, weak node] progress in
        guard let self, let node else { return }
        if progress >= cameraCompletionFraction - activationLeadFraction,
          activatedFocusWindowID != node.id
        {
          activatedFocusWindowID = node.id
          windowService.activate(node)
        }
        overlayWindow.alphaValue = CanvasMath.focusOverlayOpacity(
          progress: progress,
          handoffStart: cameraCompletionFraction
        )
      }
    ) { [weak self, node] in
      guard let self else { return }
      if activatedFocusWindowID != node.id {
        windowService.activate(node)
      }
      activatedFocusWindowID = nil
      overlayWindow.orderOut(nil)
      canvasView.endFocusTransition(completed: true)
      stateMachine.completeFocus(on: node.id)
      drainRightCommandQueue()
    }
  }

  private func cameraAligning(_ node: WindowNode, with geometry: WindowGeometry) -> CameraState {
    let viewCenter = CGPoint(x: canvasView.bounds.midX, y: canvasView.bounds.midY)
    let realCenter = CGPoint(x: geometry.screenFrame.midX, y: geometry.screenFrame.midY)
    let zoom = min(
      geometry.screenFrame.width / node.worldFrame.width,
      geometry.screenFrame.height / node.worldFrame.height
    )
    return CameraState(
      center: CGPoint(
        x: node.worldFrame.midX - (realCenter.x - viewCenter.x) / zoom,
        y: node.worldFrame.midY - (realCenter.y - viewCenter.y) / zoom
      ),
      zoom: zoom
    )
  }

  private func startCanvasLoops() {
    guard inventoryTask == nil else { return }
    inventoryTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.reconcileWindows()
        try? await Task.sleep(for: .seconds(1))
      }
    }
    chromeTabTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.refreshChromeTabCounts()
        try? await Task.sleep(for: .seconds(2))
      }
    }
    previewTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.refreshVisiblePreviews()
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  private func stopCanvasLoops() {
    inventoryTask?.cancel()
    chromeTabTask?.cancel()
    chromeTabTask = nil
    previewTask?.cancel()
    inventoryTask = nil
    previewTask = nil
  }

  private func refreshChromeTabCounts() async {
    guard UserDefaults.standard.bool(forKey: ChromeTabCounter.preferenceKey) else { return }
    guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").count == 1
    else { canvasView.chromeTabCounts = [:]; return }
    let result = await ChromeTabCounter.shared.read()
    guard !Task.isCancelled,
      UserDefaults.standard.bool(forKey: ChromeTabCounter.preferenceKey) else { return }
    var counts: [CGWindowID: Int] = [:]
    if let result {
      for node in nodesByID.values where node.bundleIdentifier == "com.google.Chrome" {
        counts[node.id] = ChromeTabWindow.count(for: node.title, frame: node.sourceFrame, in: result)
      }
    } else {
      canvasView.statusMessage = "Chrome tab count unavailable. Check Chrome’s Automation permission in System Settings."
    }
    canvasView.chromeTabCounts = counts
  }

  private func reconcileWindows(allowHidden: Bool = false) async {
    guard (allowHidden || overlayWindow.isVisible), overlayWindow.contentView === workspaceView else { return }
    guard !isReconcilingWindows, !canvasView.defersBackgroundWork || !requestedCloseIDs.isEmpty else { return }
    isReconcilingWindows = true
    defer { isReconcilingWindows = false }
    do {
      let allDiscovered = try await windowService.discover(on: mainScreen)
      guard !Task.isCancelled, !canvasView.defersBackgroundWork || !requestedCloseIDs.isEmpty else { return }
      let now = Date()
      for (processID, var suppression) in pendingQuitSuppressions {
        let currentWindowIDs = Set(
          allDiscovered.lazy.filter { $0.processID == processID }.map(\.id)
        )
        if suppression.observe(currentWindowIDs: currentWindowIDs, now: now) {
          pendingQuitSuppressions[processID] = suppression
        } else {
          pendingQuitSuppressions[processID] = nil
        }
      }
      confirmedClosedIDs.formIntersection(Set(allDiscovered.map(\.id)))
      let discovered = allDiscovered.filter { item in
        !confirmedClosedIDs.contains(item.id) && (pendingQuitSuppressions[item.processID]?.allows(item.id) ?? true)
      }
      let discoveredIDs = Set(discovered.map(\.id))
      let previousIDs = Set(nodesByID.keys)
      let potentiallyMissingIDs = previousIDs.subtracting(discoveredIDs)
      let existingIDs = potentiallyMissingIDs.isEmpty
        ? Set<CGWindowID>() : await windowService.existingWindowIDs()
      guard !Task.isCancelled, !canvasView.defersBackgroundWork || !requestedCloseIDs.isEmpty else { return }
      let change = inventoryTracker.change(
        previous: previousIDs,
        current: discoveredIDs,
        existing: existingIDs,
        requestedCloseIDs: requestedCloseIDs
      )
      requestedCloseIDs.subtract(change.removed)
      nodesByID = nodesByID.filter { !change.removed.contains($0.key) }

      var newWindows: [DiscoveredWindow] = []
      var changedMetadataIDs: [CGWindowID] = []
      var needsPreviewSizeUpdate = false
      for item in discovered {
        if change.retained.contains(item.id), let node = nodesByID[item.id] {
          if node.applicationName != item.applicationName || node.title != item.title
            || node.isPrivateBrowsing != item.isPrivateBrowsing
            || (node.icon == nil) != (item.icon == nil)
          {
            changedMetadataIDs.append(item.id)
          }
          if node.sourceFrame.size != item.frame.size { needsPreviewSizeUpdate = true }
          node.update(from: item)
          if shouldRedactPrivatePreview(node) {
            redactPrivatePreview(node)
          } else if node.previewState == .redacted {
            node.previewState = .loading
          }
        } else if change.added.contains(item.id) {
          newWindows.append(item)
        }
      }

      let snapshots = discovered.map {
        WindowPlacementSnapshot(
          windowID: $0.id,
          bundleIdentifier: $0.bundleIdentifier,
          title: $0.title,
          center: .zero,
          size: $0.frame.size
        )
      }
      let restoredCenters = canvasView.restoredWindowCenters(for: snapshots)
      let requestedLaunchCenters = Dictionary(
        uniqueKeysWithValues: requestedLaunchAnchors.compactMap { bundleIdentifier, anchor in
          newWindows
            .filter { $0.bundleIdentifier == bundleIdentifier }
            .min(by: { $0.id < $1.id })
            .map { ($0.id, anchor) }
        }
      )

      if !didInitialLayout && !discovered.isEmpty {
        let sizes = canvasView.preferredPreviewSizes(for: discovered.map { $0.frame.size })
        let frames: [CGRect]
        if canvasView.hasManifestedAppPlacements {
          let items = Array(zip(discovered, sizes))
          var framesByID: [CGWindowID: CGRect] = [:]
          var occupied: [CGRect] = []
          for (item, size) in items {
            if let center = requestedLaunchCenters[item.id] ?? restoredCenters[item.id] {
              let frame = CGRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2,
                width: size.width,
                height: size.height
              )
              framesByID[item.id] = frame
              occupied.append(frame)
            }
          }
          for (item, size) in items where framesByID[item.id] == nil {
            let frame = CanvasMath.nearestAvailableFrame(
              size: size,
              centeredAt: placementAnchor(for: item),
              avoiding: occupied + canvasView.reservedAppFrames(
                excluding: item.bundleIdentifier
              )
            )
            framesByID[item.id] = frame
            occupied.append(frame)
          }
          frames = discovered.compactMap { framesByID[$0.id] }
        } else {
          frames = CanvasMath.gridFrames(for: sizes).map {
            $0.offsetBy(dx: canvasView.camera.center.x, dy: canvasView.camera.center.y)
          }
        }
        for (item, frame) in zip(discovered, frames) {
          nodesByID[item.id] = await makeNode(for: item, worldFrame: frame)
        }
        didInitialLayout = true
        canvasView.camera = canvasView.initialCamera(
          fitting: CanvasMath.fitCamera(frames: frames, in: canvasView.bounds)
        )
      } else {
        let orderedNewWindows = newWindows.sorted { lhs, rhs in
          let lhsHasCenter = requestedLaunchCenters[lhs.id] != nil
            || restoredCenters[lhs.id] != nil
          let rhsHasCenter = requestedLaunchCenters[rhs.id] != nil
            || restoredCenters[rhs.id] != nil
          if lhsHasCenter != rhsHasCenter { return lhsHasCenter }
          return lhs.id < rhs.id
        }
        for item in orderedNewWindows {
          let size = canvasView.preferredPreviewSizes(for: [item.frame.size])[0]
          let frame: CGRect
          if let center = requestedLaunchCenters[item.id] ?? restoredCenters[item.id] {
            frame = CGRect(
              x: center.x - size.width / 2,
              y: center.y - size.height / 2,
              width: size.width,
              height: size.height
            )
          } else {
            frame = CanvasMath.nearestAvailableFrame(
              size: size,
              centeredAt: placementAnchor(for: item),
              avoiding: nodesByID.values.map(\.worldFrame)
                + canvasView.reservedAppFrames(excluding: item.bundleIdentifier)
            )
          }
          nodesByID[item.id] = await makeNode(for: item, worldFrame: frame)
        }
      }
      if !didInitialLayout { didInitialLayout = true }

      let structureChanged = !change.removed.isEmpty || !newWindows.isEmpty
      if structureChanged {
        publishNodes()
      } else if !changedMetadataIDs.isEmpty {
        canvasView.refreshMetadata(for: changedMetadataIDs)
      }
      if structureChanged || needsPreviewSizeUpdate {
        canvasView.applyPreviewSizePreference(fitAll: false)
      }
      canvasView.statusMessage = nil
      resolvePendingLaunch(with: newWindows)
    } catch {
      canvasView.statusMessage = "Window access unavailable — \(error.localizedDescription)"
      if !CGPreflightScreenCaptureAccess() { showPermissions() }
    }
  }

  private func placementAnchor(for item: DiscoveredWindow) -> CGPoint {
    if let home = canvasView.manifestedAppHome(for: item.bundleIdentifier) {
      return home
    }
    if let pendingLaunch = pendingLaunchesByBundle[item.bundleIdentifier] {
      return pendingLaunch.anchor
    }
    if let id = lastFocusedByBundle[item.bundleIdentifier], let active = nodesByID[id] {
      return CGPoint(x: active.worldFrame.midX, y: active.worldFrame.midY)
    }
    return canvasView.camera.center
  }

  private func resolvePendingLaunch(with newWindows: [DiscoveredWindow]) {
    guard !pendingLaunchesByBundle.isEmpty else { return }
    var openedNodes: [WindowNode] = []
    var fallbackApplication: NSRunningApplication?

    for pendingLaunch in Array(pendingLaunchesByBundle.values) {
      if let item = newWindows.first(where: {
        !pendingLaunch.knownWindowIDs.contains($0.id)
          && ($0.processID == pendingLaunch.processID
            || $0.bundleIdentifier == pendingLaunch.bundleIdentifier)
      }), let node = nodesByID[item.id] {
        requestedLaunchAnchors[pendingLaunch.bundleIdentifier] = nil
        pendingLaunchesByBundle[pendingLaunch.bundleIdentifier] = nil
        openedNodes.append(node)
        continue
      }

      guard Date() >= pendingLaunch.deadline else { continue }
      pendingLaunchesByBundle[pendingLaunch.bundleIdentifier] = nil
      if requestedLaunchAnchors[pendingLaunch.bundleIdentifier] != nil {
        requestedLaunchAnchors[pendingLaunch.bundleIdentifier] = nil
        canvasView.showLaunchError(
          for: pendingLaunch.bundleIdentifier,
          message: "No window appeared"
        )
      } else {
        fallbackApplication = NSRunningApplication(
          processIdentifier: pendingLaunch.processID
        )
      }
    }

    if let node = canvasView.selectedWindowID.flatMap({ selectedID in
      openedNodes.first { $0.id == selectedID }
    }) ?? openedNodes.last {
      focus(node)
    } else if let fallbackApplication {
      overlayWindow.orderOut(nil)
      stopCanvasLoops()
      fallbackApplication.activate(options: [])
    }
  }

  private func refreshVisiblePreviews() async {
    guard overlayWindow.isVisible, overlayWindow.contentView === workspaceView else { return }
    guard !canvasView.defersBackgroundWork else { return }
    let visibleIDs = canvasView.visibleWindowIDs()
    let refreshIDs = previewScheduler.nextIDs(
      from: visibleIDs,
      selectedID: canvasView.selectedWindowID,
      limit: 2
    )
    let nodes = refreshIDs.compactMap { nodesByID[$0] }

    // ponytail: update the focused preview continuously and rotate one background preview per tick.
    let evenNodes = stride(from: 0, to: nodes.count, by: 2).map { nodes[$0] }
    let oddNodes = stride(from: 1, to: nodes.count, by: 2).map { nodes[$0] }
    async let even = capturePreviews(evenNodes)
    async let odd = capturePreviews(oddNodes)
    let refreshed = await (even, odd)
    if refreshed.0 || refreshed.1 { canvasView.setNeedsDisplay(for: refreshIDs) }
  }

  private func capturePreviews(_ nodes: [WindowNode]) async -> Bool {
    var didChange = false
    for node in nodes where !Task.isCancelled {
      guard !requestedCloseIDs.contains(node.id), nodesByID[node.id] === node else { continue }
      guard !canvasView.defersBackgroundWork else { break }
      if shouldRedactPrivatePreview(node) {
        redactPrivatePreview(node)
        didChange = true
        continue
      }
      if node.previewState == .redacted { node.previewState = .loading }
      let previousState = node.previewState
      let loadingIndicatorTask = Task { [weak self, weak node] in
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled, let self, let node,
          !self.requestedCloseIDs.contains(node.id), self.nodesByID[node.id] === node else { return }
        node.previewState = .loading
        canvasView.setNeedsDisplay(for: [node.id])
      }
      do {
        let preview = try await windowService.capture(
          window: node.captureWindow,
          targetLongEdgePixels: canvasView.previewPixelLength(for: node)
        )
        loadingIndicatorTask.cancel()
        guard !requestedCloseIDs.contains(node.id), nodesByID[node.id] === node else { continue }
        guard !canvasView.defersBackgroundWork else {
          node.previewState = previousState
          continue
        }
        applyFreshPreview(preview, to: node)
      } catch WindowCaptureError.privateBrowsing {
        loadingIndicatorTask.cancel()
        redactPrivatePreview(node)
      } catch {
        loadingIndicatorTask.cancel()
        guard !requestedCloseIDs.contains(node.id), nodesByID[node.id] === node else { continue }
        if shouldRedactPrivatePreview(node) {
          redactPrivatePreview(node)
        } else {
          node.previewState = .failed
        }
      }
      didChange = true
    }
    return didChange
  }

  private func makeNode(for item: DiscoveredWindow, worldFrame: CGRect) async -> WindowNode {
    if BrowserPrivacy.shouldSuppressPreview(bundleIdentifier: item.bundleIdentifier,
      applicationName: item.applicationName, isPrivateBrowsing: item.isPrivateBrowsing,
      allowsPrivatePreviews: !protectsPrivateBrowserPreviews) {
      await previewCache.remove(windowID: item.id, bundleIdentifier: item.bundleIdentifier)
      let node = WindowNode(discovered: item, worldFrame: worldFrame)
      node.previewState = .redacted
      return node
    }
    if item.isPrivateBrowsing || BrowserPrivacy.isBrowser(bundleIdentifier: item.bundleIdentifier,
      applicationName: item.applicationName) {
      return WindowNode(discovered: item, worldFrame: worldFrame)
    }
    let data = await previewCache.loadData(
      windowID: item.id,
      bundleIdentifier: item.bundleIdentifier
    )
    return WindowNode(
      discovered: item,
      worldFrame: worldFrame,
      cachedPreview: data.flatMap(NSImage.init(data:))
    )
  }

  private func applyFreshPreview(_ preview: CapturedPreview, to node: WindowNode) {
    guard !requestedCloseIDs.contains(node.id), nodesByID[node.id] === node else { return }
    guard !shouldRedactPrivatePreview(node) else {
      redactPrivatePreview(node)
      return
    }
    canvasView.replacePreview(
      NSImage(cgImage: preview.image, size: preview.size),
      for: node
    )
    node.previewState = .current

    guard !node.isPrivateBrowsing,
      !BrowserPrivacy.isBrowser(bundleIdentifier: node.bundleIdentifier, applicationName: node.applicationName)
    else { return }
    let now = Date()
    guard
      node.lastPreviewCacheWrite.map({ now.timeIntervalSince($0) >= 60 }) ?? true
    else { return }

    node.lastPreviewCacheWrite = now
    let windowID = node.id
    let bundleIdentifier = node.bundleIdentifier
    Task {
      await previewCache.store(
        image: preview.image,
        windowID: windowID,
        bundleIdentifier: bundleIdentifier
      )
    }
  }

  private var protectsPrivateBrowserPreviews: Bool {
    !UserDefaults.standard.bool(forKey: OpenPlanePreferences.showPrivateBrowserPreviews)
  }

  private func shouldRedactPrivatePreview(_ node: WindowNode) -> Bool {
    BrowserPrivacy.shouldSuppressPreview(bundleIdentifier: node.bundleIdentifier,
      applicationName: node.applicationName, isPrivateBrowsing: node.isPrivateBrowsing,
      allowsPrivatePreviews: !protectsPrivateBrowserPreviews)
  }

  private func redactPrivatePreview(_ node: WindowNode) {
    guard shouldRedactPrivatePreview(node) else { return }
    let needsCacheRemoval = node.previewState != .redacted || node.preview != nil
    node.previewState = .redacted
    canvasView.clearPreview(for: node)
    guard needsCacheRemoval else { return }
    let windowID = node.id
    let bundleIdentifier = node.bundleIdentifier
    Task {
      await previewCache.remove(windowID: windowID, bundleIdentifier: bundleIdentifier)
    }
  }

  private func observeWorkspace() {
    let center = NSWorkspace.shared.notificationCenter
    center.addObserver(
      self, selector: #selector(workspaceDidLaunch(_:)),
      name: NSWorkspace.didLaunchApplicationNotification, object: nil)
    center.addObserver(
      self, selector: #selector(workspaceDidActivate(_:)),
      name: NSWorkspace.didActivateApplicationNotification, object: nil)
    center.addObserver(
      self, selector: #selector(workspaceDidTerminate(_:)),
      name: NSWorkspace.didTerminateApplicationNotification, object: nil)
  }

  @objc private func workspaceDidLaunch(_ notification: Notification) {
    guard isShowingCanvas, let application = workspaceApplication(from: notification),
      shouldFollow(application)
    else { return }
    beginPendingLaunch(for: application)
  }

  @objc private func workspaceDidActivate(_ notification: Notification) {
    windowFocusObserver.observeFrontmost()
    guard isShowingCanvas, let application = workspaceApplication(from: notification),
      shouldFollow(application)
    else { return }
    if !WorkspaceActivationPolicy.shouldFollow(
      bundleIdentifier: application.bundleIdentifier,
      requestedLaunches: Set(requestedLaunchAnchors.keys)
    ) {
      return
    }
    let candidates = nodesByID.values.filter {
      $0.processID == application.processIdentifier
        || $0.bundleIdentifier == application.bundleIdentifier
    }
    if let remembered = application.bundleIdentifier.flatMap({ lastFocusedByBundle[$0] }),
      let node = nodesByID[remembered], candidates.contains(where: { $0.id == node.id })
    {
      focus(node)
    } else if let frontmostID = windowService.frontmostWindowID(among: candidates),
      let node = nodesByID[frontmostID]
    {
      focus(node)
    } else if let node = candidates.first {
      focus(node)
    } else if let bundleIdentifier = application.bundleIdentifier,
      pendingLaunchesByBundle[bundleIdentifier] == nil
    {
      beginPendingLaunch(for: application)
    }
  }

  @objc private func workspaceDidTerminate(_ notification: Notification) {
    guard let application = workspaceApplication(from: notification) else { return }
    pendingQuitSuppressions[application.processIdentifier] = nil
    let removedIDs = nodesByID.values.filter { $0.processID == application.processIdentifier }.map(
      \.id)
    for id in removedIDs { nodesByID[id] = nil }
    publishNodes()

    if case .working(let id) = stateMachine.mode, removedIDs.contains(id) {
      stateMachine.returnToOverview()
      showCanvas()
    }
  }

  private var isShowingCanvas: Bool {
    overlayWindow.isVisible && overlayWindow.contentView === workspaceView
      && stateMachine.mode == .overview
  }

  private func publishNodes() {
    let order = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
      as? [[String: Any]] ?? []).compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
    let ranks = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
    let nodes = nodesByID.values.sorted {
      let a = ranks[$0.id] ?? Int.max, b = ranks[$1.id] ?? Int.max
      return a == b ? $0.id < $1.id : a < b
    }
    canvasView.recentWindows.updateInventory(nodes.map(\.id))
    canvasView.nodes = nodes.sorted { $0.id < $1.id }
    guard !canvasView.hasCanvasSelection else { return }
    canvasView.selectedWindowID = windowService.frontmostWindowID(among: nodes) ?? nodes.first?.id
  }

  private func preferredNode(for bundleIdentifier: String) -> WindowNode? {
    let candidates = nodesByID.values.filter { $0.bundleIdentifier == bundleIdentifier }
    if let remembered = lastFocusedByBundle[bundleIdentifier].flatMap({ nodesByID[$0] }),
      candidates.contains(where: { $0.id == remembered.id })
    {
      return remembered
    }
    if let frontmostID = windowService.frontmostWindowID(among: candidates) {
      return nodesByID[frontmostID]
    }
    return candidates.min(by: { $0.id < $1.id })
  }

  private func workspaceApplication(from notification: Notification) -> NSRunningApplication? {
    notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
  }

  private func shouldFollow(_ application: NSRunningApplication) -> Bool {
    guard application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
      application.activationPolicy != .prohibited,
      let bundle = application.bundleIdentifier
    else { return false }
    let ignored = [
      "com.apple.Spotlight", "com.apple.dock", "com.apple.controlcenter",
      "com.apple.systemuiserver",
    ]
    return !ignored.contains(where: { bundle.hasPrefix($0) })
  }

  private func beginPendingLaunch(
    for application: NSRunningApplication,
    anchor requestedAnchor: CGPoint? = nil
  ) {
    guard let bundleIdentifier = application.bundleIdentifier else { return }
    let existing = pendingLaunchesByBundle[bundleIdentifier]
    pendingLaunchesByBundle[bundleIdentifier] = PendingLaunch(
      processID: application.processIdentifier,
      bundleIdentifier: bundleIdentifier,
      anchor: requestedAnchor
        ?? requestedLaunchAnchors[bundleIdentifier]
        ?? existing?.anchor
        ?? canvasView.camera.center,
      knownWindowIDs: existing?.knownWindowIDs ?? Set(nodesByID.keys),
      deadline: Date().addingTimeInterval(5)
    )
  }

  private func installShortcut() {
    OverviewShortcutController.shared.stop()
    if let globalSwipeMonitor { NSEvent.removeMonitor(globalSwipeMonitor) }
    globalSwipeMonitor = nil
    if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
    localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .swipe]) {
      [weak self] event in
      if event.type == .swipe {
        let handled = MainActor.assumeIsolated { self?.handleOverviewSwipe(event) ?? false }
        return handled ? nil : event
      }
      if let recorder = event.window?.firstResponder as? OverviewShortcutRecorder,
        recorder.isRecording {
        if event.type == .keyDown { recorder.keyDown(with: event) }
        return nil
      }
      if event.type == .keyUp {
        let handled = MainActor.assumeIsolated {
          self?.isShowingCanvas == true && self?.canvasView.handleNavigationKeyUp(event) == true
        }
        return handled ? nil : event
      }
      if self?.isShowingCanvas == true, self?.canvasView.handleInterfaceKey(event) == true { return nil }
      if event.keyCode == 53 {
        let dismissed = MainActor.assumeIsolated {
          guard self?.isShowingCanvas == true else { return false }
          if self?.canvasView.dismissSearch() == true { return true }
          if self?.canvasView.navigateBackInSettings() == true { return true }
          if self?.canvasView.dismissSettings() == true { return true }
          if self?.canvasView.closeCatalog() == true { return true }
          if self?.canvasView.dismissDesktopTitleEditing() == true { return true }
          self?.dismissCanvas()
          return true
        }
        if dismissed { return nil }
      }
      let navigated = MainActor.assumeIsolated {
        self?.isShowingCanvas == true && self?.canvasView.handleNavigationKey(event) == true
      }
      if navigated { return nil }
      return event
    }
    globalSwipeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .swipe) { [weak self] event in
      MainActor.assumeIsolated { _ = self?.handleOverviewSwipe(event) }
    }
    OverviewShortcutController.shared.onActivate = { [weak self] in self?.handleShortcut() }
    if !OverviewShortcutController.shared.start() {
      canvasView.statusMessage = "Overview shortcut is unavailable. Choose another in Settings."
    }
    _ = configureCommandTabEventTap(
      enabled: UserDefaults.standard.bool(forKey: OpenPlanePreferences.useCommandTabShortcut)
    )
  }

  private func configureCommandTabEventTap(enabled: Bool) -> Bool {
    removeCommandTabEventTap()
    guard enabled || UserDefaults.standard.bool(forKey: "useRightCommandShortcut") else { return true }

    let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
      | CGEventMask(1 << CGEventType.keyUp.rawValue)
      | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
      | CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
      | CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
      | CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: openPlaneCommandTabEventTapCallback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      ),
      let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    else { return false }

    commandTabEventTap = eventTap
    commandTabRunLoopSource = runLoopSource
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    return true
  }

  private func removeCommandTabEventTap() {
    rightCommandTap = RightCommandTap()
    if let commandTabEventTap {
      CGEvent.tapEnable(tap: commandTabEventTap, enable: false)
      CFMachPortInvalidate(commandTabEventTap)
    }
    if let commandTabRunLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), commandTabRunLoopSource, .commonModes)
    }
    commandTabEventTap = nil
    commandTabRunLoopSource = nil
  }

  fileprivate func reenableCommandTabEventTap() {
    rightCommandTap = RightCommandTap()
    if let commandTabEventTap {
      CGEvent.tapEnable(tap: commandTabEventTap, enable: true)
    }
  }

  private func handleOverviewSwipe(_ event: NSEvent) -> Bool {
    guard UserDefaults.standard.bool(forKey: "swipeUpOpensOverview"),
      !OverviewShortcutController.shared.isRecording,
      ShortcutMatcher.isOverviewSwipe(deltaX: event.deltaX, deltaY: event.deltaY) else { return false }
    // A trailing swipe must not replace the animation handing off to a window.
    if case .focusing = stateMachine.mode { return true }
    canvasView.setViewMode(.overview)
    handleShortcut()
    return true
  }

  fileprivate func handleShortcut() {
    switch stateMachine.mode {
    case .working, .overview:
      showCanvas()
    case .focusing:
      break
    }
  }
}
