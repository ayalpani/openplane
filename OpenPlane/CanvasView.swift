@preconcurrency import AppKit
@preconcurrency import QuartzCore

private func drawOpenPlaneLaunchMessage(in bounds: CGRect) {
  let title = "OpenPlane"
  let subtitle = "Open an app with Spotlight or the Dock. Its window will appear here."
  let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 30, weight: .semibold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.88),
  ]
  let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14),
    .foregroundColor: NSColor.white.withAlphaComponent(0.52),
  ]
  let titleSize = title.size(withAttributes: titleAttributes)
  let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
  title.draw(
    at: CGPoint(x: bounds.midX - titleSize.width / 2, y: bounds.midY + 8),
    withAttributes: titleAttributes
  )
  subtitle.draw(
    at: CGPoint(x: bounds.midX - subtitleSize.width / 2, y: bounds.midY - 26),
    withAttributes: subtitleAttributes
  )
}

@MainActor
private final class LaunchSplashView: NSView {
  private let backgroundColor: NSColor

  init(frame frameRect: NSRect, backgroundColor: NSColor) {
    self.backgroundColor = backgroundColor
    super.init(frame: frameRect)
    wantsLayer = true
  }

  required init?(coder: NSCoder) { nil }

  override func draw(_ dirtyRect: NSRect) {
    backgroundColor.setFill()
    dirtyRect.fill()

    let spacing: CGFloat = 52
    let path = CGMutablePath()
    var x = floor(dirtyRect.minX / spacing) * spacing
    while x < dirtyRect.maxX {
      var y = floor(dirtyRect.minY / spacing) * spacing
      while y < dirtyRect.maxY {
        path.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
        y += spacing
      }
      x += spacing
    }
    if let context = NSGraphicsContext.current?.cgContext {
      context.setFillColor(NSColor.white.withAlphaComponent(0.20).cgColor)
      context.addPath(path)
      context.fillPath()
    }
    drawOpenPlaneLaunchMessage(in: bounds)
  }
}

private final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
  override func drawingRect(forBounds rect: NSRect) -> NSRect {
    centeredTextRect(for: rect)
  }

  override func edit(
    withFrame rect: NSRect,
    in controlView: NSView,
    editor textObject: NSText,
    delegate: Any?,
    event: NSEvent?
  ) {
    super.edit(
      withFrame: centeredTextRect(for: rect),
      in: controlView,
      editor: textObject,
      delegate: delegate,
      event: event
    )
  }

  override func select(
    withFrame rect: NSRect,
    in controlView: NSView,
    editor textObject: NSText,
    delegate: Any?,
    start selectionStart: Int,
    length selectionLength: Int
  ) {
    super.select(
      withFrame: centeredTextRect(for: rect),
      in: controlView,
      editor: textObject,
      delegate: delegate,
      start: selectionStart,
      length: selectionLength
    )
  }

  private func centeredTextRect(for rect: NSRect) -> NSRect {
    var textRect = super.drawingRect(forBounds: rect)
    guard let font else { return textRect }
    let textHeight = ceil(font.ascender - font.descender + font.leading)
    textRect.origin.y += floor(max(0, textRect.height - textHeight) / 2)
    textRect.size.height = min(textRect.height, textHeight)
    return textRect
  }
}

@MainActor
private final class HoverButton: NSButton {
  private var hoverTrackingArea: NSTrackingArea?
  private var isHovering = false
  var usesOpacityOnlyHover = false {
    didSet {
      guard usesOpacityOnlyHover else { return }
      layer?.backgroundColor = NSColor.clear.cgColor
      layer?.setAffineTransform(.identity)
      updateOpacityOnlyAppearance()
    }
  }

  override var isEnabled: Bool {
    didSet {
      if usesOpacityOnlyHover { updateOpacityOnlyAppearance() }
    }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.masksToBounds = false
  }

  required init?(coder: NSCoder) { nil }

  override func layout() {
    super.layout()
    layer?.cornerRadius = min(bounds.width, bounds.height) * 0.3
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
    let trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.mouseEnteredAndExited, .activeAlways],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    hoverTrackingArea = trackingArea
  }

  override func mouseEntered(with event: NSEvent) {
    super.mouseEntered(with: event)
    setHovering(isEnabled)
  }

  override func mouseExited(with event: NSEvent) {
    super.mouseExited(with: event)
    setHovering(false)
  }

  private func setHovering(_ hovering: Bool) {
    guard hovering != isHovering else { return }
    isHovering = hovering
    CATransaction.begin()
    CATransaction.setAnimationDuration(0.18)
    CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
    if usesOpacityOnlyHover {
      layer?.backgroundColor = NSColor.clear.cgColor
      layer?.setAffineTransform(.identity)
      updateOpacityOnlyAppearance()
    } else {
      layer?.backgroundColor = NSColor.clear.cgColor
      layer?.setAffineTransform(
        hovering ? CGAffineTransform(scaleX: 1.06, y: 1.06) : .identity)
    }
    CATransaction.commit()
  }

  private func updateOpacityOnlyAppearance() {
    layer?.opacity = !isEnabled ? 0.2 : isHovering ? 1 : 0.5
  }
}

@MainActor
protocol CanvasViewDelegate: AnyObject {
  func canvasView(_ canvasView: CanvasView, didRequestFocus node: WindowNode)
  func canvasViewDidRequestBack(_ canvasView: CanvasView)
  func canvasViewDidRequestForward(_ canvasView: CanvasView)
  func canvasView(_ canvasView: CanvasView, setCommandTabShortcut enabled: Bool) -> Bool
}

@MainActor
final class CanvasView: NSView, NSTextFieldDelegate, NSViewToolTipOwner {
  private static let backgroundPreferenceKey = "canvasBackground"
  private static let navigatorPanelXPreferenceKey = "navigatorPanelX"
  private static let navigatorPanelYPreferenceKey = "navigatorPanelY"
  private static let expandLandscapePreviewsPreferenceKey = "expandLandscapePreviews"
  private static let debugInformationPreferenceKey = "showDebugInformation"
  private static let desktopPagesPreferenceKey = "desktopPages"
  private static let navigatorPanelSize = CGSize(width: 268, height: 244)
  private static let navigatorTextFont = NSFont.systemFont(ofSize: 14, weight: .medium)
  private static let desktopTitleFont = NSFont.systemFont(ofSize: 36, weight: .heavy)
  private static let appIconSize: CGFloat = 36
  private static let previewFadeDuration: TimeInterval = 0.25
  static let selectionTransitionDuration: TimeInterval = 0.36

  weak var delegate: CanvasViewDelegate?
  var nodes: [WindowNode] = [] {
    didSet {
      let nodeIDs = Set(nodes.map(\.id))
      groupSelectionIDs.formIntersection(nodeIDs)
      previousPreviews = previousPreviews.filter { nodeIDs.contains($0.key) }
      previewFadeStartedAt = previewFadeStartedAt.filter { nodeIDs.contains($0.key) }
      if previewFadeStartedAt.isEmpty {
        previewFadeDisplayLink?.invalidate()
        previewFadeDisplayLink = nil
      }
      if isHoveringGroupSelection, groupSelectionIDs.isEmpty {
        setHoveredWindow(nil)
      }
      if let hoveredWindowID, !nodes.contains(where: { $0.id == hoveredWindowID }) {
        setHoveredWindow(nil)
      }
      needsDisplay = true
      schedulePreviewToolTipUpdate()
      updateNavigatorPanel()
      if isSearching { updateSearchResults(centerSelection: false) }
    }
  }
  var selectedWindowID: CGWindowID? {
    didSet {
      guard selectedWindowID != oldValue else { return }
      animateSelection(from: oldValue, to: selectedWindowID)
      needsDisplay = true
      updateNavigatorPanel()
    }
  }
  var camera = CameraState() {
    didSet {
      desktopPages.updateSelectedCamera(camera)
      scheduleDesktopPagesPersistence()
      needsDisplay = true
      schedulePreviewToolTipUpdate()
    }
  }
  var statusMessage: String? {
    didSet {
      guard statusMessage != oldValue else { return }
      needsDisplay = true
    }
  }
  var backNavigationTarget: WindowNode? {
    didSet {
      if backNavigationTarget == nil { isHoveringBackButton = false }
      updateNavigatorPanel()
    }
  }
  var forwardNavigationTarget: WindowNode? {
    didSet {
      if forwardNavigationTarget == nil { isHoveringForwardButton = false }
      updateNavigatorPanel()
    }
  }

  private enum Interaction {
    case miniMap
    case navigatorPanel(start: CGPoint, origin: CGPoint, button: NSButton?, dragged: Bool)
    case marquee(start: CGPoint, current: CGPoint, dragged: Bool)
    case group(start: CGPoint, frames: [CGWindowID: CGRect], dragged: Bool)
    case window(
      node: WindowNode,
      start: CGPoint,
      frames: [CGWindowID: CGRect],
      dragged: Bool
    )
  }

  private struct MiniMapProjection {
    let frame: CGRect
    let contentBounds: CGRect
    let camera: CameraState
    let viewportWorldFrame: CGRect
  }

  private var interaction: Interaction?
  private var backgroundWorkDeferredUntil: TimeInterval = 0
  private var groupSelectionIDs: Set<CGWindowID> = []
  private var animationDisplayLink: CADisplayLink?
  private var cameraAnimation: CameraAnimation?
  private var isPresentingFinalAnimationFrame = false
  private var focusTransitionWindowID: CGWindowID?
  private var focusTransitionProgress: CGFloat = 0
  private var navigatorPanelOrigin: CGPoint?
  private var canvasTrackingArea: NSTrackingArea?
  private var backTrackingArea: NSTrackingArea?
  private var forwardTrackingArea: NSTrackingArea?
  private var isHoveringBackButton = false {
    didSet {
      guard isHoveringBackButton != oldValue else { return }
      updateNavigatorPanel()
    }
  }
  private var isHoveringForwardButton = false {
    didSet {
      guard isHoveringForwardButton != oldValue else { return }
      updateNavigatorPanel()
    }
  }
  private var appIconSourceRects: [ObjectIdentifier: CGRect] = [:]
  private var previewToolTipTags: [NSView.ToolTipTag] = []
  private var previewToolTipWindowIDs: [NSView.ToolTipTag: CGWindowID] = [:]
  private var previewToolTipUpdateTask: Task<Void, Never>?
  private var hoveredWindowID: CGWindowID?
  private var isHoveringGroupSelection = false
  private var windowHoverProgress: [CGWindowID: CGFloat] = [:]
  private var windowHoverStartProgress: [CGWindowID: CGFloat] = [:]
  private var windowHoverAnimationStartedAt: TimeInterval?
  private var windowHoverDisplayLink: CADisplayLink?
  private var selectionProgress: [CGWindowID: CGFloat] = [:]
  private var selectionStartProgress: [CGWindowID: CGFloat] = [:]
  private var selectionStaysWithinApplication = false
  private var selectionAnimationStartedAt: TimeInterval?
  private var selectionDisplayLink: CADisplayLink?
  private var previousPreviews: [CGWindowID: NSImage] = [:]
  private var previewFadeStartedAt: [CGWindowID: TimeInterval] = [:]
  private var previewFadeDisplayLink: CADisplayLink?
  private var gridPatternZoom: CGFloat?
  private var gridPatternColor: NSColor?
  private var launchSplashView: LaunchSplashView?
  private var launchSplashTask: Task<Void, Never>?
  private var displayedNavigatorNodeID: CGWindowID?
  private var hasDisplayedNavigatorContent = false
  private let focusButton = NSButton()
  private let backButton = HoverButton()
  private let forwardButton = HoverButton()
  private let menuButton = HoverButton()
  private let fitAllButton = HoverButton()
  private let searchButton = HoverButton()
  private let settingsButton = HoverButton()
  private let lockViewButton = HoverButton()
  private let closeSearchButton = HoverButton()
  private let nextSearchResultButton = HoverButton()
  private let previousSearchResultButton = HoverButton()
  private let searchField = NSTextField()
  private let desktopTitleField = NSTextField()
  private let settingsPopover = NSPopover()
  private let navigatorMenu = NSMenu()
  private let desktopPagesMenu = NSMenu()
  private let desktopPagesMenuItem = NSMenuItem()
  private let newDesktopMenuItem = NSMenuItem()
  private let expandLandscapePreviewsMenuItem = NSMenuItem()
  private let debugInformationMenuItem = NSMenuItem()
  private let commandTabShortcutMenuItem = NSMenuItem()
  private var isSearching = false
  private var expandsLandscapePreviews = true
  private var showsDebugInformation = UserDefaults.standard.bool(
    forKey: CanvasView.debugInformationPreferenceKey)
  private var usesCommandTabShortcut = UserDefaults.standard.bool(
    forKey: OpenPlanePreferences.useCommandTabShortcut)
  private var desktopPages = DesktopPages()
  private let selectionColor = NSColor(srgbRed: 1, green: 1, blue: 0, alpha: 1)
  private let groupSelectionColor = NSColor(
    srgbRed: 0.21,
    green: 0.94,
    blue: 0.44,
    alpha: 1
  )
  private var background = CanvasPalette.background(
    for: UserDefaults.standard.string(forKey: CanvasView.backgroundPreferenceKey))

  private struct CameraAnimation {
    let start: CameraState
    let target: CameraState
    let trackingWorldPoint: CGPoint?
    let focusWindowID: CGWindowID?
    let cameraCompletionFraction: CGFloat
    let progressHandler: (@MainActor @Sendable (CGFloat) -> Void)?
    let startedAt: TimeInterval
    let duration: TimeInterval
    let completion: @MainActor @Sendable () -> Void
  }

  override var acceptsFirstResponder: Bool { true }

  override init(frame frameRect: NSRect) {
    let defaults = UserDefaults.standard
    desktopPages = Self.loadDesktopPages(from: defaults)
    camera = desktopPages.selectedPage.camera ?? camera
    if defaults.object(forKey: Self.navigatorPanelXPreferenceKey) != nil,
      defaults.object(forKey: Self.navigatorPanelYPreferenceKey) != nil
    {
      navigatorPanelOrigin = CGPoint(
        x: defaults.double(forKey: Self.navigatorPanelXPreferenceKey),
        y: defaults.double(forKey: Self.navigatorPanelYPreferenceKey)
      )
    }
    super.init(frame: frameRect)
    if defaults.object(forKey: Self.expandLandscapePreviewsPreferenceKey) != nil {
      expandsLandscapePreviews = defaults.bool(
        forKey: Self.expandLandscapePreviewsPreferenceKey)
    }
    wantsLayer = true
    allowedTouchTypes = [.indirect]
    let trackingArea = NSTrackingArea(
      rect: .zero,
      options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    canvasTrackingArea = trackingArea
    configureDesktopTitle()
    configureNavigatorPanel()
    configureMenuButton()
    configureFitAllButton()
    configureLockViewButton()
    configureSearch()
    configureSettingsButton()
    updateNavigatorPanel()
  }

  required init?(coder: NSCoder) { nil }

  override func hitTest(_ point: NSPoint) -> NSView? {
    if isSearching,
      closeSearchButton.frame.contains(point) || searchField.frame.contains(point)
    {
      return super.hitTest(point)
    }
    if navigatorHeaderFrame.contains(point) { return self }
    return super.hitTest(point)
  }

  override func layout() {
    super.layout()
    schedulePreviewToolTipUpdate()
    let panel = navigatorPanelFrame
    backButton.frame = CGRect(
      x: panel.minX + 10,
      y: panel.maxY - 44,
      width: 28,
      height: 40
    )
    forwardButton.frame = CGRect(
      x: panel.minX + 38,
      y: panel.maxY - 44,
      width: 28,
      height: 40
    )
    menuButton.frame = CGRect(
      x: panel.maxX - 48,
      y: panel.maxY - 44,
      width: 40,
      height: 40
    )
    let focusMinX = panel.minX + 74
    focusButton.frame = CGRect(
      x: focusMinX,
      y: panel.maxY - 44,
      width: panel.maxX - 48 - focusMinX,
      height: 40
    )
    let footerButtonsX = panel.midX - 80
    searchButton.frame = CGRect(
      x: footerButtonsX,
      y: panel.minY + 4,
      width: 40,
      height: 40
    )
    fitAllButton.frame = CGRect(
      x: footerButtonsX + 40,
      y: panel.minY + 4,
      width: 40,
      height: 40
    )
    settingsButton.frame = CGRect(
      x: footerButtonsX + 120,
      y: panel.minY + 4,
      width: 40,
      height: 40
    )
    lockViewButton.frame = CGRect(
      x: footerButtonsX + 80,
      y: panel.minY + 4,
      width: 40,
      height: 40
    )
    previousSearchResultButton.frame = CGRect(
      x: panel.minX + 10,
      y: panel.minY + 4,
      width: 28,
      height: 40
    )
    nextSearchResultButton.frame = CGRect(
      x: panel.minX + 38,
      y: panel.minY + 4,
      width: 28,
      height: 40
    )
    closeSearchButton.frame = CGRect(
      x: panel.minX + 4,
      y: panel.maxY - 44,
      width: 40,
      height: 40
    )
    searchField.frame = CGRect(
      x: panel.minX + 44,
      y: panel.maxY - 40,
      width: panel.width - 52,
      height: 32
    )
    let desktopTitleWidth = min(720, max(240, bounds.width - 160))
    desktopTitleField.frame = CGRect(
      x: bounds.midX - desktopTitleWidth / 2,
      y: bounds.maxY - 112,
      width: desktopTitleWidth,
      height: 52
    )
  }

  override func mouseEntered(with event: NSEvent) {
    if let backTrackingArea, event.trackingArea === backTrackingArea {
      isHoveringBackButton = true
    } else if let forwardTrackingArea, event.trackingArea === forwardTrackingArea {
      isHoveringForwardButton = true
    } else {
      super.mouseEntered(with: event)
    }
  }

  override func mouseExited(with event: NSEvent) {
    if let backTrackingArea, event.trackingArea === backTrackingArea {
      isHoveringBackButton = false
    } else if let forwardTrackingArea, event.trackingArea === forwardTrackingArea {
      isHoveringForwardButton = false
    } else if let canvasTrackingArea, event.trackingArea === canvasTrackingArea {
      setHoveredWindow(nil)
    } else {
      super.mouseExited(with: event)
    }
  }

  override func mouseMoved(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    updateHover(at: point)
    super.mouseMoved(with: event)
  }

  override func draw(_ dirtyRect: NSRect) {
    let backdropOpacity = CanvasMath.focusBackdropOpacity(
      progress: focusTransitionProgress
    )
    let context = NSGraphicsContext.current?.cgContext
    context?.clear(dirtyRect)
    context?.saveGState()
    context?.setAlpha(backdropOpacity)
    background.color.setFill()
    dirtyRect.fill()
    drawGrid(in: dirtyRect)
    context?.restoreGState()

    let selectedProcessID = nodes.first(where: { $0.id == selectedWindowID })?.processID
    let raisedIDs = hoverTargetWindowIDs
    let drawingNodes = nodes.filter { !raisedIDs.contains($0.id) }
      + nodes.filter { raisedIDs.contains($0.id) }
    for node in drawingNodes {
      let baseRect = CanvasMath.viewRect(for: node.worldFrame, camera: camera, bounds: bounds)
      let expansion = 3 * (windowHoverProgress[node.id] ?? 0)
      let rect = baseRect.insetBy(dx: -expansion, dy: -expansion)
      guard rect.intersects(bounds.insetBy(dx: -80, dy: -80)),
        rect.intersects(dirtyRect.insetBy(dx: -48, dy: -48))
      else { continue }
      NSGraphicsContext.saveGraphicsState()
      var nodeOpacity: CGFloat = node.id == focusTransitionWindowID ? 1 : backdropOpacity
      if isSearching, !matchesSearch(node) {
        nodeOpacity *= 0.14
      }
      NSGraphicsContext.current?.cgContext.setAlpha(nodeOpacity)
      draw(node: node, in: rect, selectedProcessID: selectedProcessID)
      NSGraphicsContext.restoreGraphicsState()
    }

    context?.saveGState()
    context?.setAlpha(backdropOpacity)
    if nodes.isEmpty {
      drawEmptyState()
    }
    if let statusMessage {
      drawStatus(statusMessage)
    }
    drawGroupSelection()
    if showsDebugInformation { drawDebugInformation() }
    drawNavigatorPanel()
    context?.restoreGState()
  }

  func visibleWindowIDs() -> [CGWindowID] {
    nodes.compactMap { node in
      CanvasMath.viewRect(for: node.worldFrame, camera: camera, bounds: bounds)
        .intersects(bounds.insetBy(dx: -120, dy: -120)) ? node.id : nil
    }
  }

  func previewPixelLength(for node: WindowNode) -> Int {
    let displaySize = CanvasMath.viewRect(
      for: node.worldFrame,
      camera: camera,
      bounds: bounds
    ).size
    return CanvasMath.previewPixelLength(
      displaySize: displaySize,
      backingScale: window?.backingScaleFactor ?? 2
    )
  }

  func showLaunchSplash(for duration: TimeInterval = 2.5) {
    launchSplashTask?.cancel()
    launchSplashView?.removeFromSuperview()

    let splash = LaunchSplashView(frame: bounds, backgroundColor: background.color)
    splash.autoresizingMask = [.width, .height]
    splash.alphaValue = 1
    addSubview(splash, positioned: .above, relativeTo: nil)
    launchSplashView = splash

    launchSplashTask = Task { @MainActor [weak self, weak splash] in
      try? await Task.sleep(for: .milliseconds(Int(duration * 1_000)))
      guard
        !Task.isCancelled,
        let self,
        let splash,
        self.launchSplashView === splash
      else { return }

      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.22
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        splash.animator().alphaValue = 0
      } completionHandler: { [weak self, weak splash] in
        Task { @MainActor in
          splash?.removeFromSuperview()
          if self?.launchSplashView === splash {
            self?.launchSplashView = nil
            self?.launchSplashTask = nil
          }
        }
      }
    }
  }

  func preferredPreviewSizes(for sourceSizes: [CGSize]) -> [CGSize] {
    CanvasMath.previewSizes(
      for: sourceSizes,
      expand: expandsLandscapePreviews
    )
  }

  func initialCamera(fitting fallback: CameraState) -> CameraState {
    desktopPages.selectedPage.camera ?? fallback
  }

  func applyPreviewSizePreference(fitAll: Bool) {
    let sizes = preferredPreviewSizes(for: nodes.map(\.sourceFrame.size))
    var changed = false
    for (node, size) in zip(nodes, sizes) where node.worldFrame.size != size {
      let center = CGPoint(x: node.worldFrame.midX, y: node.worldFrame.midY)
      node.worldFrame = CGRect(
        x: center.x - size.width / 2,
        y: center.y - size.height / 2,
        width: size.width,
        height: size.height
      )
      changed = true
    }
    guard changed else { return }
    needsDisplay = true
    schedulePreviewToolTipUpdate()
    if fitAll, !nodes.isEmpty {
      animateCamera(to: CanvasMath.fitCamera(frames: nodes.map(\.worldFrame), in: bounds)) {}
    }
  }

  func setNeedsDisplay(for windowIDs: [CGWindowID]) {
    let ids = Set(windowIDs)
    for node in nodes where ids.contains(node.id) {
      let rect = CanvasMath.viewRect(for: node.worldFrame, camera: camera, bounds: bounds)
      setNeedsDisplay(rect.insetBy(dx: -48, dy: -48))
    }
  }

  func replacePreview(_ image: NSImage, for node: WindowNode) {
    guard let previousPreview = node.preview else {
      node.preview = image
      setNeedsDisplay(for: [node.id])
      return
    }

    let revealsAdditionalDetail = image.representations.reduce(0) {
      max($0, max($1.pixelsWide, $1.pixelsHigh))
    } > previousPreview.representations.reduce(0) {
      max($0, max($1.pixelsWide, $1.pixelsHigh))
    }
    node.preview = image
    guard revealsAdditionalDetail else {
      previousPreviews[node.id] = nil
      previewFadeStartedAt[node.id] = nil
      if previewFadeStartedAt.isEmpty {
        previewFadeDisplayLink?.invalidate()
        previewFadeDisplayLink = nil
      }
      setNeedsDisplay(for: [node.id])
      return
    }

    previousPreviews[node.id] = previousPreview
    previewFadeStartedAt[node.id] = CACurrentMediaTime()
    setNeedsDisplay(for: [node.id])

    guard previewFadeDisplayLink == nil else { return }
    let displayLink = displayLink(
      target: self,
      selector: #selector(stepPreviewFadeAnimation(_:))
    )
    previewFadeDisplayLink = displayLink
    displayLink.add(to: .main, forMode: .common)
  }

  @objc private func stepPreviewFadeAnimation(_ displayLink: CADisplayLink) {
    let now = CACurrentMediaTime()
    let transitions = previewFadeStartedAt
    var finishedWindowIDs: [CGWindowID] = []

    for (windowID, startedAt) in transitions
    where now - startedAt >= Self.previewFadeDuration {
      finishedWindowIDs.append(windowID)
    }
    for windowID in finishedWindowIDs {
      previousPreviews[windowID] = nil
      previewFadeStartedAt[windowID] = nil
    }

    setNeedsDisplay(for: Array(transitions.keys))
    guard previewFadeStartedAt.isEmpty else { return }
    previewFadeDisplayLink = nil
    displayLink.invalidate()
  }

  var defersBackgroundWork: Bool {
    interaction != nil
      || cameraAnimation != nil
      || CACurrentMediaTime() < backgroundWorkDeferredUntil
  }

  func refreshMetadata(for windowIDs: [CGWindowID]) {
    setNeedsDisplay(for: windowIDs)
    updateNavigatorPanel()
    if isSearching { updateSearchResults(centerSelection: false) }
  }

  func handleNavigationKey(_ event: NSEvent) -> Bool {
    guard !settingsPopover.isShown else { return false }
    guard desktopTitleField.currentEditor() == nil else { return false }
    let modifiers = event.modifierFlags.intersection([.command, .control, .option])
    guard modifiers.isEmpty else { return false }

    if isSearching { return false }

    switch event.keyCode {
    case 123:
      moveSelection(.left)
    case 124:
      moveSelection(.right)
    case 125:
      moveSelection(.down)
    case 126:
      moveSelection(.up)
    case 36, 76:
      focusSelectedWindow()
    default:
      guard let text = event.characters,
        text.rangeOfCharacter(from: .alphanumerics) != nil
      else { return false }
      beginSearch(with: text)
    }
    return true
  }

  @discardableResult
  func dismissSettings() -> Bool {
    guard settingsPopover.isShown else { return false }
    settingsPopover.close()
    return true
  }

  @discardableResult
  func dismissSearch() -> Bool {
    guard isSearching else { return false }
    endSearch()
    return true
  }

  @discardableResult
  func dismissDesktopTitleEditing() -> Bool {
    guard desktopTitleField.currentEditor() != nil else { return false }
    window?.makeFirstResponder(self)
    return true
  }

  func animateCamera(
    to target: CameraState,
    tracking worldPoint: CGPoint? = nil,
    isolating focusWindowID: CGWindowID? = nil,
    duration: TimeInterval = 0.35,
    cameraCompletionFraction: CGFloat = 1,
    progressHandler: (@MainActor @Sendable (CGFloat) -> Void)? = nil,
    completion: @escaping @MainActor @Sendable () -> Void
  ) {
    setHoveredWindow(nil)
    animationDisplayLink?.invalidate()
    isPresentingFinalAnimationFrame = false
    if let focusWindowID {
      focusTransitionWindowID = focusWindowID
      setFocusTransitionProgress(0)
    } else {
      endFocusTransition()
    }
    cameraAnimation = CameraAnimation(
      start: camera,
      target: target,
      trackingWorldPoint: worldPoint,
      focusWindowID: focusWindowID,
      cameraCompletionFraction: min(1, max(0.01, cameraCompletionFraction)),
      progressHandler: progressHandler,
      startedAt: CACurrentMediaTime(),
      duration: duration,
      completion: completion
    )
    let displayLink = displayLink(
      target: self, selector: #selector(stepCameraAnimation(_:)))
    animationDisplayLink = displayLink
    displayLink.add(to: .main, forMode: .common)
  }

  @objc private func stepCameraAnimation(_ displayLink: CADisplayLink) {
    guard let animation = cameraAnimation else {
      displayLink.invalidate()
      return
    }
    if isPresentingFinalAnimationFrame {
      displayLink.invalidate()
      animationDisplayLink = nil
      cameraAnimation = nil
      isPresentingFinalAnimationFrame = false
      animation.completion()
      return
    }
    let elapsed = CACurrentMediaTime() - animation.startedAt
    let progress = min(1, elapsed / animation.duration)
    let cameraProgress = min(1, progress / animation.cameraCompletionFraction)
    let eased = CanvasMath.easedTransition(cameraProgress)
    if animation.focusWindowID != nil {
      setFocusTransitionProgress(cameraProgress)
    }
    camera = CanvasMath.interpolatedCamera(
      from: animation.start,
      to: animation.target,
      tracking: animation.trackingWorldPoint,
      progress: eased,
      in: bounds
    )
    animation.progressHandler?(progress)
    if progress >= 1 {
      isPresentingFinalAnimationFrame = true
    }
  }

  func endFocusTransition() {
    focusTransitionWindowID = nil
    setFocusTransitionProgress(0)
  }

  private func setFocusTransitionProgress(_ progress: CGFloat) {
    focusTransitionProgress = min(1, max(0, progress))
    let opacity = CanvasMath.focusBackdropOpacity(progress: focusTransitionProgress)
    for subview in subviews { subview.alphaValue = opacity }
    needsDisplay = true
  }

  private var hoverTargetWindowIDs: Set<CGWindowID> {
    if isHoveringGroupSelection { return groupSelectionIDs }
    return hoveredWindowID.map { [$0] } ?? []
  }

  private func setHoveredWindow(_ windowID: CGWindowID?, asGroup: Bool = false) {
    guard windowID != hoveredWindowID || asGroup != isHoveringGroupSelection else { return }
    let previousTargets = hoverTargetWindowIDs
    hoveredWindowID = windowID
    isHoveringGroupSelection = asGroup

    var animatedIDs = Set(windowHoverProgress.keys)
    animatedIDs.formUnion(previousTargets)
    animatedIDs.formUnion(hoverTargetWindowIDs)
    guard !animatedIDs.isEmpty else { return }

    windowHoverStartProgress = Dictionary(
      uniqueKeysWithValues: animatedIDs.map { ($0, windowHoverProgress[$0] ?? 0) })
    windowHoverAnimationStartedAt = CACurrentMediaTime()
    windowHoverDisplayLink?.invalidate()
    let displayLink = displayLink(
      target: self,
      selector: #selector(stepWindowHoverAnimation(_:))
    )
    windowHoverDisplayLink = displayLink
    displayLink.add(to: .main, forMode: .common)
  }

  @objc private func stepWindowHoverAnimation(_ displayLink: CADisplayLink) {
    guard let startedAt = windowHoverAnimationStartedAt else {
      displayLink.invalidate()
      return
    }

    let progress = min(1, (CACurrentMediaTime() - startedAt) / 0.16)
    let eased = 1 - pow(1 - progress, 3)
    let targets = hoverTargetWindowIDs
    for (windowID, start) in windowHoverStartProgress {
      let target: CGFloat = targets.contains(windowID) ? 1 : 0
      windowHoverProgress[windowID] = start + (target - start) * eased
    }
    needsDisplay = true

    guard progress >= 1 else { return }
    windowHoverProgress = windowHoverProgress.filter { $0.value > 0.001 }
    windowHoverStartProgress.removeAll(keepingCapacity: true)
    windowHoverAnimationStartedAt = nil
    windowHoverDisplayLink = nil
    displayLink.invalidate()
  }

  private func animateSelection(from oldID: CGWindowID?, to newID: CGWindowID?) {
    selectionStaysWithinApplication = {
      guard let oldID, let newID,
        let oldNode = nodes.first(where: { $0.id == oldID }),
        let newNode = nodes.first(where: { $0.id == newID })
      else { return false }
      return oldNode.processID == newNode.processID
    }()
    var current = selectionProgress
    if let oldID, current[oldID] == nil { current[oldID] = 1 }
    let outgoing = current.max { $0.value < $1.value }
    selectionStartProgress.removeAll(keepingCapacity: true)
    if let outgoing, outgoing.key != newID {
      selectionStartProgress[outgoing.key] = outgoing.value
    }
    if let newID {
      selectionStartProgress[newID] = outgoing?.key == newID ? (outgoing?.value ?? 0) : 0
    }
    guard !selectionStartProgress.isEmpty else { return }
    selectionProgress = selectionStartProgress
    selectionAnimationStartedAt = CACurrentMediaTime()
    selectionDisplayLink?.invalidate()
    let displayLink = displayLink(
      target: self,
      selector: #selector(stepSelectionAnimation(_:))
    )
    selectionDisplayLink = displayLink
    displayLink.add(to: .main, forMode: .common)
  }

  @objc private func stepSelectionAnimation(_ displayLink: CADisplayLink) {
    guard let startedAt = selectionAnimationStartedAt else {
      displayLink.invalidate()
      return
    }

    let progress = min(
      1,
      (CACurrentMediaTime() - startedAt) / Self.selectionTransitionDuration
    )
    for (windowID, start) in selectionStartProgress {
      let incoming = windowID == selectedWindowID
      let phase = selectionStaysWithinApplication
        ? CanvasMath.easedTransition(progress)
        : CanvasMath.selectionHandoffPhase(progress: progress, incoming: incoming)
      let target: CGFloat = incoming ? 1 : 0
      selectionProgress[windowID] = start + (target - start) * phase
    }
    let animatedProcessIDs = Set(
      nodes.lazy
        .filter { self.selectionStartProgress[$0.id] != nil }
        .map(\.processID)
    )
    setNeedsDisplay(
      for: nodes.compactMap { animatedProcessIDs.contains($0.processID) ? $0.id : nil }
    )

    guard progress >= 1 else { return }
    selectionProgress = selectionProgress.filter { $0.value > 0.001 }
    selectionStartProgress.removeAll(keepingCapacity: true)
    selectionStaysWithinApplication = false
    selectionAnimationStartedAt = nil
    selectionDisplayLink = nil
    displayLink.invalidate()
  }

  override func mouseDown(with event: NSEvent) {
    guard cameraAnimation == nil else { return }
    deferBackgroundWork()
    let point = convert(event.locationInWindow, from: nil)
    if navigatorHeaderFrame.contains(point) {
      interaction = .navigatorPanel(
        start: point,
        origin: navigatorPanelFrame.origin,
        button: navigatorHeaderButton(at: point),
        dragged: false
      )
      return
    }
    if let projection = miniMapProjection(), projection.frame.contains(point) {
      moveCameraCenter(toMiniMapPoint: point, projection: projection)
      interaction = .miniMap
      return
    }
    if navigatorPanelFrame.contains(point) { return }
    if let node = hitNode(at: point) {
      selectedWindowID = node.id
      if !groupSelectionIDs.contains(node.id) { groupSelectionIDs.removeAll() }
      let movingIDs: Set<CGWindowID> =
        groupSelectionIDs.contains(node.id) ? groupSelectionIDs : [node.id]
      let frames = Dictionary(
        uniqueKeysWithValues: nodes.compactMap { candidate in
          movingIDs.contains(candidate.id) ? (candidate.id, candidate.worldFrame) : nil
        }
      )
      interaction = .window(node: node, start: point, frames: frames, dragged: false)
      if movingIDs.count > 1 { NSCursor.closedHand.set() }
    } else if groupSelectionBounds()?.contains(point) == true {
      let frames = Dictionary(
        uniqueKeysWithValues: nodes.compactMap { candidate in
          groupSelectionIDs.contains(candidate.id) ? (candidate.id, candidate.worldFrame) : nil
        }
      )
      interaction = .group(start: point, frames: frames, dragged: false)
      NSCursor.closedHand.set()
    } else {
      groupSelectionIDs.removeAll()
      setHoveredWindow(nil)
      interaction = .marquee(start: point, current: point, dragged: false)
      needsDisplay = true
    }
  }

  override func mouseDragged(with event: NSEvent) {
    guard let interaction else { return }
    deferBackgroundWork()
    let point = convert(event.locationInWindow, from: nil)

    switch interaction {
    case .miniMap:
      guard let projection = miniMapProjection() else { return }
      moveCameraCenter(toMiniMapPoint: point, projection: projection)

    case .navigatorPanel(let start, let originalOrigin, let button, let wasDragged):
      let distance = hypot(point.x - start.x, point.y - start.y)
      let dragged = wasDragged || distance >= 4
      if dragged {
        moveNavigatorPanel(
          to: CGPoint(
            x: originalOrigin.x + point.x - start.x,
            y: originalOrigin.y + point.y - start.y
          )
        )
      }
      self.interaction = .navigatorPanel(
        start: start,
        origin: originalOrigin,
        button: button,
        dragged: dragged
      )

    case .marquee(let start, _, let wasDragged):
      let distance = hypot(point.x - start.x, point.y - start.y)
      let dragged = wasDragged || distance >= 4
      if dragged {
        groupSelectionIDs = CanvasMath.windowIDs(
          intersecting: CanvasMath.selectionRect(from: start, to: point),
          frames: Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.worldFrame) }),
          camera: camera,
          bounds: bounds
        )
      }
      self.interaction = .marquee(start: start, current: point, dragged: dragged)
      needsDisplay = true

    case .group(let start, let originalFrames, let wasDragged):
      let distance = hypot(point.x - start.x, point.y - start.y)
      let dragged = wasDragged || distance >= 4
      if dragged {
        let translation = CanvasMath.worldTranslation(
          forViewTranslation: CGPoint(x: point.x - start.x, y: point.y - start.y),
          zoom: camera.zoom
        )
        for candidate in nodes {
          guard let frame = originalFrames[candidate.id] else { continue }
          candidate.worldFrame = frame.offsetBy(dx: translation.x, dy: translation.y)
        }
        needsDisplay = true
      }
      self.interaction = .group(start: start, frames: originalFrames, dragged: dragged)

    case .window(let node, let start, let originalFrames, let wasDragged):
      let distance = hypot(point.x - start.x, point.y - start.y)
      let dragged = wasDragged || distance >= 4
      if dragged {
        let translation = CanvasMath.worldTranslation(
          forViewTranslation: CGPoint(x: point.x - start.x, y: point.y - start.y),
          zoom: camera.zoom
        )
        for candidate in nodes {
          guard let frame = originalFrames[candidate.id] else { continue }
          candidate.worldFrame = frame.offsetBy(dx: translation.x, dy: translation.y)
        }
        needsDisplay = true
      }
      self.interaction = .window(
        node: node,
        start: start,
        frames: originalFrames,
        dragged: dragged
      )
    }
  }

  override func mouseUp(with event: NSEvent) {
    deferBackgroundWork()
    let point = convert(event.locationInWindow, from: nil)
    defer {
      interaction = nil
      needsDisplay = true
      updateHover(at: point)
    }
    switch interaction {
    case .navigatorPanel(_, _, let button, let dragged):
      if dragged {
        persistNavigatorPanelOrigin()
      } else {
        button?.performClick(nil)
      }
    case .window(let node, _, _, let dragged) where !dragged:
      delegate?.canvasView(self, didRequestFocus: node)
    default:
      break
    }
  }

  override func scrollWheel(with event: NSEvent) {
    guard cameraAnimation == nil else { return }
    deferBackgroundWork()
    camera.center = CGPoint(
      x: camera.center.x - event.scrollingDeltaX / camera.zoom,
      y: camera.center.y + event.scrollingDeltaY / camera.zoom
    )
  }

  override func magnify(with event: NSEvent) {
    guard cameraAnimation == nil else { return }
    deferBackgroundWork()
    let point = convert(event.locationInWindow, from: nil)
    camera = CanvasMath.zoomedCamera(
      camera,
      to: camera.zoom * (1 + event.magnification),
      around: point,
      in: bounds
    )
  }

  private func hitNode(at point: CGPoint) -> WindowNode? {
    nodes.reversed().first { node in
      let rect = CanvasMath.viewRect(for: node.worldFrame, camera: camera, bounds: bounds)
      return rect.insetBy(dx: -20, dy: -30).contains(point)
    }
  }

  private func updateHover(at point: CGPoint) {
    guard cameraAnimation == nil, !navigatorPanelFrame.contains(point) else {
      setHoveredWindow(nil)
      return
    }
    let node = hitNode(at: point)
    let isOverGroup = groupSelectionBounds()?.contains(point) == true
      && (node.map { groupSelectionIDs.contains($0.id) } ?? true)
    let wasOverGroup = isHoveringGroupSelection
    setHoveredWindow(isOverGroup ? nil : node?.id, asGroup: isOverGroup)
    if isOverGroup {
      NSCursor.openHand.set()
    } else if wasOverGroup {
      NSCursor.arrow.set()
    }
  }

  private func moveSelection(_ direction: CanvasDirection) {
    guard !nodes.isEmpty else { return }

    guard let selected = nodes.first(where: { $0.id == selectedWindowID }) else {
      let closest = nodes.min {
        hypot($0.worldFrame.midX - camera.center.x, $0.worldFrame.midY - camera.center.y)
          < hypot($1.worldFrame.midX - camera.center.x, $1.worldFrame.midY - camera.center.y)
      }
      selectedWindowID = closest?.id
      return
    }

    let candidates = nodes.filter { $0.id != selected.id }.map {
      (id: $0.id, center: CGPoint(x: $0.worldFrame.midX, y: $0.worldFrame.midY))
    }
    guard
      let nextID = CanvasMath.directionalNeighbor(
        from: CGPoint(x: selected.worldFrame.midX, y: selected.worldFrame.midY),
        candidates: candidates,
        direction: direction
      ),
      let next = nodes.first(where: { $0.id == nextID })
    else { return }

    selectedWindowID = next.id
    animateCamera(
      to: CameraState(
        center: CGPoint(x: next.worldFrame.midX, y: next.worldFrame.midY),
        zoom: camera.zoom
      ),
      duration: Self.selectionTransitionDuration,
      completion: {}
    )
  }

  private func miniMapProjection() -> MiniMapProjection? {
    guard !nodes.isEmpty, bounds.width >= 480, bounds.height >= 320 else { return nil }

    let panel = navigatorPanelFrame
    let frame = CGRect(
      x: panel.minX + 12,
      y: panel.minY + 52,
      width: panel.width - 24,
      height: 140
    )
    let contentBounds = frame.insetBy(dx: 10, dy: 10)
    let lowerLeft = CanvasMath.viewToWorld(
      CGPoint(x: bounds.minX, y: bounds.minY), camera: camera, bounds: bounds)
    let upperRight = CanvasMath.viewToWorld(
      CGPoint(x: bounds.maxX, y: bounds.maxY), camera: camera, bounds: bounds)
    let viewportWorldFrame = CGRect(
      x: lowerLeft.x,
      y: lowerLeft.y,
      width: upperRight.x - lowerLeft.x,
      height: upperRight.y - lowerLeft.y
    )
    let frames = nodes.map(\.worldFrame) + [viewportWorldFrame]
    let worldBounds = frames.dropFirst().reduce(frames[0]) { $0.union($1) }
    let zoom = min(
      contentBounds.width / worldBounds.width,
      contentBounds.height / worldBounds.height
    )
    let miniMapCamera = CameraState(
      center: CGPoint(x: worldBounds.midX, y: worldBounds.midY),
      zoom: zoom
    )
    return MiniMapProjection(
      frame: frame,
      contentBounds: contentBounds,
      camera: miniMapCamera,
      viewportWorldFrame: viewportWorldFrame
    )
  }

  private func moveCameraCenter(toMiniMapPoint point: CGPoint, projection: MiniMapProjection) {
    let clampedPoint = CGPoint(
      x: min(projection.contentBounds.maxX, max(projection.contentBounds.minX, point.x)),
      y: min(projection.contentBounds.maxY, max(projection.contentBounds.minY, point.y))
    )
    camera.center = CanvasMath.viewToWorld(
      clampedPoint,
      camera: projection.camera,
      bounds: projection.contentBounds
    )
  }

  private func drawGrid(in dirtyRect: CGRect) {
    let spacing = CanvasMath.gridSpacing(at: camera.zoom)
    let dotSize = CanvasMath.gridDotSize(at: camera.zoom)
    let opacity = CanvasMath.gridOpacity(at: camera.zoom)
    guard opacity > 0 else { return }
    let origin = CanvasMath.worldToView(.zero, camera: camera, bounds: bounds)
    let patternColor: NSColor
    if gridPatternZoom == camera.zoom, let gridPatternColor {
      patternColor = gridPatternColor
    } else {
      let tile = NSImage(
        size: CGSize(width: spacing, height: spacing),
        flipped: false
      ) { rect in
        NSColor.white.withAlphaComponent(opacity).setFill()
        NSBezierPath(
          ovalIn: CGRect(
            x: rect.midX - dotSize / 2,
            y: rect.midY - dotSize / 2,
            width: dotSize,
            height: dotSize
          )
        ).fill()
        return true
      }
      patternColor = NSColor(patternImage: tile)
      gridPatternZoom = camera.zoom
      gridPatternColor = patternColor
    }

    guard let context = NSGraphicsContext.current else { return }
    let previousPhase = context.patternPhase
    context.patternPhase = CGPoint(
      x: origin.x - spacing / 2,
      y: origin.y - spacing / 2
    )
    patternColor.setFill()
    dirtyRect.fill()
    context.patternPhase = previousPhase
  }

  private func deferBackgroundWork() {
    backgroundWorkDeferredUntil = CACurrentMediaTime() + 0.25
  }

  private func drawGroupSelection() {
    if case .marquee(let start, let current, let dragged) = interaction, dragged {
      drawSelectionBox(
        CanvasMath.selectionRect(from: start, to: current),
        fillAlpha: 0.14,
        strokeAlpha: 0.88
      )
      return
    }

    guard let bounds = groupSelectionBounds() else { return }
    let hover = groupSelectionIDs.map { windowHoverProgress[$0] ?? 0 }.max() ?? 0
    drawSelectionBox(
      bounds.insetBy(dx: -3 * hover, dy: -3 * hover),
      fillAlpha: 0.14 + 0.05 * hover,
      strokeAlpha: 0.72 + 0.2 * hover
    )
  }

  private func groupSelectionBounds() -> CGRect? {
    CanvasMath.groupSelectionBounds(
      for: nodes.compactMap { node in
        guard groupSelectionIDs.contains(node.id) else { return nil }
        return CanvasMath.viewRect(for: node.worldFrame, camera: camera, bounds: bounds)
      }
    )
  }

  private func drawSelectionBox(
    _ rect: CGRect,
    fillAlpha: CGFloat,
    strokeAlpha: CGFloat
  ) {
    let path = NSBezierPath(rect: rect)
    groupSelectionColor.withAlphaComponent(fillAlpha).setFill()
    path.fill()
    groupSelectionColor.withAlphaComponent(strokeAlpha).setStroke()
    path.lineWidth = 2
    path.stroke()
  }

  private func draw(node: WindowNode, in rect: CGRect, selectedProcessID: pid_t?) {
    let cornerRadius = max(5, min(14, 12 * camera.zoom))
    NSGraphicsContext.saveGraphicsState()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
    shadow.shadowBlurRadius = 26 * min(1, camera.zoom)
    shadow.shadowOffset = CGSize(width: 0, height: -8)
    shadow.set()

    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()
    NSColor(calibratedWhite: 0.11, alpha: 1).setFill()
    rect.fill()
    if let previousPreview = previousPreviews[node.id],
      let fadeStartedAt = previewFadeStartedAt[node.id]
    {
      previousPreview.draw(
        in: rect,
        from: .zero,
        operation: .sourceOver,
        fraction: 1
      )
      let elapsed = CACurrentMediaTime() - fadeStartedAt
      let progress = min(1, elapsed / Self.previewFadeDuration)
      node.preview?.draw(
        in: rect,
        from: .zero,
        operation: .sourceOver,
        fraction: CanvasMath.easedTransition(progress)
      )
    } else {
      node.preview?.draw(
        in: rect,
        from: .zero,
        operation: .sourceOver,
        fraction: 1
      )
    }
    NSGraphicsContext.restoreGraphicsState()

    let isSelected = node.id == selectedWindowID
    let isSelectedApplication = selectedProcessID.map { $0 == node.processID } ?? false
    let isGroupSelection =
      groupSelectionIDs.count > 1 && groupSelectionIDs.contains(node.id)
    let primarySelectionColor = isGroupSelection ? groupSelectionColor : selectionColor
    let selectionPhases = CanvasMath.selectionAnimationPhases(
      progress: selectionProgress[node.id] ?? (isSelected ? 1 : 0)
    )
    let applicationSelectionPhases = CanvasMath.selectionAnimationPhases(
      progress: selectedWindowID.flatMap { selectionProgress[$0] } ?? 1
    )

    NSColor.white.withAlphaComponent(0.16).setStroke()
    path.lineWidth = 1
    path.stroke()

    let sameApplicationPrimaryProgress: CGFloat? =
      selectionStaysWithinApplication && isSelectedApplication
      ? selectionProgress[node.id] ?? (isSelected ? 1 : 0)
      : nil
    if let sameApplicationPrimaryProgress {
      let metrics = CanvasMath.sameApplicationSelectionMetrics(
        primaryProgress: sameApplicationPrimaryProgress
      )
      let borderInset = 2 + metrics.borderWidth / 2
      let borderPath = NSBezierPath(
        roundedRect: rect.insetBy(dx: -borderInset, dy: -borderInset),
        xRadius: cornerRadius + borderInset,
        yRadius: cornerRadius + borderInset
      )
      NSGraphicsContext.saveGraphicsState()
      if sameApplicationPrimaryProgress > 0 {
        let glow = NSShadow()
        glow.shadowColor = primarySelectionColor.withAlphaComponent(
          0.9 * sameApplicationPrimaryProgress
        )
        glow.shadowBlurRadius = 16 * sameApplicationPrimaryProgress
        glow.shadowOffset = .zero
        glow.set()
      }
      primarySelectionColor.setStroke()
      borderPath.lineWidth = metrics.borderWidth
      borderPath.stroke()
      NSGraphicsContext.restoreGraphicsState()
    } else if !isSelected {
      let secondaryBorderColor: NSColor? = if isGroupSelection {
        groupSelectionColor
      } else if isSelectedApplication && applicationSelectionPhases.border > 0 {
        selectionColor.withAlphaComponent(applicationSelectionPhases.border)
      } else {
        nil
      }
      if let secondaryBorderColor {
        let borderWidth: CGFloat = 2
        let borderInset = 2 + borderWidth / 2
        let borderPath = NSBezierPath(
          roundedRect: rect.insetBy(dx: -borderInset, dy: -borderInset),
          xRadius: cornerRadius + borderInset,
          yRadius: cornerRadius + borderInset
        )
        secondaryBorderColor.setStroke()
        borderPath.lineWidth = borderWidth
        borderPath.stroke()
      }
    }

    if sameApplicationPrimaryProgress == nil && selectionPhases.border > 0 {
      let borderWidth: CGFloat = 4
      let borderInset = 2 + borderWidth / 2
      let borderPath = NSBezierPath(
        roundedRect: rect.insetBy(dx: -borderInset, dy: -borderInset),
        xRadius: cornerRadius + borderInset,
        yRadius: cornerRadius + borderInset
      )
      NSGraphicsContext.saveGraphicsState()
      let glow = NSShadow()
      glow.shadowColor = primarySelectionColor.withAlphaComponent(
        0.9 * selectionPhases.border)
      glow.shadowBlurRadius = 16
      glow.shadowOffset = .zero
      glow.set()
      primarySelectionColor.withAlphaComponent(selectionPhases.border).setStroke()
      borderPath.lineWidth = borderWidth
      borderPath.stroke()
      NSGraphicsContext.restoreGraphicsState()
    }

    let badgeSize = Self.appIconSize * CanvasMath.appIconScale(at: camera.zoom)
    drawAppIcon(for: node, in: rect, size: badgeSize)
    drawPreviewStatus(for: node, in: rect)

    let titleX = rect.minX + badgeSize / 2 + 8
    let titleSelectionProgress = sameApplicationPrimaryProgress == nil
      ? isGroupSelection
        ? 1
        : isSelectedApplication && !isSelected
          ? applicationSelectionPhases.title
          : selectionPhases.title
      : 1
    let titleLift = sameApplicationPrimaryProgress.map {
      CanvasMath.sameApplicationSelectionMetrics(primaryProgress: $0).titleLift
    } ?? CanvasMath.selectionTitleLift(
      progress: titleSelectionProgress,
      isPrimary: isSelected || selectionStartProgress[node.id] != nil
    )
    let titleRect = CGRect(
      x: titleX,
      y: rect.maxY + 2 + titleLift,
      width: max(0, rect.maxX - titleX),
      height: 16
    )
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byTruncatingTail
    let titleColor = NSColor.white.withAlphaComponent(0.76).blended(
      withFraction: titleSelectionProgress,
      of: isGroupSelection ? groupSelectionColor : selectionColor
    ) ?? (isGroupSelection ? groupSelectionColor : selectionColor)
    let titleVisibility = CanvasMath.titleVisibility(
      at: camera.zoom,
      availableWidth: titleRect.width
    )
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 12, weight: isSelected ? .bold : .medium),
      .foregroundColor: titleColor.withAlphaComponent(
        titleColor.alphaComponent * titleVisibility
      ),
      .paragraphStyle: paragraph,
    ]
    NSString(string: node.title).draw(
      in: titleRect,
      withAttributes: attributes
    )
  }

  private func drawAppIcon(for node: WindowNode, in rect: CGRect, size badgeSize: CGFloat) {
    guard let icon = node.icon else { return }
    let badgeFrame = CGRect(
      x: rect.minX - badgeSize / 2,
      y: rect.maxY - badgeSize / 2,
      width: badgeSize,
      height: badgeSize
    )
    let badgeCornerRadius = badgeSize * 0.22
    let badgePath = NSBezierPath(
      roundedRect: badgeFrame,
      xRadius: badgeCornerRadius,
      yRadius: badgeCornerRadius
    )

    NSGraphicsContext.saveGraphicsState()
    let outside = NSBezierPath(rect: badgeFrame.insetBy(dx: -21, dy: -21))
    outside.append(badgePath)
    outside.windingRule = .evenOdd
    outside.addClip()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.36)
    shadow.shadowBlurRadius = 7.5 * badgeSize / Self.appIconSize
    shadow.shadowOffset = CGSize(width: 0, height: -2.25 * badgeSize / Self.appIconSize)
    shadow.set()
    NSColor.white.setFill()
    badgePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    badgePath.addClip()
    icon.draw(
      in: badgeFrame,
      from: appIconSourceRect(for: icon),
      operation: .sourceOver,
      fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
  }

  private func appIconSourceRect(for icon: NSImage) -> CGRect {
    let key = ObjectIdentifier(icon)
    if let cached = appIconSourceRects[key] { return cached }

    let sampleSize = 128
    guard
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: sampleSize,
        pixelsHigh: sampleSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
      ),
      let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else { return .zero }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: sampleSize, height: sampleSize).fill()
    icon.draw(
      in: NSRect(x: 0, y: 0, width: sampleSize, height: sampleSize),
      from: .zero,
      operation: .copy,
      fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    var minX = sampleSize
    var minY = sampleSize
    var maxX = -1
    var maxY = -1
    for y in 0..<sampleSize {
      for x in 0..<sampleSize where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
      }
    }

    guard maxX >= minX, maxY >= minY else { return .zero }
    let width = maxX - minX + 1
    let height = maxY - minY + 1
    let side = max(width, height)
    let squareMinX = max(0, min(sampleSize - side, minX - (side - width) / 2))
    let squareMinY = max(0, min(sampleSize - side, minY - (side - height) / 2))
    let trim = CGFloat(side) * 0.03
    let scaleX = icon.size.width / CGFloat(sampleSize)
    let scaleY = icon.size.height / CGFloat(sampleSize)
    let sourceRect = CGRect(
      x: (CGFloat(squareMinX) + trim) * scaleX,
      y: (CGFloat(squareMinY) + trim) * scaleY,
      width: (CGFloat(side) - 2 * trim) * scaleX,
      height: (CGFloat(side) - 2 * trim) * scaleY
    )
    appIconSourceRects[key] = sourceRect
    return sourceRect
  }

  private func previewStatusFrame(in rect: CGRect) -> CGRect {
    let size = 1.5 * max(6, min(9, 9 * sqrt(camera.zoom)))
    let inset = max(6, size * 0.75)
    return CGRect(
      x: rect.maxX - inset - size,
      y: rect.maxY - inset - size,
      width: size,
      height: size
    )
  }

  private func drawPreviewStatus(for node: WindowNode, in rect: CGRect) {
    let color: NSColor = switch node.previewState {
    case .loading: NSColor(srgbRed: 1, green: 0.62, blue: 0.15, alpha: 1)
    case .current: NSColor(srgbRed: 0.25, green: 0.85, blue: 0.39, alpha: 1)
    case .failed: NSColor(srgbRed: 1, green: 0.27, blue: 0.23, alpha: 1)
    }

    let indicator = NSBezierPath(ovalIn: previewStatusFrame(in: rect))
    color.setFill()
    indicator.fill()
    NSColor.white.setStroke()
    indicator.lineWidth = 2
    indicator.stroke()
  }

  private func schedulePreviewToolTipUpdate() {
    previewToolTipUpdateTask?.cancel()
    previewToolTipUpdateTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(120))
      guard !Task.isCancelled else { return }
      self?.updatePreviewToolTips()
    }
  }

  private func updatePreviewToolTips() {
    previewToolTipTags.forEach(removeToolTip)
    previewToolTipTags.removeAll(keepingCapacity: true)
    previewToolTipWindowIDs.removeAll(keepingCapacity: true)

    for node in nodes {
      let rect = CanvasMath.viewRect(for: node.worldFrame, camera: camera, bounds: bounds)
      guard rect.intersects(bounds) else { continue }
      let tag = addToolTip(
        previewStatusFrame(in: rect).insetBy(dx: -4, dy: -4),
        owner: self,
        userData: nil
      )
      previewToolTipTags.append(tag)
      previewToolTipWindowIDs[tag] = node.id
    }
  }

  func view(
    _ view: NSView,
    stringForToolTip tag: NSView.ToolTipTag,
    point: NSPoint,
    userData data: UnsafeMutableRawPointer?
  ) -> String {
    guard
      let windowID = previewToolTipWindowIDs[tag],
      let node = nodes.first(where: { $0.id == windowID })
    else { return "Preview status" }
    return node.previewState.toolTip(hasPreview: node.preview != nil)
  }

  private func drawEmptyState() {
    drawOpenPlaneLaunchMessage(in: bounds)
  }

  private func drawStatus(_ status: String) {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 12, weight: .medium),
      .foregroundColor: NSColor.white.withAlphaComponent(0.62),
    ]
    status.draw(at: CGPoint(x: 24, y: 20), withAttributes: attributes)
  }

  private func drawDebugInformation() {
    let label = String(format: "Zoom %.2f×", camera.zoom)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
      .foregroundColor: NSColor.white.withAlphaComponent(0.9),
    ]
    let labelSize = label.size(withAttributes: attributes)
    let frame = CGRect(
      x: 20,
      y: bounds.maxY - 48,
      width: labelSize.width + 20,
      height: 28
    )
    NSColor.black.withAlphaComponent(0.58).setFill()
    NSBezierPath(roundedRect: frame, xRadius: 8, yRadius: 8).fill()
    label.draw(
      at: CGPoint(
        x: frame.minX + 10,
        y: frame.midY - labelSize.height / 2
      ),
      withAttributes: attributes
    )
  }

  private var navigatorPanelFrame: CGRect {
    let fallback = CGPoint(
      x: bounds.maxX - 24 - Self.navigatorPanelSize.width,
      y: bounds.minY + 96
    )
    return CGRect(
      origin: clampedNavigatorPanelOrigin(navigatorPanelOrigin ?? fallback),
      size: Self.navigatorPanelSize
    )
  }

  private var navigatorHeaderFrame: CGRect {
    let panel = navigatorPanelFrame
    return CGRect(x: panel.minX, y: panel.maxY - 48, width: panel.width, height: 48)
  }

  private func clampedNavigatorPanelOrigin(_ origin: CGPoint) -> CGPoint {
    let availableFrame = CGRect(
      x: bounds.minX + 24,
      y: bounds.minY + 96,
      width: max(0, bounds.width - 48),
      height: max(0, bounds.height - 144)
    )
    return CanvasMath.clampedOrigin(
      origin,
      size: Self.navigatorPanelSize,
      in: availableFrame
    )
  }

  private func moveNavigatorPanel(to origin: CGPoint) {
    let oldFrame = navigatorPanelFrame.insetBy(dx: -28, dy: -28)
    navigatorPanelOrigin = clampedNavigatorPanelOrigin(origin)
    needsLayout = true
    layoutSubtreeIfNeeded()
    let newFrame = navigatorPanelFrame.insetBy(dx: -28, dy: -28)
    setNeedsDisplay(oldFrame.union(newFrame))
  }

  private func persistNavigatorPanelOrigin() {
    let origin = navigatorPanelFrame.origin
    navigatorPanelOrigin = origin
    UserDefaults.standard.set(Double(origin.x), forKey: Self.navigatorPanelXPreferenceKey)
    UserDefaults.standard.set(Double(origin.y), forKey: Self.navigatorPanelYPreferenceKey)
  }

  private func navigatorHeaderButton(at point: CGPoint) -> NSButton? {
    subviews.compactMap { $0 as? NSButton }.first {
      !$0.isHidden && navigatorHeaderFrame.intersects($0.frame) && $0.frame.contains(point)
    }
  }

  private func drawNavigatorPanel() {
    let panel = navigatorPanelFrame
    let panelPath = NSBezierPath(roundedRect: panel, xRadius: 18, yRadius: 18)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
    shadow.shadowBlurRadius = 22
    shadow.shadowOffset = CGSize(width: 0, height: -6)
    shadow.set()
    NSColor(calibratedWhite: 0.025, alpha: 0.94).setFill()
    panelPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    if isSearching {
      NSColor.white.withAlphaComponent(0.1).setFill()
      NSBezierPath(
        roundedRect: navigatorHeaderFrame.insetBy(dx: 8, dy: 8),
        xRadius: 8,
        yRadius: 8
      ).fill()
    }

    let separators = NSBezierPath()
    separators.move(to: CGPoint(x: panel.minX, y: panel.minY + 48))
    separators.line(to: CGPoint(x: panel.maxX, y: panel.minY + 48))
    separators.move(to: CGPoint(x: panel.minX, y: panel.maxY - 48))
    separators.line(to: CGPoint(x: panel.maxX, y: panel.maxY - 48))
    NSColor.white.withAlphaComponent(0.11).setStroke()
    separators.lineWidth = 1
    separators.stroke()

    if isSearching { drawSearchStatus(in: panel) }

    guard let projection = miniMapProjection() else { return }
    let mapBackground = NSBezierPath(roundedRect: projection.frame, xRadius: 8, yRadius: 8)
    NSColor.black.withAlphaComponent(0.28).setFill()
    mapBackground.fill()

    NSGraphicsContext.saveGraphicsState()
    mapBackground.addClip()
    let selectedProcessID = nodes.first(where: { $0.id == selectedWindowID })?.processID
    for node in nodes {
      var rect = CanvasMath.viewRect(
        for: node.worldFrame,
        camera: projection.camera,
        bounds: projection.contentBounds
      )
      if rect.width < 3 { rect = rect.insetBy(dx: -(3 - rect.width) / 2, dy: 0) }
      if rect.height < 3 { rect = rect.insetBy(dx: 0, dy: -(3 - rect.height) / 2) }
      let isGroupSelection =
        groupSelectionIDs.count > 1 && groupSelectionIDs.contains(node.id)
      let color = if isSearching && !matchesSearch(node) {
        NSColor.white.withAlphaComponent(0.1)
      } else if isGroupSelection {
        groupSelectionColor.withAlphaComponent(node.id == selectedWindowID ? 1 : 0.7)
      } else if node.id == selectedWindowID {
        selectionColor
      } else if selectedProcessID.map({ $0 == node.processID }) ?? false {
        selectionColor.withAlphaComponent(0.48)
      } else {
        NSColor.white.withAlphaComponent(0.38)
      }
      color.setFill()
      NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
    }

    let viewportRect = CanvasMath.viewRect(
      for: projection.viewportWorldFrame,
      camera: projection.camera,
      bounds: projection.contentBounds
    )
    let viewportPath = NSBezierPath(roundedRect: viewportRect, xRadius: 4, yRadius: 4)
    NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
    viewportPath.fill()
    NSColor.controlAccentColor.withAlphaComponent(0.9).setStroke()
    viewportPath.lineWidth = 2
    viewportPath.stroke()
    NSGraphicsContext.restoreGraphicsState()
  }

  private func drawSearchStatus(in panel: CGRect) {
    let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let matches = searchResults
    let selectedIndex = matches.firstIndex { $0.id == selectedWindowID }
    let message = CanvasSearch.status(
      query: query,
      resultCount: matches.count,
      selectedIndex: selectedIndex
    )
    let attributes: [NSAttributedString.Key: Any] = [
      .font: Self.navigatorTextFont,
      .foregroundColor: NSColor.white.withAlphaComponent(0.56),
    ]
    let size = message.size(withAttributes: attributes)
    let statusFrame = CGRect(
      x: panel.minX + 74,
      y: panel.minY,
      width: panel.width - 86,
      height: 48
    )
    message.draw(
      at: CGPoint(
        x: statusFrame.minX,
        y: statusFrame.midY - size.height / 2
      ),
      withAttributes: attributes
    )
  }

  private func configureDesktopTitle() {
    desktopTitleField.cell = VerticallyCenteredTextFieldCell(textCell: "")
    desktopTitleField.stringValue = desktopPages.selectedPage.title
    let placeholderStyle = NSMutableParagraphStyle()
    placeholderStyle.alignment = .center
    let placeholder = NSAttributedString(
      string: "Name this desktop",
      attributes: [
        .font: Self.desktopTitleFont,
        .foregroundColor: NSColor.white.withAlphaComponent(0.42),
        .paragraphStyle: placeholderStyle,
      ]
    )
    desktopTitleField.placeholderAttributedString = placeholder
    desktopTitleField.placeholderAttributedStrings = [placeholder]
    desktopTitleField.isBordered = false
    desktopTitleField.drawsBackground = false
    desktopTitleField.isEditable = true
    desktopTitleField.isSelectable = true
    desktopTitleField.focusRingType = .none
    desktopTitleField.alignment = .center
    desktopTitleField.cell?.alignment = .center
    desktopTitleField.font = Self.desktopTitleFont
    desktopTitleField.textColor = .white
    desktopTitleField.cell?.usesSingleLineMode = true
    desktopTitleField.cell?.isScrollable = true
    desktopTitleField.delegate = self
    desktopTitleField.target = self
    desktopTitleField.action = #selector(commitDesktopTitle(_:))
    desktopTitleField.setAccessibilityLabel("Desktop title")
    addSubview(desktopTitleField)
  }

  private func configureNavigatorPanel() {
    backButton.usesOpacityOnlyHover = true
    backButton.title = ""
    backButton.image = Self.backImage()
    backButton.imagePosition = .imageOnly
    backButton.imageScaling = .scaleProportionallyDown
    backButton.isBordered = false
    backButton.focusRingType = .none
    backButton.toolTip = "Select previous app"
    backButton.setAccessibilityLabel("Select previous app")
    backButton.target = self
    backButton.action = #selector(openPreviousApp(_:))
    addSubview(backButton)
    let trackingArea = NSTrackingArea(
      rect: .zero,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    backButton.addTrackingArea(trackingArea)
    backTrackingArea = trackingArea

    forwardButton.usesOpacityOnlyHover = true
    forwardButton.title = ""
    forwardButton.image = Self.forwardImage()
    forwardButton.imagePosition = .imageOnly
    forwardButton.imageScaling = .scaleProportionallyDown
    forwardButton.isBordered = false
    forwardButton.focusRingType = .none
    forwardButton.toolTip = "Select next app"
    forwardButton.setAccessibilityLabel("Select next app")
    forwardButton.target = self
    forwardButton.action = #selector(openNextApp(_:))
    addSubview(forwardButton)
    let forwardTrackingArea = NSTrackingArea(
      rect: .zero,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    forwardButton.addTrackingArea(forwardTrackingArea)
    self.forwardTrackingArea = forwardTrackingArea

    focusButton.isBordered = false
    focusButton.focusRingType = .none
    focusButton.alignment = .left
    focusButton.imagePosition = .imageLeading
    focusButton.imageScaling = .scaleProportionallyDown
    focusButton.font = Self.navigatorTextFont
    focusButton.wantsLayer = true
    focusButton.target = self
    focusButton.action = #selector(focusSelectedApp(_:))
    addSubview(focusButton)
  }

  private func configureMenuButton() {
    menuButton.title = ""
    menuButton.image = Self.menuImage()
    menuButton.imagePosition = .imageOnly
    menuButton.imageScaling = .scaleProportionallyDown
    menuButton.isBordered = false
    menuButton.focusRingType = .none
    menuButton.toolTip = "Menu"
    menuButton.setAccessibilityLabel("Menu")
    menuButton.target = self
    menuButton.action = #selector(showNavigatorMenu(_:))
    addSubview(menuButton)

    navigatorMenu.autoenablesItems = false
    newDesktopMenuItem.title = "New Desktop"
    newDesktopMenuItem.target = self
    newDesktopMenuItem.action = #selector(addDesktopPage(_:))
    navigatorMenu.addItem(newDesktopMenuItem)
    desktopPagesMenuItem.title = "Desktops"
    desktopPagesMenuItem.submenu = desktopPagesMenu
    navigatorMenu.addItem(desktopPagesMenuItem)
    navigatorMenu.addItem(.separator())
    expandLandscapePreviewsMenuItem.title = "Expand previews"
    expandLandscapePreviewsMenuItem.target = self
    expandLandscapePreviewsMenuItem.action = #selector(toggleLandscapePreviewExpansion(_:))
    navigatorMenu.addItem(expandLandscapePreviewsMenuItem)
    debugInformationMenuItem.title = "Show Debug Information"
    debugInformationMenuItem.target = self
    debugInformationMenuItem.action = #selector(toggleDebugInformation(_:))
    navigatorMenu.addItem(debugInformationMenuItem)
    navigatorMenu.addItem(.separator())
    commandTabShortcutMenuItem.title = "Use ⌘Tab for OpenPlane"
    commandTabShortcutMenuItem.target = self
    commandTabShortcutMenuItem.action = #selector(toggleCommandTabShortcut(_:))
    navigatorMenu.addItem(commandTabShortcutMenuItem)
  }

  private func configureSearch() {
    searchButton.title = ""
    searchButton.image = Self.searchImage()
    searchButton.imagePosition = .imageOnly
    searchButton.imageScaling = .scaleProportionallyDown
    searchButton.isBordered = false
    searchButton.focusRingType = .none
    searchButton.toolTip = "Search apps"
    searchButton.setAccessibilityLabel("Search apps")
    searchButton.target = self
    searchButton.action = #selector(showSearch(_:))
    addSubview(searchButton)

    closeSearchButton.title = ""
    closeSearchButton.image = Self.closeImage()
    closeSearchButton.imagePosition = .imageOnly
    closeSearchButton.imageScaling = .scaleProportionallyDown
    closeSearchButton.isBordered = false
    closeSearchButton.focusRingType = .none
    closeSearchButton.toolTip = "Close search"
    closeSearchButton.setAccessibilityLabel("Close search")
    closeSearchButton.target = self
    closeSearchButton.action = #selector(closeSearch(_:))
    closeSearchButton.isHidden = true
    addSubview(closeSearchButton)

    searchField.cell = VerticallyCenteredTextFieldCell(textCell: "")
    searchField.isBordered = false
    searchField.drawsBackground = false
    searchField.isEditable = true
    searchField.isSelectable = true
    searchField.appearance = NSAppearance(named: .darkAqua)
    searchField.textColor = .white
    searchField.font = Self.navigatorTextFont
    let placeholder = NSAttributedString(
      string: "Search apps",
      attributes: [
        .font: searchField.font as Any,
        .foregroundColor: NSColor.white.withAlphaComponent(0.38),
      ]
    )
    searchField.placeholderAttributedString = placeholder
    searchField.placeholderAttributedStrings = [placeholder]
    searchField.focusRingType = .none
    searchField.cell?.usesSingleLineMode = true
    searchField.cell?.isScrollable = true
    searchField.delegate = self
    searchField.target = self
    searchField.action = #selector(openSearchResult(_:))
    searchField.setAccessibilityLabel("Search apps")
    searchField.isHidden = true
    addSubview(searchField)

    nextSearchResultButton.title = ""
    nextSearchResultButton.image = Self.searchResultImage(previous: false)
    nextSearchResultButton.imagePosition = .imageOnly
    nextSearchResultButton.isBordered = false
    nextSearchResultButton.focusRingType = .none
    nextSearchResultButton.toolTip = "Next result"
    nextSearchResultButton.setAccessibilityLabel("Next search result")
    nextSearchResultButton.target = self
    nextSearchResultButton.action = #selector(selectNextSearchResult(_:))
    nextSearchResultButton.isHidden = true
    addSubview(nextSearchResultButton)

    previousSearchResultButton.title = ""
    previousSearchResultButton.image = Self.searchResultImage(previous: true)
    previousSearchResultButton.imagePosition = .imageOnly
    previousSearchResultButton.isBordered = false
    previousSearchResultButton.focusRingType = .none
    previousSearchResultButton.toolTip = "Previous result"
    previousSearchResultButton.setAccessibilityLabel("Previous search result")
    previousSearchResultButton.target = self
    previousSearchResultButton.action = #selector(selectPreviousSearchResult(_:))
    previousSearchResultButton.isHidden = true
    addSubview(previousSearchResultButton)
  }

  private func configureSettingsButton() {
    settingsButton.title = ""
    settingsButton.image = Self.colorSettingsImage()
    settingsButton.imagePosition = .imageOnly
    settingsButton.imageScaling = .scaleProportionallyDown
    settingsButton.isBordered = false
    settingsButton.focusRingType = .none
    settingsButton.toolTip = "Color palette"
    settingsButton.setAccessibilityLabel("Color palette")
    settingsButton.target = self
    settingsButton.action = #selector(showSettings(_:))
    addSubview(settingsButton)
  }

  private func configureLockViewButton() {
    lockViewButton.title = ""
    lockViewButton.imagePosition = .imageOnly
    lockViewButton.imageScaling = .scaleProportionallyDown
    lockViewButton.isBordered = false
    lockViewButton.focusRingType = .none
    lockViewButton.target = self
    lockViewButton.action = #selector(toggleLockedView(_:))
    addSubview(lockViewButton)
    updateLockViewButton()
  }

  private func configureFitAllButton() {
    fitAllButton.title = ""
    fitAllButton.image = Self.fitAllImage()
    fitAllButton.imagePosition = .imageOnly
    fitAllButton.imageScaling = .scaleProportionallyDown
    fitAllButton.isBordered = false
    fitAllButton.focusRingType = .none
    fitAllButton.toolTip = "Fit all windows"
    fitAllButton.setAccessibilityLabel("Fit all windows")
    fitAllButton.target = self
    fitAllButton.action = #selector(fitAllWindows(_:))
    addSubview(fitAllButton)
  }

  private func updateNavigatorPanel() {
    let selectedNode = nodes.first(where: { $0.id == selectedWindowID })
    let node =
      isHoveringBackButton ? backNavigationTarget
      : isHoveringForwardButton ? forwardNavigationTarget : selectedNode
    let title = node?.applicationName ?? "No app selected"
    focusButton.isEnabled = selectedNode != nil
    if !hasDisplayedNavigatorContent || displayedNavigatorNodeID != node?.id {
      if hasDisplayedNavigatorContent {
        let transition = CATransition()
        transition.type = .fade
        transition.duration = 0.2
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        focusButton.layer?.add(transition, forKey: "navigatorContentFade")
      }
      focusButton.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
          .font: Self.navigatorTextFont,
          .foregroundColor: NSColor.white.withAlphaComponent(node == nil ? 0.42 : 0.92),
        ]
      )
      if let icon = node?.icon?.copy() as? NSImage {
        icon.size = CGSize(width: 22, height: 22)
        focusButton.image = icon
      } else {
        focusButton.image = nil
      }
      displayedNavigatorNodeID = node?.id
      hasDisplayedNavigatorContent = true
    }
    focusButton.toolTip = selectedNode.map { "Open \($0.applicationName)" }
    focusButton.setAccessibilityLabel(selectedNode.map { "Open \($0.applicationName)" } ?? title)
    backButton.isEnabled = backNavigationTarget != nil
    backButton.isHidden = isSearching
    backButton.toolTip = backNavigationTarget.map { "Select \($0.applicationName)" }
    backButton.setAccessibilityLabel(backButton.toolTip ?? "Select previous app")
    forwardButton.isEnabled = forwardNavigationTarget != nil
    forwardButton.isHidden = isSearching
    forwardButton.toolTip = forwardNavigationTarget.map { "Select \($0.applicationName)" }
    forwardButton.setAccessibilityLabel(forwardButton.toolTip ?? "Select next app")
    expandLandscapePreviewsMenuItem.state = expandsLandscapePreviews ? .on : .off
    debugInformationMenuItem.state = showsDebugInformation ? .on : .off
    commandTabShortcutMenuItem.state = usesCommandTabShortcut ? .on : .off
    updateLockViewButton()
    needsLayout = true
  }

  func controlTextDidChange(_ notification: Notification) {
    guard let field = notification.object as? NSTextField else { return }
    if field === desktopTitleField {
      desktopPages.renameSelectedPage(field.stringValue)
      scheduleDesktopPagesPersistence()
      return
    }
    if field === searchField { updateSearchResults(centerSelection: true) }
  }

  func controlTextDidBeginEditing(_ notification: Notification) {
    guard let field = notification.object as? NSTextField,
      field === desktopTitleField,
      let editor = field.currentEditor() as? NSTextView
    else { return }
    editor.alignment = .center
    editor.textColor = .white
    editor.insertionPointColor = .white
  }

  func control(
    _ control: NSControl,
    textView: NSTextView,
    doCommandBy commandSelector: Selector
  ) -> Bool {
    guard control === searchField else { return false }
    if commandSelector == #selector(NSResponder.moveDown(_:)) {
      moveSearchSelection(by: 1)
      return true
    }
    if commandSelector == #selector(NSResponder.moveUp(_:)) {
      moveSearchSelection(by: -1)
      return true
    }
    return false
  }

  private func matchesSearch(_ node: WindowNode) -> Bool {
    CanvasSearch.matches(
      query: searchField.stringValue,
      applicationName: node.applicationName,
      title: node.title
    )
  }

  private var searchResults: [WindowNode] {
    let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    return query.isEmpty ? [] : nodes.filter(matchesSearch)
  }

  private func updateSearchResults(centerSelection: Bool) {
    guard isSearching else { return }
    let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      updateSearchNavigationButtons()
      needsDisplay = true
      return
    }

    let matches = searchResults
    let currentMatch = matches.first { $0.id == selectedWindowID }
    guard let result = currentMatch ?? matches.first else {
      selectedWindowID = nil
      updateSearchNavigationButtons()
      return
    }

    let changed = selectedWindowID != result.id
    selectedWindowID = result.id
    updateSearchNavigationButtons()
    if centerSelection, changed {
      animateCamera(
        to: CameraState(
          center: CGPoint(x: result.worldFrame.midX, y: result.worldFrame.midY),
          zoom: camera.zoom
        ),
        duration: Self.selectionTransitionDuration
      ) {}
    }
  }

  private func moveSearchSelection(by offset: Int) {
    let matches = searchResults
    guard let currentIndex = matches.firstIndex(where: { $0.id == selectedWindowID }) else {
      return
    }
    let nextIndex = currentIndex + offset
    guard matches.indices.contains(nextIndex) else { return }
    let result = matches[nextIndex]
    selectedWindowID = result.id
    updateSearchNavigationButtons()
    animateCamera(
      to: CameraState(
        center: CGPoint(x: result.worldFrame.midX, y: result.worldFrame.midY),
        zoom: camera.zoom
      ),
      duration: Self.selectionTransitionDuration
    ) {}
  }

  private func updateSearchNavigationButtons() {
    let matches = searchResults
    let selectedIndex = matches.firstIndex { $0.id == selectedWindowID }
    let showsNavigation = isSearching && matches.count >= 2
    nextSearchResultButton.isHidden = !showsNavigation
    previousSearchResultButton.isHidden = !showsNavigation
    nextSearchResultButton.isEnabled = selectedIndex.map { $0 < matches.count - 1 } ?? false
    previousSearchResultButton.isEnabled = selectedIndex.map { $0 > 0 } ?? false
    for button in [nextSearchResultButton, previousSearchResultButton] {
      button.contentTintColor = NSColor.white.withAlphaComponent(button.isEnabled ? 0.82 : 0.5)
    }
    needsDisplay = true
  }

  private func beginSearch(with text: String = "") {
    dismissSettings()
    isSearching = true
    searchField.stringValue = text
    setSearchControlsVisible(true)
    updateSearchResults(centerSelection: true)
    searchField.selectText(nil)
    if let editor = searchField.currentEditor() {
      editor.selectedRange = NSRange(location: searchField.stringValue.utf16.count, length: 0)
    }
    needsDisplay = true
  }

  private func endSearch() {
    isSearching = false
    searchField.stringValue = ""
    window?.makeFirstResponder(self)
    setSearchControlsVisible(false)
    needsDisplay = true
  }

  private func setSearchControlsVisible(_ visible: Bool) {
    if visible {
      isHoveringBackButton = false
      isHoveringForwardButton = false
    }
    closeSearchButton.isHidden = !visible
    searchField.isHidden = !visible
    backButton.isHidden = visible
    forwardButton.isHidden = visible
    focusButton.isHidden = visible
    searchButton.isHidden = visible
    fitAllButton.isHidden = visible
    settingsButton.isHidden = visible
    lockViewButton.isHidden = visible
    menuButton.isHidden = visible
    nextSearchResultButton.isHidden = true
    previousSearchResultButton.isHidden = true
    if visible { updateSearchNavigationButtons() }
  }

  @objc private func focusSelectedApp(_ sender: NSButton) {
    focusSelectedWindow()
  }

  @objc private func openPreviousApp(_ sender: NSButton) {
    delegate?.canvasViewDidRequestBack(self)
  }

  @objc private func openNextApp(_ sender: NSButton) {
    delegate?.canvasViewDidRequestForward(self)
  }

  @objc private func showSearch(_ sender: NSButton) {
    beginSearch()
  }

  @objc private func showNavigatorMenu(_ sender: NSButton) {
    expandLandscapePreviewsMenuItem.state = expandsLandscapePreviews ? .on : .off
    debugInformationMenuItem.state = showsDebugInformation ? .on : .off
    commandTabShortcutMenuItem.state = usesCommandTabShortcut ? .on : .off
    rebuildDesktopPagesMenu()
    navigatorMenu.popUp(
      positioning: nil,
      at: CGPoint(x: sender.bounds.minX, y: sender.bounds.minY),
      in: sender
    )
  }

  @objc private func toggleLandscapePreviewExpansion(_ sender: NSMenuItem) {
    expandsLandscapePreviews.toggle()
    UserDefaults.standard.set(
      expandsLandscapePreviews,
      forKey: Self.expandLandscapePreviewsPreferenceKey
    )
    sender.state = expandsLandscapePreviews ? .on : .off
    applyPreviewSizePreference(fitAll: false)
  }

  @objc private func toggleDebugInformation(_ sender: NSMenuItem) {
    showsDebugInformation.toggle()
    UserDefaults.standard.set(
      showsDebugInformation,
      forKey: Self.debugInformationPreferenceKey
    )
    sender.state = showsDebugInformation ? .on : .off
    needsDisplay = true
  }

  @objc private func toggleCommandTabShortcut(_ sender: NSMenuItem) {
    let enabled = !usesCommandTabShortcut
    guard delegate?.canvasView(self, setCommandTabShortcut: enabled) == true else {
      NSSound.beep()
      return
    }
    usesCommandTabShortcut = enabled
    UserDefaults.standard.set(enabled, forKey: OpenPlanePreferences.useCommandTabShortcut)
    sender.state = enabled ? .on : .off
  }

  @objc private func closeSearch(_ sender: NSButton) {
    endSearch()
  }

  @objc private func openSearchResult(_ sender: NSTextField) {
    focusSelectedWindow()
  }

  @objc private func selectNextSearchResult(_ sender: NSButton) {
    moveSearchSelection(by: 1)
  }

  @objc private func selectPreviousSearchResult(_ sender: NSButton) {
    moveSearchSelection(by: -1)
  }

  @objc private func fitAllWindows(_ sender: NSButton) {
    if let lockedCamera = desktopPages.selectedPage.lockedCamera {
      animateCamera(to: lockedCamera) {}
      return
    }
    guard !nodes.isEmpty else { return }
    let target = CanvasMath.fitCamera(frames: nodes.map(\.worldFrame), in: bounds)
    animateCamera(to: target) {}
  }

  @objc private func commitDesktopTitle(_ sender: NSTextField) {
    desktopPages.renameSelectedPage(sender.stringValue)
    persistDesktopPages()
    window?.makeFirstResponder(self)
  }

  @objc private func toggleLockedView(_ sender: NSButton) {
    desktopPages.toggleSelectedPageLock(at: camera)
    persistDesktopPages()
    updateLockViewButton()
  }

  @objc private func addDesktopPage(_ sender: NSMenuItem) {
    let target = CameraState(
      center: CGPoint(
        x: camera.center.x + max(640, bounds.width * 0.82) / camera.zoom,
        y: camera.center.y
      ),
      zoom: camera.zoom
    )
    _ = desktopPages.addPage(camera: target)
    desktopTitleField.stringValue = desktopPages.selectedPage.title
    persistDesktopPages()
    updateLockViewButton()
    animateCamera(to: target) {}
  }

  @objc private func selectDesktopPage(_ sender: NSMenuItem) {
    guard let rawID = sender.representedObject as? String,
      let id = UUID(uuidString: rawID),
      let target = desktopPages.select(id)
    else { return }
    desktopTitleField.stringValue = desktopPages.selectedPage.title
    persistDesktopPages()
    updateLockViewButton()
    animateCamera(to: target) {}
  }

  private func rebuildDesktopPagesMenu() {
    desktopPagesMenu.removeAllItems()
    for page in desktopPages.pages {
      let item = NSMenuItem(
        title: page.displayTitle,
        action: #selector(selectDesktopPage(_:)),
        keyEquivalent: ""
      )
      item.target = self
      item.representedObject = page.id.uuidString
      item.state = page.id == desktopPages.selectedID ? .on : .off
      desktopPagesMenu.addItem(item)
    }
  }

  private func updateLockViewButton() {
    let locked = desktopPages.isSelectedPageLocked
    lockViewButton.image = Self.lockViewImage(locked: locked)
    lockViewButton.toolTip = locked ? "Unlock desktop view" : "Lock current desktop view"
    lockViewButton.setAccessibilityLabel(lockViewButton.toolTip ?? "Lock desktop view")
    fitAllButton.toolTip = locked ? "Return to locked view" : "Fit all windows"
    fitAllButton.setAccessibilityLabel(fitAllButton.toolTip ?? "Fit all windows")
  }

  private func scheduleDesktopPagesPersistence() {
    NSObject.cancelPreviousPerformRequests(
      withTarget: self,
      selector: #selector(persistDesktopPages),
      object: nil
    )
    perform(#selector(persistDesktopPages), with: nil, afterDelay: 0.3)
  }

  @objc private func persistDesktopPages() {
    guard let data = try? JSONEncoder().encode(desktopPages) else { return }
    UserDefaults.standard.set(data, forKey: Self.desktopPagesPreferenceKey)
  }

  private static func loadDesktopPages(from defaults: UserDefaults) -> DesktopPages {
    guard let data = defaults.data(forKey: desktopPagesPreferenceKey),
      let decoded = try? JSONDecoder().decode(DesktopPages.self, from: data)
    else { return DesktopPages() }
    return DesktopPages(pages: decoded.pages, selectedID: decoded.selectedID)
  }

  private func focusSelectedWindow() {
    guard let selectedWindowID,
      let node = nodes.first(where: { $0.id == selectedWindowID })
    else { return }
    delegate?.canvasView(self, didRequestFocus: node)
  }

  @objc private func showSettings(_ sender: NSButton) {
    if dismissSettings() { return }

    let paletteView = CanvasPaletteView(selectedID: background.id)
    paletteView.onSelect = { [weak self, weak paletteView] selectedBackground in
      guard let self else { return }
      background = selectedBackground
      UserDefaults.standard.set(
        selectedBackground.id,
        forKey: Self.backgroundPreferenceKey
      )
      needsDisplay = true
      paletteView?.select(background: selectedBackground)
    }

    let controller = NSViewController()
    controller.view = paletteView
    settingsPopover.contentViewController = controller
    settingsPopover.contentSize = paletteView.frame.size
    settingsPopover.behavior = .transient
    settingsPopover.animates = true
    settingsPopover.appearance = NSAppearance(named: .aqua)
    settingsPopover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
  }

  private static func colorSettingsImage() -> NSImage? {
    let svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="30" height="30" viewBox="0 0 32 32">
        <circle cx="16" cy="10.5" r="8.25" fill="#79AEF0" fill-opacity=".78"/>
        <circle cx="11.25" cy="18.75" r="8.25" fill="#BD8ADD" fill-opacity=".78"/>
        <circle cx="20.75" cy="18.75" r="8.25" fill="#F08DA4" fill-opacity=".78"/>
      </svg>
      """
    guard let image = NSImage(data: Data(svg.utf8)) else { return nil }
    image.size = CGSize(width: 30, height: 30)
    image.isTemplate = false
    return image
  }

  private static func lockViewImage(locked: Bool) -> NSImage? {
    let shackle = locked
      ? "M5 11V7a7 7 0 0 1 14 0v4"
      : "M8 11V7a4 4 0 0 1 7.7-1.5"
    let svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24"
           fill="none" stroke="#FFFFFF" stroke-opacity=".82" stroke-width="2"
           stroke-linecap="round" stroke-linejoin="round">
        <path d="\(shackle)"/>
        <rect width="18" height="11" x="3" y="11" rx="2" ry="2"/>
      </svg>
      """
    guard let image = NSImage(data: Data(svg.utf8)) else { return nil }
    image.size = CGSize(width: 22, height: 22)
    image.isTemplate = false
    return image
  }

  private static func fitAllImage() -> NSImage? {
    let svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"
           fill="none" stroke="#FFFFFF" stroke-opacity=".82" stroke-width="2"
           stroke-linecap="round" stroke-linejoin="round">
        <path d="M3 7V5a2 2 0 0 1 2-2h2"/>
        <path d="M17 3h2a2 2 0 0 1 2 2v2"/>
        <path d="M21 17v2a2 2 0 0 1-2 2h-2"/>
        <path d="M7 21H5a2 2 0 0 1-2-2v-2"/>
      </svg>
      """
    guard let image = NSImage(data: Data(svg.utf8)) else { return nil }
    image.size = CGSize(width: 24, height: 24)
    image.isTemplate = false
    return image
  }

  private static func searchImage() -> NSImage? {
    let svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24"
           fill="none" stroke="#FFFFFF" stroke-opacity=".82" stroke-width="2"
           stroke-linecap="round" stroke-linejoin="round">
        <circle cx="11" cy="11" r="8"/>
        <path d="m21 21-4.3-4.3"/>
      </svg>
      """
    guard let image = NSImage(data: Data(svg.utf8)) else { return nil }
    image.size = CGSize(width: 22, height: 22)
    image.isTemplate = false
    return image
  }

  private static func searchResultImage(previous: Bool) -> NSImage? {
    let path = previous ? "m18 15-6-6-6 6" : "m6 9 6 6 6-6"
    let svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24"
           fill="none" stroke="#FFFFFF" stroke-width="2"
           stroke-linecap="round" stroke-linejoin="round">
        <path d="\(path)"/>
      </svg>
      """
    guard let image = NSImage(data: Data(svg.utf8)) else { return nil }
    image.size = CGSize(width: 20, height: 20)
    image.isTemplate = true
    return image
  }

  private static func closeImage() -> NSImage? {
    let svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24"
           fill="none" stroke="#FFFFFF" stroke-opacity=".82" stroke-width="2"
           stroke-linecap="round" stroke-linejoin="round">
        <path d="M18 6 6 18"/>
        <path d="m6 6 12 12"/>
      </svg>
      """
    guard let image = NSImage(data: Data(svg.utf8)) else { return nil }
    image.size = CGSize(width: 20, height: 20)
    image.isTemplate = false
    return image
  }

  private static func backImage() -> NSImage? {
    let svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24"
           fill="none" stroke="#FFFFFF" stroke-width="2"
           stroke-linecap="round" stroke-linejoin="round">
        <path d="m15 18-6-6 6-6"/>
      </svg>
      """
    guard let image = NSImage(data: Data(svg.utf8)) else { return nil }
    image.size = CGSize(width: 20, height: 20)
    image.isTemplate = false
    return image
  }

  private static func forwardImage() -> NSImage? {
    let svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24"
           fill="none" stroke="#FFFFFF" stroke-width="2"
           stroke-linecap="round" stroke-linejoin="round">
        <path d="m9 18 6-6-6-6"/>
      </svg>
      """
    guard let image = NSImage(data: Data(svg.utf8)) else { return nil }
    image.size = CGSize(width: 20, height: 20)
    image.isTemplate = false
    return image
  }

  private static func menuImage() -> NSImage? {
    let svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24"
           fill="none" stroke="#FFFFFF" stroke-opacity=".82" stroke-width="2"
           stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="5" r="1"/>
        <circle cx="12" cy="12" r="1"/>
        <circle cx="12" cy="19" r="1"/>
      </svg>
      """
    guard let image = NSImage(data: Data(svg.utf8)) else { return nil }
    image.size = CGSize(width: 22, height: 22)
    image.isTemplate = false
    return image
  }
}

@MainActor
private final class CanvasPaletteView: NSView {
  var onSelect: ((CanvasBackground) -> Void)?

  private let swatchSize: CGFloat = 40
  private let selectedBorderColor = NSColor.black.withAlphaComponent(0.78).cgColor
  private var swatches: [NSButton] = []
  private var selectedID: String

  init(selectedID: String) {
    self.selectedID = selectedID
    super.init(frame: CGRect(x: 0, y: 0, width: 332, height: 124))

    for (index, background) in CanvasPalette.backgrounds.enumerated() {
      let button = NSButton(frame: swatchFrame(at: index))
      button.identifier = NSUserInterfaceItemIdentifier(background.id)
      button.title = ""
      button.isBordered = false
      button.focusRingType = .none
      button.wantsLayer = true
      button.layer?.backgroundColor = background.color.cgColor
      button.layer?.cornerRadius = 10
      button.layer?.borderColor = NSColor.black.withAlphaComponent(0.14).cgColor
      button.layer?.borderWidth = 1
      button.toolTip = background.name
      button.setAccessibilityLabel(background.name)
      button.target = self
      button.action = #selector(selectSwatch(_:))
      addSubview(button)
      swatches.append(button)
    }

    updateSelection()
  }

  required init?(coder: NSCoder) { nil }

  func select(background: CanvasBackground) {
    selectedID = background.id
    updateSelection()
  }

  @objc private func selectSwatch(_ sender: NSButton) {
    let background = CanvasPalette.background(for: sender.identifier?.rawValue)
    onSelect?(background)
  }

  private func swatchFrame(at index: Int) -> CGRect {
    let column = index % 6
    let row = index / 6
    return CGRect(
      x: 20 + CGFloat(column) * 52,
      y: 66 - CGFloat(row) * 52,
      width: swatchSize,
      height: swatchSize
    )
  }

  private func updateSelection() {
    for button in swatches {
      let isSelected = button.identifier?.rawValue == selectedID
      button.layer?.borderColor = isSelected
        ? selectedBorderColor
        : NSColor.black.withAlphaComponent(0.14).cgColor
      button.layer?.borderWidth = isSelected ? 3 : 1
    }
  }
}
