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

  guard ShortcutMatcher.isCommandTab(
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
  private let permissionView = PermissionView(frame: .zero)

  private var overlayWindow: NSWindow!
  private var nodesByID: [CGWindowID: WindowNode] = [:]
  private var stateMachine = CanvasStateMachine()
  private var lastOverviewCamera = CameraState()
  private var pendingLaunch: PendingLaunch?
  private var lastFocusedByBundle: [String: CGWindowID] = [:]
  private var appHistory = AppNavigationHistory()
  private var inventoryTracker = WindowInventoryTracker()
  private var didInitialLayout = false
  private var isReturning = false
  private var isDismissing = false

  private var inventoryTask: Task<Void, Never>?
  private var previewTask: Task<Void, Never>?
  private var previewScheduler = PreviewRefreshScheduler()
  private var permissionTimer: Timer?
  private var globalKeyMonitor: Any?
  private var localKeyMonitor: Any?
  private var commandTabEventTap: CFMachPort?
  private var commandTabRunLoopSource: CFRunLoopSource?

  func applicationDidFinishLaunching(_ notification: Notification) {
    buildMenu()
    buildOverlayWindow()
    configurePermissionView()
    observeWorkspace()
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
    stopCanvasLoops()
    permissionTimer?.invalidate()
    if let globalKeyMonitor { NSEvent.removeMonitor(globalKeyMonitor) }
    if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
    removeCommandTabEventTap()
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

  func canvasView(_ canvasView: CanvasView, didRequestFocus node: WindowNode) {
    focus(node)
  }

  func canvasViewDidRequestBack(_ canvasView: CanvasView) {
    let available = Set(nodesByID.values.map(\.bundleIdentifier))
    selectHistoryTarget(appHistory.goBack(available: available))
  }

  func canvasViewDidRequestForward(_ canvasView: CanvasView) {
    let available = Set(nodesByID.values.map(\.bundleIdentifier))
    selectHistoryTarget(appHistory.goForward(available: available))
  }

  private func selectHistoryTarget(_ bundleIdentifier: String?) {
    updateHistoryNavigation()
    guard let bundleIdentifier, let node = preferredNode(for: bundleIdentifier) else { return }
    canvasView.selectedWindowID = node.id
    canvasView.animateCamera(
      to: CameraState(
        center: CGPoint(x: node.worldFrame.midX, y: node.worldFrame.midY),
        zoom: canvasView.camera.zoom
      ),
      duration: CanvasView.selectionTransitionDuration
    ) {}
  }

  func canvasView(_ canvasView: CanvasView, setCommandTabShortcut enabled: Bool) -> Bool {
    configureCommandTabEventTap(enabled: enabled)
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

  private func showCanvas() {
    guard permissionState.requiredAccessGranted else {
      showPermissions()
      return
    }
    permissionTimer?.invalidate()
    configureWindowForCanvas()
    overlayWindow.contentView = canvasView

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
    guard isShowingCanvas, !isDismissing else { return }
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
        node.previewState = .loading
        canvasView.setNeedsDisplay(for: [node.id])
        do {
          let preview = try await windowService.capture(window: node.captureWindow)
          applyFreshPreview(preview, to: node)
        } catch {
          node.previewState = .failed
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
      canvasView.animateCamera(to: target) { [weak self] in
        guard let self else { return }
        stateMachine.returnToOverview()
        lastOverviewCamera = target
        startCanvasLoops()
        isReturning = false
      }
    }
  }

  private func focus(_ node: WindowNode, recordInHistory: Bool = true) {
    guard stateMachine.beginFocus(on: node.id) else { return }
    canvasView.selectedWindowID = node.id
    lastOverviewCamera = canvasView.camera
    lastFocusedByBundle[node.bundleIdentifier] = node.id
    if recordInHistory { appHistory.opened(node.bundleIdentifier) }
    updateHistoryNavigation()
    stopCanvasLoops()
    guard windowService.prepareForFocus(node) else {
      overlayWindow.orderOut(nil)
      windowService.activate(node)
      stateMachine.completeFocus(on: node.id)
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
    windowService.activate(node)
    Task { [weak self, weak node] in
      guard let self, let node else { return }
      await waitForActivation(of: node)
      guard stateMachine.mode == .focusing(node.id) else { return }
      canvasView.animateCamera(
        to: target,
        tracking: CGPoint(x: node.worldFrame.midX, y: node.worldFrame.midY),
        isolating: node.id,
        duration: 0.5,
        cameraCompletionFraction: 0.7,
        progressHandler: { [weak self] progress in
          self?.overlayWindow.alphaValue = CanvasMath.focusOverlayOpacity(progress: progress)
        }
      ) { [weak self, weak node] in
        guard let self, let node else { return }
        overlayWindow.orderOut(nil)
        overlayWindow.alphaValue = 1
        canvasView.endFocusTransition()
        stateMachine.completeFocus(on: node.id)
      }
    }
  }

  private func waitForActivation(of node: WindowNode) async {
    let deadline = CACurrentMediaTime() + 0.05
    while NSWorkspace.shared.frontmostApplication?.processIdentifier != node.processID,
      CACurrentMediaTime() < deadline
    {
      try? await Task.sleep(for: .milliseconds(5))
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
    previewTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.refreshVisiblePreviews()
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  private func stopCanvasLoops() {
    inventoryTask?.cancel()
    previewTask?.cancel()
    inventoryTask = nil
    previewTask = nil
  }

  private func reconcileWindows() async {
    guard overlayWindow.isVisible, overlayWindow.contentView === canvasView else { return }
    guard !canvasView.defersBackgroundWork else { return }
    do {
      let discovered = try await windowService.discover(on: mainScreen)
      guard !Task.isCancelled, !canvasView.defersBackgroundWork else { return }
      let discoveredIDs = Set(discovered.map(\.id))
      let previousIDs = Set(nodesByID.keys)
      let potentiallyMissingIDs = previousIDs.subtracting(discoveredIDs)
      let existingIDs = potentiallyMissingIDs.isEmpty
        ? Set<CGWindowID>() : await windowService.existingWindowIDs()
      guard !Task.isCancelled, !canvasView.defersBackgroundWork else { return }
      let change = inventoryTracker.change(
        previous: previousIDs,
        current: discoveredIDs,
        existing: existingIDs
      )
      nodesByID = nodesByID.filter { !change.removed.contains($0.key) }

      var newWindows: [DiscoveredWindow] = []
      var changedMetadataIDs: [CGWindowID] = []
      var needsPreviewSizeUpdate = false
      for item in discovered {
        if change.retained.contains(item.id), let node = nodesByID[item.id] {
          if node.applicationName != item.applicationName || node.title != item.title
            || (node.icon == nil) != (item.icon == nil)
          {
            changedMetadataIDs.append(item.id)
          }
          if node.sourceFrame.size != item.frame.size { needsPreviewSizeUpdate = true }
          node.update(from: item)
        } else if change.added.contains(item.id) {
          newWindows.append(item)
        }
      }

      if !didInitialLayout && !discovered.isEmpty {
        let sizes = canvasView.preferredPreviewSizes(for: discovered.map { $0.frame.size })
        let frames = CanvasMath.gridFrames(for: sizes)
        for (item, frame) in zip(discovered, frames) {
          nodesByID[item.id] = await makeNode(for: item, worldFrame: frame)
        }
        didInitialLayout = true
        canvasView.camera = canvasView.initialCamera(
          fitting: CanvasMath.fitCamera(frames: frames, in: canvasView.bounds)
        )
      } else {
        for item in newWindows {
          let anchor = placementAnchor(for: item)
          let frame = CanvasMath.cascadedFrame(
            size: item.frame.size,
            centeredAt: anchor,
            avoiding: nodesByID.values.map(\.worldFrame)
          )
          nodesByID[item.id] = await makeNode(for: item, worldFrame: frame)
        }
      }

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
    if let pendingLaunch, pendingLaunch.bundleIdentifier == item.bundleIdentifier {
      return pendingLaunch.anchor
    }
    if let id = lastFocusedByBundle[item.bundleIdentifier], let active = nodesByID[id] {
      return CGPoint(x: active.worldFrame.midX + 80, y: active.worldFrame.midY - 80)
    }
    return canvasView.camera.center
  }

  private func resolvePendingLaunch(with newWindows: [DiscoveredWindow]) {
    guard let pendingLaunch else { return }
    if let item = newWindows.first(where: {
      !pendingLaunch.knownWindowIDs.contains($0.id)
        && ($0.processID == pendingLaunch.processID
          || $0.bundleIdentifier == pendingLaunch.bundleIdentifier)
    }), let node = nodesByID[item.id] {
      self.pendingLaunch = nil
      focus(node)
      return
    }
    guard Date() >= pendingLaunch.deadline else { return }
    self.pendingLaunch = nil
    overlayWindow.orderOut(nil)
    stopCanvasLoops()
    NSRunningApplication(processIdentifier: pendingLaunch.processID)?.activate(options: [])
  }

  private func refreshVisiblePreviews() async {
    guard overlayWindow.isVisible, overlayWindow.contentView === canvasView else { return }
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
      guard !canvasView.defersBackgroundWork else { break }
      let previousState = node.previewState
      let loadingIndicatorTask = Task { [weak self, weak node] in
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled, let self, let node else { return }
        node.previewState = .loading
        canvasView.setNeedsDisplay(for: [node.id])
      }
      do {
        let preview = try await windowService.capture(
          window: node.captureWindow,
          targetLongEdgePixels: canvasView.previewPixelLength(for: node)
        )
        loadingIndicatorTask.cancel()
        guard !canvasView.defersBackgroundWork else {
          node.previewState = previousState
          continue
        }
        applyFreshPreview(preview, to: node)
      } catch {
        loadingIndicatorTask.cancel()
        node.previewState = .failed
      }
      didChange = true
    }
    return didChange
  }

  private func makeNode(for item: DiscoveredWindow, worldFrame: CGRect) async -> WindowNode {
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
    canvasView.replacePreview(
      NSImage(cgImage: preview.image, size: preview.size),
      for: node
    )
    node.previewState = .current

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
    guard isShowingCanvas, let application = workspaceApplication(from: notification),
      shouldFollow(application)
    else { return }
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
    } else if pendingLaunch == nil {
      beginPendingLaunch(for: application)
    }
  }

  @objc private func workspaceDidTerminate(_ notification: Notification) {
    guard let application = workspaceApplication(from: notification) else { return }
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
    overlayWindow.isVisible && overlayWindow.contentView === canvasView
      && stateMachine.mode == .overview
  }

  private func publishNodes() {
    let nodes = nodesByID.values.sorted { $0.id < $1.id }
    canvasView.nodes = nodes
    updateHistoryNavigation()
    guard !nodes.contains(where: { $0.id == canvasView.selectedWindowID }) else { return }
    canvasView.selectedWindowID = windowService.frontmostWindowID(among: nodes) ?? nodes.first?.id
  }

  private func updateHistoryNavigation() {
    let available = Set(nodesByID.values.map(\.bundleIdentifier))
    canvasView.backNavigationTarget = appHistory
      .backDestination(available: available)
      .flatMap(preferredNode)
    canvasView.forwardNavigationTarget = appHistory
      .forwardDestination(available: available)
      .flatMap(preferredNode)
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

  private func beginPendingLaunch(for application: NSRunningApplication) {
    guard let bundleIdentifier = application.bundleIdentifier else { return }
    pendingLaunch = PendingLaunch(
      processID: application.processIdentifier,
      bundleIdentifier: bundleIdentifier,
      anchor: canvasView.camera.center,
      knownWindowIDs: Set(nodesByID.keys),
      deadline: Date().addingTimeInterval(5)
    )
  }

  private func installShortcut() {
    if let globalKeyMonitor { NSEvent.removeMonitor(globalKeyMonitor) }
    if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
    localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      if Self.isCanvasShortcut(event) {
        MainActor.assumeIsolated { self?.handleShortcut() }
        return nil
      }
      if event.keyCode == 53 {
        let dismissed = MainActor.assumeIsolated {
          guard self?.isShowingCanvas == true else { return false }
          if self?.canvasView.dismissSearch() == true { return true }
          if self?.canvasView.dismissSettings() == true { return true }
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
    globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard Self.isCanvasShortcut(event) else { return }
      Task { @MainActor in self?.handleShortcut() }
    }
    _ = configureCommandTabEventTap(
      enabled: UserDefaults.standard.bool(forKey: OpenPlanePreferences.useCommandTabShortcut)
    )
  }

  private func configureCommandTabEventTap(enabled: Bool) -> Bool {
    removeCommandTabEventTap()
    guard enabled else { return true }

    let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
      | CGEventMask(1 << CGEventType.keyUp.rawValue)
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
    if let commandTabEventTap {
      CGEvent.tapEnable(tap: commandTabEventTap, enable: true)
    }
  }

  nonisolated private static func isCanvasShortcut(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    return event.keyCode == 49 && modifiers == [.control, .option]
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
