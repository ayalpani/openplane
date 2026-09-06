@preconcurrency import AppKit
@preconcurrency import QuartzCore
@preconcurrency import ApplicationServices

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
    // AppKit already dims disabled controls; keeping the layer opaque avoids dimming twice.
    layer?.opacity = !isEnabled ? 1 : isHovering ? 1 : 0.78
  }
}

@MainActor
protocol CanvasViewDelegate: AnyObject {
  func canvasView(_ canvasView: CanvasView, didRequestFocus node: WindowNode)
  func canvasView(_ canvasView: CanvasView, didRequestQuit node: WindowNode)
  func canvasView(
    _ canvasView: CanvasView,
    didRequestLaunch bundleIdentifier: String,
    applicationName: String,
    at anchor: CGPoint
  )
  func canvasViewDidRequestBack(_ canvasView: CanvasView)
  func canvasViewDidRequestForward(_ canvasView: CanvasView)
  func canvasView(_ canvasView: CanvasView, setCommandTabShortcut enabled: Bool) -> Bool
  func canvasView(_ canvasView: CanvasView, setPrivateBrowserPreviews enabled: Bool)
}

private struct AppPlaceholder {
  let bundleIdentifier: String
  let applicationName: String
  var worldFrame: CGRect
  let icon: NSImage?
  let isAvailable: Bool
  let isLaunching: Bool
  let errorMessage: String?
}

// The scene and HUD do not intercept events; CanvasView owns the existing hit testing.
@MainActor
private final class CanvasDrawingView: NSView {
  var render: ((CGRect) -> Void)?
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override func draw(_ dirtyRect: NSRect) { render?(dirtyRect) }
}

private final class CanvasCardLayer: CALayer {
  let surface = CALayer()
  let preview = CALayer()
  let previousPreview = CALayer()
  let icon = CALayer()
  let header = CALayer()
  let activeHeader = CALayer()
  let regularTitle = CATextLayer()
  let boldTitle = CATextLayer()
  let regularActiveTitle = CATextLayer()
  let boldActiveTitle = CATextLayer()
  let status = CATextLayer()
  let border = CAShapeLayer()
  let indicator = CAShapeLayer()
  var previewImage: NSImage?
  var previousImage: NSImage?
  var iconImage: NSImage?
  var headerValue: NSAttributedString?
  var activeHeaderValue: NSAttributedString?
  var statusValue: NSAttributedString?
  var privateSize: CGSize?
  var borderGeometry: CGRect?
  var borderRadius: CGFloat = 0
  var borderStrokeWidth: CGFloat = 0

  override init() {
    super.init()
    anchorPoint = .zero
    surface.anchorPoint = .zero
    surface.masksToBounds = true
    surface.borderWidth = 2
    surface.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
    addSublayer(surface)
    surface.addSublayer(previousPreview)
    surface.addSublayer(preview)
    surface.addSublayer(status)
    addSublayer(border)
    addSublayer(indicator)
    addSublayer(icon)
    addSublayer(header)
    addSublayer(activeHeader)
    border.fillColor = nil
    border.shadowOffset = .zero
    border.shadowRadius = 16
    header.addSublayer(regularTitle)
    header.addSublayer(boldTitle)
    activeHeader.addSublayer(regularActiveTitle)
    activeHeader.addSublayer(boldActiveTitle)
    for title in [regularTitle, boldTitle, regularActiveTitle, boldActiveTitle] {
      title.truncationMode = .end
      title.actions = ["contents": NSNull()]
    }
    status.alignmentMode = .center
    status.truncationMode = .end
    // CATextLayer may prepare contents after the surrounding transaction commits.
    // Only the explicit preview/selection animations should crossfade content.
    for layer in [surface, preview, previousPreview, icon, header, activeHeader, status, border, indicator] {
      layer.actions = ["contents": NSNull()]
    }
  }

  override init(layer: Any) { super.init(layer: layer) }
  required init?(coder: NSCoder) { nil }
}

@MainActor
final class CanvasView: NSView, NSTextFieldDelegate, NSViewToolTipOwner {
  private let sceneView = CanvasDrawingView()
  private let hudView = CanvasDrawingView()
  let cameraLayer = CALayer()
  private let gridLayer = CAReplicatorLayer()
  private let gridRows = CAReplicatorLayer()
  private let gridTile = CALayer()
  private let centerGuideLayer = CAShapeLayer()
  private let miniMapViewport = CAShapeLayer()
  private let miniMapClip = CAShapeLayer()
  private let miniMapContent = CALayer()
  private let miniMapContainer = CALayer()
  private let miniMapContentClip = CAShapeLayer()
  private var miniMapCards: [String: CAShapeLayer] = [:]
  private var renderedMiniMapCamera: CameraState?
  private var cardLayers: [String: CanvasCardLayer] = [:]
  private var gridZoom: CGFloat?
  private var gridSize = CGSize.zero
  // Counts actual image preparation, not camera/selection layer property updates.
  private(set) var sceneContentUpdates = 0
  private(set) var sceneCardUpdates = 0

  private static let backgroundPreferenceKey = "canvasBackground"
  private static let navigatorPanelXPreferenceKey = "navigatorPanelX"
  private static let navigatorPanelYPreferenceKey = "navigatorPanelY"
  private static let expandLandscapePreviewsPreferenceKey = "expandLandscapePreviews"
  private static let debugInformationPreferenceKey = "showDebugInformation"
  private static let centerGuidePreferenceKey = "showCenterGuide"
  private static let lightClosedCardsPreferenceKey = "useLightClosedCards"
  private static let desktopPagesPreferenceKey = "desktopPages"
  private static let navigatorPanelSize = CGSize(width: 268, height: 244)
  private static let navigatorTextFont = NSFont.systemFont(ofSize: 12, weight: .medium)
  private static let desktopTitleFont = NSFont.systemFont(ofSize: 36, weight: .heavy)
  private static let desktopTabFont = NSFont.systemFont(ofSize: 20, weight: .semibold)
  static let desktopTransitionDuration: TimeInterval = selectionTransitionDuration
  private static let selectionHandleHitSize: CGFloat = 20
  private static let minimumGroupSize: CGFloat = 80
  private static let previewFadeDuration: TimeInterval = 0.25
  static let selectionTransitionDuration: TimeInterval = 0.18

  private(set) var isChronological = UserDefaults.standard.bool(forKey: "chronologicalMode")
  var onModeChange: (() -> Void)?
  var recentWindows = RecentWindowOrder()
  private var freeFrames: [CGWindowID: CGRect] = [:]
  private var chronologicalCamera = CameraState(center: .zero, zoom: 0.45)
  private let modeControl = NSSegmentedControl(labels: ["Canvas", "Chronological"], trackingMode: .selectOne, target: nil, action: nil)
  private static let allAppsID = "openplane:all-apps"
  private var catalog: [InstalledApp] = []
  private var catalogTask: Task<Void, Never>?
  private(set) var showingAllApps = false
  private var catalogReturnCamera: CameraState?
  private var catalogReturnSelection: CGWindowID?
  private let catalogBackButton = NSButton(title: "← Back to windows", target: nil, action: nil)
  private var displayedNodes: [WindowNode] { showingAllApps ? [] : nodes }

  weak var delegate: CanvasViewDelegate?
  var nodes: [WindowNode] = [] {
    didSet {
      let nodeIDs = Set(nodes.map(\.id))
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
      synchronizeManifestedPlacements()
      for oldNode in oldValue where groupSelectionIDs.contains(NavigationTarget.window(oldNode).key) {
        if !nodes.contains(where: { $0.bundleIdentifier == oldNode.bundleIdentifier }),
          desktopPages.selectedAppPlacement(for: oldNode.bundleIdentifier) != nil
        {
          groupSelectionIDs.insert("app:\(oldNode.bundleIdentifier)")
        }
      }
      if isChronological {
        for node in nodes where freeFrames[node.id] == nil { freeFrames[node.id] = node.worldFrame }
        freeFrames = freeFrames.filter { nodeIDs.contains($0.key) }
        arrangeRecentWindows(reorder: recentWindows.visible.isEmpty)
      } else { refreshPlaceholders() }
      if !showingAllApps, let bundleIdentifier = selectedPlaceholderBundleIdentifier,
        let node = nodes.first(where: { $0.bundleIdentifier == bundleIdentifier })
      {
        launchingPlaceholderBundles.remove(bundleIdentifier)
        placeholderErrors[bundleIdentifier] = nil
        selectedPlaceholderBundleIdentifier = nil
        selectedWindowID = node.id
      } else if let bundleIdentifier = selectedPlaceholderBundleIdentifier,
        !appPlaceholders.contains(where: { $0.bundleIdentifier == bundleIdentifier })
      {
        selectedPlaceholderBundleIdentifier = nil
      }
      updateNavigatorPanel()
      if isSearching { updateSearchResults(centerSelection: false) }
    }
  }
  var selectedWindowID: CGWindowID? {
    didSet {
      guard selectedWindowID != oldValue else { return }
      if selectedWindowID != nil { selectedPlaceholderBundleIdentifier = nil }
      animateSelection(from: oldValue, to: selectedWindowID)
      invalidateSelectionHUD()
      updateNavigatorPanel()
    }
  }
  private var cameraState = CameraState()
  var camera: CameraState {
    get {
      guard nativeCameraTravel, let animation = cameraAnimation else { return cameraState }
      return CanvasMath.interpolatedCamera(from: animation.start, to: animation.target,
        tracking: nil, progress: CanvasMath.easedTransition(
          min(1, (CACurrentMediaTime() - animation.startedAt) / animation.duration)), in: bounds)
    }
    set {
      let oldValue = camera
      stopNativeCameraTravel()
      cameraState = newValue
      guard newValue != oldValue else { return }
      rememberCamera(newValue)
      scheduleCameraMaintenance()
      if oldValue.zoom != newValue.zoom {
        synchronizeScene()
      } else {
        updateSceneCamera()
      }
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
    case groupResize(
      handle: SelectionResizeHandle,
      start: CGPoint,
      selectionRect: CGRect
    )
    case items(
      target: NavigationTarget?,
      start: CGPoint,
      frames: [String: CGRect],
      togglesSelection: Bool,
      dragged: Bool
    )
  }

  private struct MiniMapProjection {
    let frame: CGRect
    let contentBounds: CGRect
    let camera: CameraState
    let viewportWorldFrame: CGRect
  }

  @MainActor private enum NavigationTarget {
    case window(WindowNode)
    case placeholder(AppPlaceholder)

    var key: String {
      switch self {
      case .window(let node): "window:\(node.id)"
      case .placeholder(let placeholder): "app:\(placeholder.bundleIdentifier)"
      }
    }

    var worldFrame: CGRect {
      switch self {
      case .window(let node): node.worldFrame
      case .placeholder(let placeholder): placeholder.worldFrame
      }
    }

    var center: CGPoint {
      CGPoint(x: worldFrame.midX, y: worldFrame.midY)
    }
  }

  private var interaction: Interaction?
  private var appPlaceholders: [AppPlaceholder] = []
  private var appIconsByBundle: [String: NSImage] = [:]
  private var placeholderErrors: [String: String] = [:]
  private var launchingPlaceholderBundles: Set<String> = []
  private var selectedPlaceholderBundleIdentifier: String? {
    didSet {
      guard selectedPlaceholderBundleIdentifier != oldValue else { return }
      synchronizeScene(targetKeys: Set([oldValue, selectedPlaceholderBundleIdentifier]
        .compactMap { $0.map { "app:\($0)" } }))
      invalidateSelectionHUD()
      updateNavigatorPanel()
    }
  }
  private var hoveredPlaceholderBundleIdentifier: String? {
    didSet {
      if hoveredPlaceholderBundleIdentifier != oldValue { needsDisplay = true }
    }
  }
  private var backgroundWorkDeferredUntil: TimeInterval = 0
  private var displayedLockState: Bool?
  private(set) var groupSelectionIDs: Set<String> = []
  private var resizingGroupSelectionWorldRect: CGRect?
  var groupSelectionWorldRect: CGRect? {
    groupSelectionBounds().map { CanvasMath.worldRect(for: $0, camera: camera, bounds: bounds) }
  }
  private struct KeyboardZoomGesture {
    let inward: Bool
    let tapBaseZoom: CGFloat
    let viewAnchor: CGPoint
    let startedAt: TimeInterval
    var lastFrameAt: TimeInterval
    var controlsCamera: Bool
  }
  private struct KeyboardTapZoomAnimation {
    var targetZoom: CGFloat
    let viewAnchor: CGPoint
    var velocity: CGFloat
    var lastFrameAt: TimeInterval
  }
  private var keyboardZoomGesture: KeyboardZoomGesture?
  private var keyboardZoomDisplayLink: CADisplayLink?
  private var keyboardTapZoomAnimation: KeyboardTapZoomAnimation?
  private var keyboardTapZoomDisplayLink: CADisplayLink?
  private var animationDisplayLink: CADisplayLink?
  private var cameraAnimation: CameraAnimation?
  private(set) var nativeCameraTravel = false
  private var nativeCameraBounds = CGRect.zero
  private(set) var cameraFrameCallbacks = 0
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
  private var cameraMaintenancePending = false
  private var cameraChangedAt: TimeInterval = 0
  private(set) var cameraMaintenanceStarts = 0
  private(set) var cameraMaintenanceRuns = 0
  private var hoveredWindowID: CGWindowID?
  private var isHoveringGroupSelection = false
  private var hoveredSelectionResizeHandle: SelectionResizeHandle?
  private var windowHoverProgress: [CGWindowID: CGFloat] = [:]
  private var windowHoverStartProgress: [CGWindowID: CGFloat] = [:]
  private var windowHoverAnimationStartedAt: TimeInterval?
  private var windowHoverDisplayLink: CADisplayLink?
  private var selectionSamplingTime: TimeInterval?
  private var selectionTargetWindowID: CGWindowID?
  private func selectionProgress(for windowID: CGWindowID) -> CGFloat? {
    guard let startedAt = selectionAnimationStartedAt,
      let start = selectionStartProgress[windowID] else { return nil }
    let time = selectionSamplingTime ?? CACurrentMediaTime()
    let progress = time >= startedAt + Self.selectionTransitionDuration
      ? 1 : max(0, (time - startedAt) / Self.selectionTransitionDuration)
    let incoming = windowID == selectionTargetWindowID
    let phase = CanvasMath.easedTransition(progress)
    return start + ((incoming ? 1 : 0) - start) * phase
  }
  private var selectionStartProgress: [CGWindowID: CGFloat] = [:]
  private var selectionStaysWithinApplication = false
  private var selectionAnimationStartedAt: TimeInterval?

  private var previousPreviews: [CGWindowID: NSImage] = [:]
  private var previewFadeStartedAt: [CGWindowID: TimeInterval] = [:]
  private var previewFadeDisplayLink: CADisplayLink?
  private var launchSplashView: LaunchSplashView?
  private var launchSplashTask: Task<Void, Never>?
  private var displayedNavigatorContentID: String?
  private var hasDisplayedNavigatorContent = false
  private let focusButton = NSButton()
  private let backButton = HoverButton()
  private let forwardButton = HoverButton()
  private let menuButton = HoverButton()
  private let fitAllButton = HoverButton()
  private let searchButton = HoverButton()
  private let addDesktopButton = NSButton()
  private let lockViewButton = HoverButton()
  private let closeSearchButton = HoverButton()
  private let nextSearchResultButton = HoverButton()
  private let previousSearchResultButton = HoverButton()
  private let searchField = NSTextField()
  private let desktopTitleField = NSTextField()
  private let desktopTabsScrollView = NSScrollView()
  private let desktopTabsContent = NSView()
  private var desktopTabButtons: [NSButton] = []
  private var desktopTransitionStartedAt: TimeInterval?
  private var pendingDesktopChanges: [(direction: Int?, change: () -> Void)] = []
  private var desktopTransitionDisplayLink: CADisplayLink?
  private var settingsWorkspace: CanvasWorkspaceView? { superview as? CanvasWorkspaceView }
  private let expandLandscapePreviewsMenuItem = NSMenuItem()
  private let debugInformationMenuItem = NSMenuItem()
  private let gridMenuItem = NSMenuItem()
  private let centerGuideMenuItem = NSMenuItem()
  private let lightClosedCardsMenuItem = NSMenuItem()
  private let commandTabShortcutMenuItem = NSMenuItem()
  private let privateBrowserPreviewsMenuItem = NSMenuItem()
  private var isSearching = false
  private var expandsLandscapePreviews = true
  private var showsDebugInformation = UserDefaults.standard.bool(
    forKey: CanvasView.debugInformationPreferenceKey)
  // Retain the font: recreating it across draw/autorelease cycles can crash CoreText.
  private let debugInformationFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
  private var showsGrid = UserDefaults.standard.object(forKey: "showGrid") as? Bool ?? true
  private var showsCenterGuide = UserDefaults.standard.bool(
    forKey: CanvasView.centerGuidePreferenceKey)
  private var usesLightClosedCards = UserDefaults.standard.bool(
    forKey: CanvasView.lightClosedCardsPreferenceKey)
  private var usesCommandTabShortcut = UserDefaults.standard.bool(
    forKey: OpenPlanePreferences.useCommandTabShortcut)
  private var showsPrivateBrowserPreviews = UserDefaults.standard.bool(
    forKey: OpenPlanePreferences.showPrivateBrowserPreviews)
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
    defaults.removeObject(forKey: "synchronizeSelectionAnimation")
    desktopPages = Self.loadDesktopPages(from: defaults)
    cameraState = desktopPages.selectedPage.camera ?? cameraState
    if defaults.object(forKey: Self.navigatorPanelXPreferenceKey) != nil,
      defaults.object(forKey: Self.navigatorPanelYPreferenceKey) != nil
    {
      navigatorPanelOrigin = CGPoint(
        x: defaults.double(forKey: Self.navigatorPanelXPreferenceKey),
        y: defaults.double(forKey: Self.navigatorPanelYPreferenceKey)
      )
    }
    if let data = defaults.data(forKey: "chronologicalCamera"),
      let saved = try? JSONDecoder().decode(CameraState.self, from: data) { chronologicalCamera = saved }
    if isChronological { cameraState = chronologicalCamera }
    super.init(frame: frameRect)
    if defaults.object(forKey: Self.expandLandscapePreviewsPreferenceKey) != nil {
      expandsLandscapePreviews = defaults.bool(
        forKey: Self.expandLandscapePreviewsPreferenceKey)
    }
    wantsLayer = true
    configureScene()
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
    modeControl.target = self
    modeControl.action = #selector(changeMode(_:))
    modeControl.selectedSegment = isChronological ? 1 : 0
    modeControl.setAccessibilityLabel("View mode")
    catalogBackButton.target = self
    catalogBackButton.action = #selector(backFromCatalog(_:))
    catalogBackButton.isHidden = true
    addSubview(catalogBackButton)
    refreshPlaceholders()
    updateNavigatorPanel()
  }

  required init?(coder: NSCoder) { nil }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard frame.contains(point) else { return nil }
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
    if nativeCameraTravel, nativeCameraBounds != bounds {
      let destination = cameraAnimation?.target
      stopNativeCameraTravel()
      if isChronological, let destination { camera = destination }
    }
    catalogBackButton.frame = CGRect(x: bounds.midX - 100, y: bounds.maxY - 64, width: 200, height: 32)
    updateModeControls()
    sceneView.frame = bounds
    hudView.frame = bounds
    updateSceneCamera()
    schedulePreviewToolTipUpdate()
    let panel = navigatorPanelFrame
    var navigationX = panel.minX + 10
    backButton.frame = CGRect(
      x: navigationX,
      y: panel.maxY - 44,
      width: 28,
      height: 40
    )
    if !backButton.isHidden { navigationX += 28 }
    forwardButton.frame = CGRect(
      x: navigationX,
      y: panel.maxY - 44,
      width: 28,
      height: 40
    )
    if !forwardButton.isHidden { navigationX += 28 }
    menuButton.frame = CGRect(
      x: panel.maxX - 48,
      y: panel.maxY - 44,
      width: 40,
      height: 40
    )
    let hasNavigation = !backButton.isHidden || !forwardButton.isHidden
    let focusMinX = hasNavigation ? navigationX + 8 : panel.minX + 12
    focusButton.frame = CGRect(
      x: focusMinX,
      y: panel.maxY - 44,
      width: panel.maxX - 48 - focusMinX,
      height: 40
    )
    searchButton.frame = CGRect(
      x: panel.minX + 8,
      y: panel.minY + 4,
      width: 40,
      height: 40
    )
    fitAllButton.frame = CGRect(
      x: panel.maxX - 88,
      y: panel.minY + 4,
      width: 40,
      height: 40
    )
    lockViewButton.frame = CGRect(
      x: panel.maxX - 48,
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
      x: previousSearchResultButton.isHidden ? panel.minX + 10 : previousSearchResultButton.frame.maxX,
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
    layoutDesktopTabs()
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
      hoveredSelectionResizeHandle = nil
      hoveredPlaceholderBundleIdentifier = nil
      setHoveredWindow(nil)
      NSCursor.arrow.set()
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
    synchronizeScene()
    hudView.needsDisplay = true
  }

  private func drawHUD(_ dirtyRect: CGRect) {
    NSGraphicsContext.current?.cgContext.clear(dirtyRect)
    if nodes.isEmpty && appPlaceholders.isEmpty { drawEmptyState() }
    if let statusMessage { drawStatus(statusMessage) }
    drawGroupSelection()
    if showsDebugInformation { drawDebugInformation() }
    drawDesktopTitleNudge()
    drawNavigatorPanel()
  }

  private func invalidateSelectionHUD() {
    // Normal selection only changes retained map layers and the separate focus button.
    if !groupSelectionIDs.isEmpty || isSearching {
      hudView.needsDisplay = true
    }
  }

  private func configureScene() {
    for view in [sceneView, hudView] {
      view.frame = bounds
      view.autoresizingMask = [.width, .height]
      view.wantsLayer = true
      addSubview(view)
    }
    sceneView.layer?.masksToBounds = true
    cameraLayer.anchorPoint = .zero
    gridLayer.anchorPoint = .zero
    gridRows.anchorPoint = .zero
    gridTile.anchorPoint = .zero
    gridLayer.addSublayer(gridRows)
    gridRows.addSublayer(gridTile)
    sceneView.layer?.addSublayer(gridLayer)
    sceneView.layer?.addSublayer(centerGuideLayer)
    sceneView.layer?.addSublayer(cameraLayer)
    miniMapContent.anchorPoint = .zero
    miniMapContainer.addSublayer(miniMapContent)
    miniMapContainer.mask = miniMapContentClip
    hudView.layer?.addSublayer(miniMapContainer)
    hudView.layer?.addSublayer(miniMapViewport)
    miniMapViewport.fillColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
    miniMapViewport.strokeColor = NSColor.controlAccentColor.withAlphaComponent(0.9).cgColor
    miniMapViewport.lineWidth = 2
    miniMapViewport.mask = miniMapClip
    hudView.render = { [weak self] rect in self?.drawHUD(rect) }
  }

  private func updateSceneCamera() {
    guard sceneView.layer != nil, !nativeCameraTravel else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    if cameraAnimation == nil { cameraLayer.removeAnimation(forKey: "cameraTravel") }
    cameraLayer.setAffineTransform(CGAffineTransform(
      a: camera.zoom, b: 0, c: 0, d: camera.zoom,
      tx: bounds.midX - camera.center.x * camera.zoom,
      ty: bounds.midY - camera.center.y * camera.zoom
    ))
    updateGrid(camera: camera)
    if let projection = miniMapProjection() {
      miniMapContainer.isHidden = false
      miniMapViewport.isHidden = false
      miniMapContent.setAffineTransform(cameraTransform(projection.camera, in: projection.contentBounds))
      let rect = CanvasMath.viewRect(for: projection.viewportWorldFrame,
        camera: projection.camera, bounds: projection.contentBounds)
      miniMapViewport.path = CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil)
      miniMapClip.path = CGPath(roundedRect: projection.frame, cornerWidth: 8, cornerHeight: 8, transform: nil)
      miniMapContentClip.path = miniMapClip.path
      if renderedMiniMapCamera?.zoom != projection.camera.zoom { synchronizeMiniMap(projection) }
    } else {
      miniMapViewport.isHidden = true
      miniMapContainer.isHidden = true
    }
    CATransaction.commit()
    if !groupSelectionIDs.isEmpty { hudView.needsDisplay = true }
  }

  private func cameraTransform(_ camera: CameraState, in bounds: CGRect) -> CGAffineTransform {
    CGAffineTransform(a: camera.zoom, b: 0, c: 0, d: camera.zoom,
      tx: bounds.midX - camera.center.x * camera.zoom,
      ty: bounds.midY - camera.center.y * camera.zoom)
  }

  private func updateGrid(camera: CameraState, travel: CGPoint = .zero) {
    let opacity = showsGrid ? CanvasMath.gridOpacity(at: camera.zoom) : 0
    gridLayer.isHidden = opacity == 0
    guard opacity > 0 else {
      if gridZoom != camera.zoom {
        gridZoom = camera.zoom
        hudView.setNeedsDisplay(CGRect(x: 0, y: bounds.maxY - 60, width: 150, height: 60))
      }
      return
    }
    let spacing = CanvasMath.gridSpacing(at: camera.zoom)
    let dotsPerSide = max(1, min(32, Int(ceil(256 / spacing))))
    let tileSize = spacing * CGFloat(dotsPerSide)
    if gridZoom != camera.zoom || gridSize != bounds.size {
      gridZoom = camera.zoom
      gridSize = bounds.size
      gridTile.bounds = CGRect(x: 0, y: 0, width: tileSize, height: tileSize)
      gridTile.contents = sceneImage(size: gridTile.bounds.size) { _ in
        let path = CGMutablePath()
        let size = CanvasMath.gridDotSize(at: camera.zoom)
        for x in 0..<dotsPerSide {
          for y in 0..<dotsPerSide {
            path.addEllipse(in: CGRect(x: (CGFloat(x) + 0.5) * spacing - size / 2,
              y: (CGFloat(y) + 0.5) * spacing - size / 2, width: size, height: size))
          }
        }
        NSGraphicsContext.current?.cgContext.setFillColor(NSColor.white.withAlphaComponent(opacity).cgColor)
        NSGraphicsContext.current?.cgContext.addPath(path)
        NSGraphicsContext.current?.cgContext.fillPath()
      }
      hudView.setNeedsDisplay(CGRect(x: 0, y: bounds.maxY - 60, width: 150, height: 60))
    }
    // Repeat one rasterized tile, including the area exposed by this camera flight.
    gridLayer.instanceCount = Int(ceil((bounds.width + abs(travel.x)) / tileSize)) + 3
    gridRows.instanceCount = Int(ceil((bounds.height + abs(travel.y)) / tileSize)) + 3
    gridLayer.instanceTransform = CATransform3DMakeTranslation(tileSize, 0, 0)
    gridRows.instanceTransform = CATransform3DMakeTranslation(0, tileSize, 0)
    gridRows.position = CGPoint(x: -ceil(max(0, travel.x) / tileSize) * tileSize,
      y: -ceil(max(0, travel.y) / tileSize) * tileSize)
    let transform = cameraTransform(camera, in: bounds)
    gridLayer.position = CGPoint(
      x: (transform.tx - spacing / 2).truncatingRemainder(dividingBy: tileSize) - tileSize,
      y: (transform.ty - spacing / 2).truncatingRemainder(dividingBy: tileSize) - tileSize)
  }

  private func synchronizeMiniMap(_ projection: MiniMapProjection) {
    let targets = appPlaceholders.map(NavigationTarget.placeholder) + displayedNodes.map(NavigationTarget.window)
    let keys = Set(targets.map(\.key))
    for key in Array(miniMapCards.keys) where !keys.contains(key) {
      miniMapCards.removeValue(forKey: key)?.removeFromSuperlayer()
    }
    let selectedPID = nodes.first { $0.id == selectedWindowID }?.processID
    for target in targets {
      let card = miniMapCards[target.key] ?? CAShapeLayer()
      if card.superlayer == nil {
        card.anchorPoint = .zero
        miniMapContent.addSublayer(card)
        miniMapCards[target.key] = card
      }
      let zoom = projection.camera.zoom
      var rect = target.worldFrame
      if rect.width * zoom < 3 { rect = rect.insetBy(dx: -(3 / zoom - rect.width) / 2, dy: 0) }
      if rect.height * zoom < 3 { rect = rect.insetBy(dx: 0, dy: -(3 / zoom - rect.height) / 2) }
      if card.bounds.size != rect.size || renderedMiniMapCamera?.zoom != zoom {
        card.bounds = CGRect(origin: .zero, size: rect.size)
        card.path = CGPath(roundedRect: card.bounds, cornerWidth: 2 / zoom, cornerHeight: 2 / zoom, transform: nil)
      }
      card.position = rect.origin
      let grouped = groupSelectionIDs.contains(target.key)
      let color: NSColor
      switch target {
      case .placeholder(let placeholder):
        color = grouped ? groupSelectionColor
          : placeholder.bundleIdentifier == selectedPlaceholderBundleIdentifier ? selectionColor
          : NSColor.white.withAlphaComponent(0.22)
      case .window(let node):
        color = isSearching && !matchesSearch(target) ? NSColor.white.withAlphaComponent(0.1)
          : grouped ? groupSelectionColor.withAlphaComponent(node.id == selectedWindowID ? 1 : 0.7)
          : node.id == selectedWindowID ? selectionColor
          : selectedPID == node.processID ? selectionColor.withAlphaComponent(0.48)
          : NSColor.white.withAlphaComponent(0.38)
      }
      card.fillColor = color.cgColor
    }
    renderedMiniMapCamera = projection.camera
  }

  func synchronizeScene(windowIDs: Set<CGWindowID>? = nil, targetKeys: Set<String>? = nil) {
    guard sceneView.layer != nil else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    defer { CATransaction.commit() }
    let backdrop = CanvasMath.focusBackdropOpacity(progress: focusTransitionProgress)
    sceneView.layer?.backgroundColor = background.color.withAlphaComponent(
      CanvasMath.focusCanvasBackgroundOpacity(progress: focusTransitionProgress)).cgColor
    gridLayer.opacity = Float(backdrop)
    centerGuideLayer.isHidden = !showsCenterGuide && !isChronological
    centerGuideLayer.opacity = Float(backdrop)
    let guide = CGMutablePath()
    guide.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
    guide.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY))
    guide.move(to: CGPoint(x: bounds.minX, y: bounds.midY))
    guide.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
    centerGuideLayer.path = guide
    centerGuideLayer.strokeColor = NSColor.white.withAlphaComponent(0.5).cgColor
    centerGuideLayer.lineWidth = 1
    let targets = appPlaceholders.map(NavigationTarget.placeholder) + displayedNodes.map(NavigationTarget.window)
    let keys = Set(targets.map(\.key))
    for key in Array(cardLayers.keys) where !keys.contains(key) {
      cardLayers.removeValue(forKey: key)?.removeFromSuperlayer()
    }
    let selectedPID = nodes.first(where: { $0.id == selectedWindowID })?.processID
    for (index, target) in targets.enumerated() {
      if let targetKeys, !targetKeys.contains(target.key) { continue }
      if let windowIDs {
        guard case .window(let node) = target, windowIDs.contains(node.id) else { continue }
      }
      let card: CanvasCardLayer
      if let existing = cardLayers[target.key] { card = existing }
      else {
        card = CanvasCardLayer()
        card.name = target.key
        cardLayers[target.key] = card
        cameraLayer.addSublayer(card)
      }
      updateCard(card, target: target, selectedPID: selectedPID, backdrop: backdrop)
      card.zPosition = CGFloat(index) + (card.zPosition > 0 ? CGFloat(targets.count) : 0)
    }
    updateSceneCamera()
    if let projection = miniMapProjection() { synchronizeMiniMap(projection) }
  }

  private func updateCard(
    _ card: CanvasCardLayer, target: NavigationTarget, selectedPID: pid_t?, backdrop: CGFloat
  ) {
    sceneCardUpdates += 1
    let zoom = camera.zoom
    let scale = window?.backingScaleFactor ?? 2
    var rect = CGRect(origin: .zero, size: CGSize(
      width: target.worldFrame.width * zoom, height: target.worldFrame.height * zoom))
    var icon: NSImage?
    let title: String
    let selected: Bool
    let grouped = groupSelectionIDs.contains(target.key)
    let color = grouped ? groupSelectionColor : selectionColor
    var preview: NSImage?
    var previous: NSImage?
    var previewOpacity: Float = 1
    var statusText: String?
    var statusColor = NSColor.white.withAlphaComponent(0.62)
    var redacted = false
    card.opacity = Float(backdrop * searchOpacity(for: target))
    card.zPosition = 0
    card.surface.backgroundColor = NSColor(calibratedWhite: 0.11, alpha: 1).cgColor
    card.indicator.isHidden = true
    switch target {
    case .window(let node):
      selected = node.id == selectedWindowID
      icon = node.icon
      title = node.displayTitle
      let expansion = 3 * (windowHoverProgress[node.id] ?? 0)
      rect = rect.insetBy(dx: -expansion, dy: -expansion)
      if hoverTargetWindowIDs.contains(node.id) { card.zPosition = 1 }
      if node.id == focusTransitionWindowID { card.opacity = Float(searchOpacity(for: target)) }
      preview = node.preview
      previous = previousPreviews[node.id]
      if let startedAt = previewFadeStartedAt[node.id] {
        previewOpacity = Float(CanvasMath.easedTransition(min(1,
          (CACurrentMediaTime() - startedAt) / Self.previewFadeDuration)))
      }
      redacted = node.previewState == .redacted
      if node.previewState == .loading || node.previewState == .failed {
        card.indicator.isHidden = false
        card.indicator.path = CGPath(ellipseIn: previewStatusFrame(in: rect), transform: nil)
        card.indicator.fillColor = (node.previewState == .loading
          ? NSColor(srgbRed: 1, green: 0.62, blue: 0.15, alpha: 1)
          : NSColor(srgbRed: 1, green: 0.27, blue: 0.23, alpha: 1)).cgColor
        card.indicator.strokeColor = NSColor.white.cgColor
        card.indicator.lineWidth = 2
      }
    case .placeholder(let placeholder):
      selected = selectedPlaceholderBundleIdentifier == placeholder.bundleIdentifier
      icon = placeholder.icon
      title = placeholder.applicationName
      let hovered = hoveredPlaceholderBundleIdentifier == placeholder.bundleIdentifier
        || (isHoveringGroupSelection && grouped)
      card.surface.backgroundColor = (usesLightClosedCards ? NSColor.white : NSColor.black)
        .withAlphaComponent(hovered ? 0.14 : 0.1).cgColor
      statusText = placeholder.errorMessage
        ?? (placeholder.isLaunching ? "Opening…" : placeholder.bundleIdentifier == Self.allAppsID
          ? "Browse installed apps" : showingAllApps ? placeholder.applicationName
          : placeholder.isAvailable ? "Closed" : "App unavailable")
      if placeholder.errorMessage != nil || !placeholder.isAvailable {
        statusColor = NSColor.systemRed.withAlphaComponent(0.86)
      }
    }
    if redacted { preview = nil; previous = nil }
    card.position = target.worldFrame.origin
    card.setAffineTransform(CGAffineTransform(scaleX: 1 / zoom, y: 1 / zoom))
    card.surface.frame = rect
    let radius = max(5, min(14, 12 * zoom))
    card.surface.cornerRadius = radius
    for layer in [card.preview, card.previousPreview] { layer.frame = CGRect(origin: .zero, size: rect.size) }
    if card.previewImage !== preview {
      card.previewImage = preview
      card.preview.contents = preview?.cgImage(forProposedRect: nil, context: nil, hints: nil)
      sceneContentUpdates += 1
    }
    if card.previousImage !== previous {
      card.previousImage = previous
      card.previousPreview.contents = previous?.cgImage(forProposedRect: nil, context: nil, hints: nil)
      sceneContentUpdates += 1
    }
    card.preview.opacity = previewOpacity
    card.status.isHidden = statusText == nil
    if let statusText {
      let fontSize = CanvasMath.placeholderStatusFontSize(at: zoom)
      let value = NSAttributedString(string: statusText, attributes: [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold), .foregroundColor: statusColor])
      if card.statusValue != value { card.status.string = value; card.statusValue = value; sceneContentUpdates += 1 }
      card.status.contentsScale = scale
      card.status.frame = CGRect(x: 8, y: rect.height / 2 - fontSize * 0.7,
        width: max(0, rect.width - 16), height: fontSize * 1.4)
    }
    if redacted {
      if card.privateSize != rect.size {
        card.preview.contents = sceneImage(size: rect.size) { self.drawPrivatePreview(in: $0) }
        card.privateSize = rect.size
      }
    } else if card.privateSize != nil {
      card.privateSize = nil
      card.preview.contents = preview?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    let (_, titleLift) = previewTitlePresentation(for: target)
    let layout = CanvasMath.previewHeaderLayout(for: rect, zoom: zoom, titleLift: titleLift)
    card.icon.frame = layout.icon.insetBy(dx: -21 * layout.icon.width / 36, dy: -21 * layout.icon.width / 36)
    if card.iconImage !== icon || (icon != nil && card.icon.contents == nil) {
      card.iconImage = icon
      // A fixed-resolution badge includes the original crop, rounded corners and shadow.
      card.icon.contents = sceneImage(size: CGSize(width: 78, height: 78)) { _ in
        self.drawAppIcon(icon, in: CGRect(x: 21, y: 21, width: 36, height: 36))
      }
    }
    let font = NSFont.systemFont(ofSize: 12, weight: .medium)
    let value = NSAttributedString(string: title, attributes: [
      .font: font, .foregroundColor: NSColor.white.withAlphaComponent(0.76)])
    if card.headerValue != value {
      card.regularTitle.string = value
      card.boldTitle.string = NSAttributedString(string: title, attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: NSColor.white.withAlphaComponent(0.76)])
      card.headerValue = value; sceneContentUpdates += 1
    }
    let active = NSAttributedString(string: title, attributes: [.font: font, .foregroundColor: color])
    if card.activeHeaderValue != active {
      card.regularActiveTitle.string = active
      card.boldActiveTitle.string = NSAttributedString(string: title, attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: color])
      card.activeHeaderValue = active; sceneContentUpdates += 1
    }
    for title in [card.regularTitle, card.boldTitle, card.regularActiveTitle, card.boldActiveTitle] {
      title.contentsScale = scale
    }
    card.regularTitle.isHidden = selected
    card.regularActiveTitle.isHidden = selected
    card.boldTitle.isHidden = !selected
    card.boldActiveTitle.isHidden = !selected
    updateSelectionAppearance(card, target: target, selectedPID: selectedPID)
  }

  private func updateSelectionAppearance(
    _ card: CanvasCardLayer, target: NavigationTarget, selectedPID: pid_t?,
    recording: (([Any]) -> Void)? = nil
  ) {
    let previousSamplingTime = selectionSamplingTime
    if previousSamplingTime == nil, let startedAt = selectionAnimationStartedAt {
      selectionSamplingTime = startedAt + Self.selectionTransitionDuration
    }
    defer { selectionSamplingTime = previousSamplingTime }
    let rect = card.surface.frame
    let radius = card.surface.cornerRadius
    let grouped = groupSelectionIDs.contains(target.key)
    let color = grouped ? groupSelectionColor : selectionColor
    let selected: Bool
    var borderProgress: CGFloat = 0
    var borderWidth: CGFloat = 4
    var secondary = false
    switch target {
    case .window(let node):
      selected = node.id == selectedWindowID
      let sameApp = selectedPID == node.processID
      let phases = CanvasMath.selectionAnimationPhases(
        progress: selectionProgress(for: node.id) ?? (selected ? 1 : 0))
      if selectionStaysWithinApplication && sameApp {
        borderProgress = selectionProgress(for: node.id) ?? (selected ? 1 : 0)
        borderWidth = CanvasMath.sameApplicationSelectionMetrics(primaryProgress: borderProgress).borderWidth
        secondary = borderProgress == 0
      } else {
        borderProgress = phases.border
        if !selected && (grouped || sameApp) && borderProgress == 0 {
          let appPhase = CanvasMath.selectionAnimationPhases(
            progress: selectedWindowID.flatMap { selectionProgress(for: $0) } ?? 1).border
          secondary = grouped || appPhase > 0
        }
      }
    case .placeholder(let placeholder):
      selected = selectedPlaceholderBundleIdentifier == placeholder.bundleIdentifier
      borderProgress = selected ? 1 : 0
      secondary = grouped && !selected
    }
    let inset: CGFloat = secondary ? 4 : 2 + borderWidth / 2
    let borderRect = rect.insetBy(dx: -inset, dy: -inset)
    let (titleProgress, titleLift) = previewTitlePresentation(for: target)
    let layout = CanvasMath.previewHeaderLayout(for: rect, zoom: camera.zoom, titleLift: titleLift)
    if let recording {
      let path: CGPath
      let shadowPath: CGPath
      if card.borderGeometry == borderRect, card.borderRadius == radius + inset,
        card.borderStrokeWidth == borderWidth,
        let existingPath = card.border.path, let existingShadow = card.border.shadowPath {
        path = existingPath
        shadowPath = existingShadow
      } else {
        path = CGPath(roundedRect: borderRect, cornerWidth: radius + inset,
          cornerHeight: radius + inset, transform: nil)
        shadowPath = path.copy(strokingWithWidth: borderWidth,
          lineCap: .round, lineJoin: .round, miterLimit: 0)
      }
      let titlePosition = NSValue(point: CGPoint(x: layout.title.midX, y: layout.title.midY))
      recording([
        NSNumber(value: Float(secondary ? 1 : borderProgress)),
        NSNumber(value: Double(secondary ? 2 : borderWidth)), path, shadowPath,
        NSNumber(value: secondary ? 0 : 0.9),
        NSNumber(value: Float(layout.titleVisibility * (1 - titleProgress))), titlePosition,
        NSNumber(value: Float(layout.titleVisibility * titleProgress)), titlePosition,
      ])
      return
    }
    if card.borderGeometry != borderRect || card.borderRadius != radius + inset
      || card.borderStrokeWidth != borderWidth {
      card.borderGeometry = borderRect
      card.borderRadius = radius + inset
      card.borderStrokeWidth = borderWidth
      card.border.path = CGPath(roundedRect: borderRect, cornerWidth: radius + inset,
        cornerHeight: radius + inset, transform: nil)
      card.border.shadowPath = card.border.path?.copy(strokingWithWidth: borderWidth,
        lineCap: .round, lineJoin: .round, miterLimit: 0)
    }
    card.border.strokeColor = color.cgColor
    card.border.lineWidth = secondary ? 2 : borderWidth
    card.border.opacity = Float(secondary ? 1 : borderProgress)
    card.border.shadowColor = color.cgColor
    card.border.shadowOpacity = secondary ? 0 : 0.9
    card.header.frame = layout.title
    card.activeHeader.frame = layout.title
    for title in [card.regularTitle, card.boldTitle, card.regularActiveTitle, card.boldActiveTitle] {
      title.frame = card.header.bounds
    }
    card.header.opacity = Float(layout.titleVisibility * (1 - titleProgress))
    card.activeHeader.opacity = Float(layout.titleVisibility * titleProgress)
  }

  private func sceneImage(size: CGSize, draw: (CGRect) -> Void) -> CGImage? {
    let scale = window?.backingScaleFactor ?? 2
    guard size.width > 0, size.height > 0,
      let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
        pixelsWide: Int(ceil(size.width * scale)), pixelsHigh: Int(ceil(size.height * scale)),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    bitmap.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: scale, y: scale)
    draw(CGRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    sceneContentUpdates += 1
    return bitmap.cgImage
  }

  func visibleWindowIDs() -> [CGWindowID] {
    displayedNodes.compactMap { node in
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
    isChronological ? chronologicalCamera : desktopPages.selectedPage.camera ?? fallback
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
    if isChronological { arrangeRecentWindows(reorder: false) }
    needsDisplay = true
    schedulePreviewToolTipUpdate()
    synchronizeManifestedPlacements()
    if fitAll, !canvasItemFrames.isEmpty {
      animateCamera(to: CanvasMath.fitCamera(frames: canvasItemFrames, in: bounds)) {}
    }
  }

  func setNeedsDisplay(for windowIDs: [CGWindowID]) {
    synchronizeScene(windowIDs: Set(windowIDs))
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

  func clearPreview(for node: WindowNode) {
    node.preview = nil
    previousPreviews[node.id] = nil
    previewFadeStartedAt[node.id] = nil
    if previewFadeStartedAt.isEmpty {
      previewFadeDisplayLink?.invalidate()
      previewFadeDisplayLink = nil
    }
    setNeedsDisplay(for: [node.id])
    schedulePreviewToolTipUpdate()
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
      || desktopTransitionStartedAt != nil
      || cameraAnimation != nil
      || keyboardZoomGesture != nil
      || keyboardTapZoomAnimation != nil
      || CACurrentMediaTime() < backgroundWorkDeferredUntil
  }

  func refreshMetadata(for windowIDs: [CGWindowID]) {
    setNeedsDisplay(for: windowIDs)
    updateNavigatorPanel()
    if isSearching { updateSearchResults(centerSelection: false) }
    synchronizeManifestedPlacements()
  }

  func persistState() {
    stopNativeCameraTravel()
    NSObject.cancelPreviousPerformRequests(
      withTarget: self, selector: #selector(performCameraMaintenance), object: nil)
    cameraMaintenancePending = false
    synchronizeManifestedPlacements()
    persistDesktopPages()
  }

  func handleNavigationKey(_ event: NSEvent) -> Bool {
    guard desktopTitleField.currentEditor() == nil else { return false }
    let modifiers = event.modifierFlags.intersection([.shift, .command, .control, .option])
    if modifiers == [.command], event.keyCode == 13, isChronological, !isSearching {
      closeSelectedWindow(nil)
      return true
    }
    guard modifiers.isEmpty || modifiers == [.shift] else { return false }

    if isSearching { return false }

    if event.characters == "+", !isChronological {
      if !event.isARepeat { addDesktopPage(nil) }
      return true
    }

    if event.keyCode == 48 {
      if isChronological { stepRecent(by: modifiers == [.shift] ? -1 : 1, wrapping: false); return true }
      guard !event.isARepeat, desktopPages.pages.count > 1 else { return true }
      let offset = modifiers == [.shift] ? -1 : 1
      transitionDesktop(direction: offset) { [weak self] in
        guard let self,
          let index = self.desktopPages.pages.firstIndex(where: { $0.id == self.desktopPages.selectedID })
        else { return }
        let nextIndex = (index + offset + self.desktopPages.pages.count) % self.desktopPages.pages.count
        let target = self.desktopPages.select(self.desktopPages.pages[nextIndex].id) ?? self.camera
        self.applySelectedDesktop(camera: target)
      }
      return true
    }

    if desktopTransitionStartedAt != nil { return true }

    if modifiers == [.shift] {
      switch event.keyCode {
      case 36, 76:
        if !event.isARepeat, let target = selectedNavigationTarget {
          toggleGroupSelection(target)
        }
      case 125:
        beginKeyboardZoom(inward: true)
      case 126:
        beginKeyboardZoom(inward: false)
      default:
        return false
      }
      return true
    }

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
    case 51:
      if ShortcutMatcher.isPlaneQuit(keyCode: event.keyCode, isRepeat: event.isARepeat) {
        quitSelectedApplication()
      }
    default:
      guard let text = event.characters,
        text.rangeOfCharacter(from: .alphanumerics) != nil
      else { return false }
      beginSearch(with: text)
    }
    return true
  }

  func handleNavigationKeyUp(_ event: NSEvent) -> Bool {
    guard keyboardZoomGesture != nil, event.keyCode == 125 || event.keyCode == 126 else {
      return false
    }
    stopKeyboardZoom(completingTap: true)
    return true
  }

  private func beginKeyboardZoom(inward: Bool) {
    if keyboardZoomGesture?.inward == inward { return }
    stopKeyboardZoom(completingTap: false)
    deferBackgroundWork()
    let viewAnchor = CGPoint(x: bounds.midX, y: bounds.midY)
    let now = CACurrentMediaTime()
    keyboardZoomGesture = KeyboardZoomGesture(
      inward: inward,
      tapBaseZoom: keyboardTapZoomAnimation?.targetZoom
        ?? cameraAnimation?.target.zoom
        ?? camera.zoom,
      viewAnchor: viewAnchor,
      startedAt: now,
      lastFrameAt: now,
      controlsCamera: cameraAnimation == nil && keyboardTapZoomAnimation == nil
    )
    let displayLink = displayLink(target: self, selector: #selector(stepKeyboardZoom(_:)))
    keyboardZoomDisplayLink = displayLink
    displayLink.add(to: .main, forMode: .common)
  }

  private func stopKeyboardZoom(completingTap: Bool) {
    guard let gesture = keyboardZoomGesture else { return }
    let elapsed = CACurrentMediaTime() - gesture.startedAt
    keyboardZoomGesture = nil
    keyboardZoomDisplayLink?.invalidate()
    keyboardZoomDisplayLink = nil
    scheduleDesktopPagesPersistence()

    guard completingTap, elapsed < 0.22 else { return }
    let baseZoom = keyboardTapZoomAnimation?.targetZoom ?? gesture.tapBaseZoom
    let targetZoom = CanvasMath.steppedZoom(baseZoom, inward: gesture.inward)
    guard targetZoom != baseZoom else { return }
    if var animation = keyboardTapZoomAnimation {
      animation.targetZoom = targetZoom
      keyboardTapZoomAnimation = animation
      return
    }
    let now = CACurrentMediaTime()
    keyboardTapZoomAnimation = KeyboardTapZoomAnimation(
      targetZoom: targetZoom,
      viewAnchor: gesture.viewAnchor,
      velocity: (gesture.inward ? 1 : -1) * CanvasMath.heldZoomSpeed(after: elapsed),
      lastFrameAt: now
    )
    let displayLink = displayLink(target: self, selector: #selector(stepKeyboardTapZoom(_:)))
    keyboardTapZoomDisplayLink = displayLink
    displayLink.add(to: .main, forMode: .common)
  }

  @objc private func stepKeyboardZoom(_ displayLink: CADisplayLink) {
    guard var gesture = keyboardZoomGesture else {
      displayLink.invalidate()
      return
    }
    let now = CACurrentMediaTime()
    let elapsed = now - gesture.startedAt
    let deltaTime = min(1.0 / 15.0, max(0, now - gesture.lastFrameAt))
    gesture.lastFrameAt = now

    if !gesture.controlsCamera {
      guard elapsed >= 0.22 else {
        keyboardZoomGesture = gesture
        return
      }
      stopKeyboardTapZoom()
      stopNativeCameraTravel()
      animationDisplayLink?.invalidate()
      animationDisplayLink = nil
      cameraAnimation = nil
      isPresentingFinalAnimationFrame = false
      gesture.controlsCamera = true
      gesture.lastFrameAt = now
      keyboardZoomGesture = gesture
      return
    }
    keyboardZoomGesture = gesture

    let zoom = CanvasMath.heldZoom(
      camera.zoom,
      inward: gesture.inward,
      elapsed: elapsed,
      deltaTime: deltaTime
    )
    camera = CanvasMath.zoomedCamera(
      camera,
      to: zoom,
      around: gesture.viewAnchor,
      in: bounds
    )
    if zoom == CanvasMath.minimumZoom || zoom == CanvasMath.maximumZoom {
      stopKeyboardZoom(completingTap: false)
    }
  }

  @objc private func stepKeyboardTapZoom(_ displayLink: CADisplayLink) {
    guard var animation = keyboardTapZoomAnimation else {
      displayLink.invalidate()
      return
    }
    let now = CACurrentMediaTime()
    guard cameraAnimation == nil else {
      animation.lastFrameAt = now
      keyboardTapZoomAnimation = animation
      return
    }
    let deltaTime = min(1.0 / 15.0, max(0, now - animation.lastFrameAt))
    animation.lastFrameAt = now
    let frame = CanvasMath.animatedKeyboardZoom(
      from: camera.zoom,
      to: animation.targetZoom,
      velocity: animation.velocity,
      deltaTime: deltaTime
    )
    animation.velocity = frame.velocity
    camera = CanvasMath.zoomedCamera(
      camera,
      to: frame.zoom,
      around: animation.viewAnchor,
      in: bounds
    )
    guard frame.zoom == animation.targetZoom, frame.velocity == 0 else {
      keyboardTapZoomAnimation = animation
      return
    }
    keyboardTapZoomAnimation = nil
    keyboardTapZoomDisplayLink = nil
    displayLink.invalidate()
  }

  private func stopKeyboardTapZoom() {
    keyboardTapZoomAnimation = nil
    keyboardTapZoomDisplayLink?.invalidate()
    keyboardTapZoomDisplayLink = nil
  }

  @discardableResult
  func dismissSettings() -> Bool {
    guard let host = settingsWorkspace, host.isSettingsVisible else { return false }
    host.hideSettings()
    return true
  }

  @discardableResult
  func dismissSearch() -> Bool {
    guard isSearching else { return false }
    endSearch()
    if showingAllApps { refreshRecentPlaceholders() }
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
    finishDesktopTransition()
    stopKeyboardTapZoom()
    if cameraAnimation != nil, let presentation = cameraLayer.presentation() {
      let transform = presentation.affineTransform()
      if transform.a > 0 {
        // A translation never changes zoom. Decomposing its presentation matrix can
        // round the scale and accidentally turn the next flight into a CPU zoom.
        let zoom = nativeCameraTravel ? camera.zoom : transform.a
        camera = CameraState(center: CGPoint(
          x: (bounds.midX - transform.tx) / zoom,
          y: (bounds.midY - transform.ty) / zoom), zoom: zoom)
      }
    }
    stopNativeCameraTravel()
    cameraLayer.removeAnimation(forKey: "cameraTravel")
    setHoveredWindow(nil)
    animationDisplayLink?.invalidate()
    animationDisplayLink = nil
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
    if target.zoom == camera.zoom, focusWindowID == nil, worldPoint == nil,
      progressHandler == nil, cameraCompletionFraction == 1, groupSelectionIDs.isEmpty,
      duration > 0, let animation = cameraAnimation {
      beginNativeCameraTravel(animation)
      return
    }
    let displayLink = displayLink(
      target: self, selector: #selector(stepCameraAnimation(_:)))
    animationDisplayLink = displayLink
    displayLink.add(to: .main, forMode: .common)
  }

  @objc private func stepCameraAnimation(_ displayLink: CADisplayLink) {
    cameraFrameCallbacks += 1
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

  private func beginNativeCameraTravel(_ animation: CameraAnimation) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    defer { CATransaction.commit() }
    nativeCameraTravel = true
    nativeCameraBounds = bounds
    cameraState = animation.target
    rememberCamera(animation.target)
    scheduleCameraMaintenance()
    let startTransform = cameraTransform(animation.start, in: bounds)
    let endTransform = cameraTransform(animation.target, in: bounds)
    let delta = CGPoint(x: endTransform.tx - startTransform.tx, y: endTransform.ty - startTransform.ty)
    updateGrid(camera: animation.start, travel: delta)
    let gridStart = gridLayer.position
    var transforms: [Any] = []
    var gridPositions: [Any] = []
    var mapTransforms: [Any] = []
    var viewportPaths: [Any] = []
    let itemBounds = canvasItemFrames.reduce(CGRect.null) { $0.union($1) }
    for index in 0...60 {
      let progress = CanvasMath.easedTransition(CGFloat(index) / 60)
      let state = CanvasMath.interpolatedCamera(from: animation.start, to: animation.target,
        tracking: nil, progress: progress, in: bounds)
      transforms.append(NSValue(caTransform3D: CATransform3DMakeAffineTransform(cameraTransform(state, in: bounds))))
      gridPositions.append(NSValue(point: CGPoint(x: gridStart.x + delta.x * progress,
        y: gridStart.y + delta.y * progress)))
      if let projection = miniMapProjection(camera: state, itemBounds: itemBounds) {
        mapTransforms.append(NSValue(caTransform3D: CATransform3DMakeAffineTransform(
          cameraTransform(projection.camera, in: projection.contentBounds))))
        let rect = CanvasMath.viewRect(for: projection.viewportWorldFrame,
          camera: projection.camera, bounds: projection.contentBounds)
        viewportPaths.append(CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil))
      }
    }
    if let projection = miniMapProjection(camera: animation.target) { synchronizeMiniMap(projection) }
    for (layer, key, values) in [
      (cameraLayer, "transform", transforms), (gridLayer, "position", gridPositions),
      (miniMapContent, "transform", mapTransforms), (miniMapViewport, "path", viewportPaths),
    ] {
      guard let last = values.last else { continue }
      layer.setValue(last, forKeyPath: key)
      let travel = CAKeyframeAnimation(keyPath: key)
      travel.values = values
      travel.duration = animation.duration
      travel.beginTime = layer.convertTime(animation.startedAt, from: nil)
      layer.add(travel, forKey: "cameraTravel")
    }
    perform(#selector(finishNativeCameraTravel), with: nil, afterDelay: animation.duration)
  }

  private func stopNativeCameraTravel() {
    guard nativeCameraTravel else { return }
    cameraState = camera
    nativeCameraTravel = false
    cameraAnimation = nil
    NSObject.cancelPreviousPerformRequests(withTarget: self,
      selector: #selector(finishNativeCameraTravel), object: nil)
    for layer in [cameraLayer, gridLayer, miniMapContent, miniMapViewport] {
      layer.removeAnimation(forKey: "cameraTravel")
    }
    rememberCamera(cameraState)
    updateSceneCamera()
  }

  @objc private func finishNativeCameraTravel() {
    guard nativeCameraTravel, let animation = cameraAnimation else { return }
    stopNativeCameraTravel()
    camera = animation.target
    animation.completion()
  }

  func endFocusTransition() {
    guard focusTransitionWindowID != nil || focusTransitionProgress != 0 else { return }
    focusTransitionWindowID = nil
    setFocusTransitionProgress(0)
  }

  private func setFocusTransitionProgress(_ progress: CGFloat) {
    focusTransitionProgress = min(1, max(0, progress))
    let opacity = CanvasMath.focusBackdropOpacity(progress: focusTransitionProgress)
    for subview in subviews where subview !== sceneView { subview.alphaValue = opacity }
    synchronizeScene()
  }

  private var hoverTargetWindowIDs: Set<CGWindowID> {
    if isHoveringGroupSelection {
      return Set(nodes.filter { groupSelectionIDs.contains(NavigationTarget.window($0).key) }.map(\.id))
    }
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
    // Evaluate an interrupted transition only when another selection actually arrives.
    var current: [CGWindowID: CGFloat] = [:]
    for id in selectionStartProgress.keys { current[id] = selectionProgress(for: id) }
    let previouslyAnimated = Set(selectionStartProgress.keys)
    if let oldID, current[oldID] == nil { current[oldID] = 1 }
    selectionStaysWithinApplication = {
      guard let oldID, let newID,
        let oldNode = nodes.first(where: { $0.id == oldID }),
        let newNode = nodes.first(where: { $0.id == newID }) else { return false }
      return oldNode.processID == newNode.processID
    }()
    let outgoing = current.max { $0.value < $1.value }
    selectionStartProgress.removeAll(keepingCapacity: true)
    if let outgoing, outgoing.key != newID {
      selectionStartProgress[outgoing.key] = outgoing.value
    }
    if let newID {
      selectionStartProgress[newID] = outgoing?.key == newID ? (outgoing?.value ?? 0) : 0
    }
    selectionTargetWindowID = newID
    guard !selectionStartProgress.isEmpty else { return }
    let startedAt = CACurrentMediaTime()
    selectionAnimationStartedAt = startedAt
    let ids = previouslyAnimated.union(selectionStartProgress.keys)
    let processes = Set(nodes.filter { ids.contains($0.id) }.map(\.processID))
    let selectedPID = nodes.first(where: { $0.id == newID })?.processID

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    defer {
      selectionSamplingTime = nil
      CATransaction.commit()
    }
    synchronizeScene(windowIDs: Set(nodes.filter { processes.contains($0.processID) }.map(\.id)))
    for node in nodes where processes.contains(node.processID) {
      let target = NavigationTarget.window(node)
      guard let card = cardLayers[target.key] else { continue }
      let tracks: [(CALayer, String)] = [
        (card.border, "opacity"), (card.border, "lineWidth"),
        (card.border, "path"), (card.border, "shadowPath"), (card.border, "shadowOpacity"),
        (card.header, "opacity"), (card.header, "position"),
        (card.activeHeader, "opacity"), (card.activeHeader, "position"),
      ]
      let interrupted = tracks.map { layer, key -> Any? in
        guard layer.animation(forKey: "selection.\(key)") != nil else { return nil }
        return layer.presentation()?.value(forKeyPath: key)
      }
      var values = Array(repeating: [Any](), count: tracks.count)
      // Sample the existing easing/phase rules once, then let Core Animation play them.
      for index in 0...12 {
        selectionSamplingTime = startedAt + Self.selectionTransitionDuration * Double(index) / 12
        updateSelectionAppearance(card, target: target, selectedPID: selectedPID) { sample in
          for track in tracks.indices {
            values[track].append(index == 0 ? interrupted[track] ?? sample[track] : sample[track])
          }
        }
      }
      // Set destination properties once; preparing keyframes must not mutate the live layers.
      updateSelectionAppearance(card, target: target, selectedPID: selectedPID)
      for (track, pair) in tracks.enumerated() {
        let (layer, key) = pair
        layer.removeAnimation(forKey: "selection.\(key)")
        guard values[track].count == 13, let first = values[track].first,
          values[track].dropFirst().contains(where: { !CFEqual(first as CFTypeRef, $0 as CFTypeRef) })
        else { continue }
        let animation = CAKeyframeAnimation(keyPath: key)
        animation.values = values[track]
        animation.duration = Self.selectionTransitionDuration
        animation.beginTime = layer.convertTime(startedAt, from: nil)
        layer.add(animation, forKey: "selection.\(key)")
      }
    }
  }

  override func mouseDown(with event: NSEvent) {
    guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
    guard cameraAnimation == nil, desktopTransitionStartedAt == nil else { return }
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
    let target = hitNavigationTarget(at: point)
    let togglesSelection = event.modifierFlags.contains(.shift)
    // Shift-click always addresses the item, even where the group's handles overlap it.
    if togglesSelection, let target {
      selectNavigationTarget(target)
      interaction = .items(
        target: target, start: point,
        frames: groupSelectionIDs.contains(target.key) ? selectedItemFrames : [target.key: target.worldFrame],
        togglesSelection: true, dragged: false
      )
      return
    }
    if let handle = selectionResizeHandle(at: point), let selectionRect = groupSelectionWorldRect {
      interaction = .groupResize(handle: handle, start: point, selectionRect: selectionRect)
      resizeCursor(for: handle).set()
      return
    }
    if let target {
      selectNavigationTarget(target)
      if !groupSelectionIDs.contains(target.key) { clearGroupSelection() }
      let isMember = groupSelectionIDs.contains(target.key)
      interaction = .items(
        target: target,
        start: point,
        frames: isMember ? selectedItemFrames : [target.key: target.worldFrame],
        togglesSelection: false,
        dragged: false
      )
      if isMember { NSCursor.closedHand.set() }
    } else if groupSelectionBounds()?.contains(point) == true {
      interaction = .items(
        target: nil,
        start: point,
        frames: selectedItemFrames,
        togglesSelection: false,
        dragged: false
      )
      NSCursor.closedHand.set()
    } else {
      clearGroupSelection()
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
        groupSelectionIDs = CanvasMath.itemIDs(
          containedIn: CanvasMath.selectionRect(from: start, to: point),
          frames: itemFrames,
          camera: camera,
          bounds: bounds
        )
      }
      self.interaction = .marquee(start: start, current: point, dragged: dragged)
      needsDisplay = true

    case .groupResize(let handle, let start, let originalSelectionRect):
      resizeGroupSelection(
        handle: handle,
        from: start,
        originalRect: originalSelectionRect,
        to: point
      )

    case .items(let target, let start, let originalFrames, let togglesSelection, let wasDragged):
      let distance = hypot(point.x - start.x, point.y - start.y)
      let dragged = wasDragged || distance >= 4
      if dragged {
        let translation = CanvasMath.worldTranslation(
          forViewTranslation: CGPoint(x: point.x - start.x, y: point.y - start.y),
          zoom: camera.zoom
        )
        for candidate in nodes {
          guard let frame = originalFrames[NavigationTarget.window(candidate).key] else { continue }
          candidate.worldFrame = frame.offsetBy(dx: translation.x, dy: translation.y)
        }
        for index in appPlaceholders.indices {
          guard let frame = originalFrames[NavigationTarget.placeholder(appPlaceholders[index]).key] else { continue }
          appPlaceholders[index].worldFrame = frame.offsetBy(dx: translation.x, dy: translation.y)
        }
        needsDisplay = true
      }
      self.interaction = .items(
        target: target,
        start: start,
        frames: originalFrames,
        togglesSelection: togglesSelection,
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
    case .marquee(_, _, let dragged) where dragged:
      fitGroupSelectionToItems()
    case .groupResize(let handle, let start, let originalSelectionRect):
      resizeGroupSelection(
        handle: handle,
        from: start,
        originalRect: originalSelectionRect,
        to: point
      )
      fitGroupSelectionToItems()
    case .items(let target, _, let frames, _, true):
      manifestMovedItems(originalFrames: frames, primaryTarget: target)
      fitGroupSelectionToItems()
    case .items(let target?, _, _, let togglesSelection, false):
      if togglesSelection {
        toggleGroupSelection(target)
      } else {
        switch target {
        case .window(let node): delegate?.canvasView(self, didRequestFocus: node)
        case .placeholder(let placeholder): activatePlaceholder(placeholder.bundleIdentifier)
        }
      }
    default:
      break
    }
  }

  override func scrollWheel(with event: NSEvent) {
    guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
    guard cameraAnimation == nil, desktopTransitionStartedAt == nil else { return }
    deferBackgroundWork()
    camera.center = CGPoint(
      x: camera.center.x - event.scrollingDeltaX / camera.zoom,
      y: camera.center.y + event.scrollingDeltaY / camera.zoom
    )
  }

  override func magnify(with event: NSEvent) {
    guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
    guard cameraAnimation == nil, desktopTransitionStartedAt == nil else { return }
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
    displayedNodes.reversed().first { node in
      let rect = CanvasMath.viewRect(for: node.worldFrame, camera: camera, bounds: bounds)
      return rect.insetBy(dx: -20, dy: -30).contains(point)
    }
  }

  private func hitNavigationTarget(at point: CGPoint) -> NavigationTarget? {
    if let node = hitNode(at: point) { return .window(node) }
    return hitPlaceholder(at: point).map(NavigationTarget.placeholder)
  }

  private func hitPlaceholder(at point: CGPoint) -> AppPlaceholder? {
    appPlaceholders.reversed().first { placeholder in
      CanvasMath.viewRect(
        for: placeholder.worldFrame,
        camera: camera,
        bounds: bounds
      ).insetBy(dx: -16, dy: -16).contains(point)
    }
  }

  override func menu(for event: NSEvent) -> NSMenu? {
    let point = convert(event.locationInWindow, from: nil)
    guard bounds.contains(point) else { return nil }
    let bundleIdentifier = hitNode(at: point)?.bundleIdentifier
      ?? hitPlaceholder(at: point)?.bundleIdentifier
    if isChronological, let node = hitNode(at: point) {
      selectedWindowID = node.id
      let menu = NSMenu()
      for (title, action) in [("Close Window", #selector(closeSelectedWindow(_:))),
                               ("Quit App", #selector(quitFromMenu(_:)))] {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
      }
      return menu
    }
    guard let bundleIdentifier,
      desktopPages.selectedAppPlacement(for: bundleIdentifier) != nil
    else { return nil }

    let menu = NSMenu()
    let item = NSMenuItem(
      title: "Forget Position",
      action: #selector(forgetAppPosition(_:)),
      keyEquivalent: ""
    )
    item.target = self
    item.representedObject = bundleIdentifier
    menu.addItem(item)
    return menu
  }

  @objc private func forgetAppPosition(_ sender: NSMenuItem) {
    guard let bundleIdentifier = sender.representedObject as? String else { return }
    desktopPages.forgetSelectedAppPlacement(bundleIdentifier: bundleIdentifier)
    placeholderErrors[bundleIdentifier] = nil
    launchingPlaceholderBundles.remove(bundleIdentifier)
    if selectedPlaceholderBundleIdentifier == bundleIdentifier {
      selectedPlaceholderBundleIdentifier = nil
    }
    persistDesktopPages()
    refreshPlaceholders()
  }

  private func updateHover(at point: CGPoint) {
    guard bounds.contains(point), cameraAnimation == nil, !navigatorPanelFrame.contains(point) else {
      hoveredSelectionResizeHandle = nil
      hoveredPlaceholderBundleIdentifier = nil
      setHoveredWindow(nil)
      NSCursor.arrow.set()
      return
    }
    let selectionBounds = groupSelectionBounds()
    if let handle = selectionResizeHandle(at: point) {
      let changed = hoveredSelectionResizeHandle != handle
      hoveredSelectionResizeHandle = handle
      hoveredPlaceholderBundleIdentifier = nil
      setHoveredWindow(nil)
      resizeCursor(for: handle).set()
      if changed { needsDisplay = true }
      return
    }
    let wasOverResizeHandle = hoveredSelectionResizeHandle != nil
    hoveredSelectionResizeHandle = nil
    let node = hitNode(at: point)
    let placeholder = node == nil ? hitPlaceholder(at: point) : nil
    let target = node.map(NavigationTarget.window) ?? placeholder.map(NavigationTarget.placeholder)
    let isOverGroup = selectionBounds?.contains(point) == true
      && (target.map { groupSelectionIDs.contains($0.key) } ?? true)
    let wasOverGroup = isHoveringGroupSelection
    setHoveredWindow(isOverGroup ? nil : node?.id, asGroup: isOverGroup)
    hoveredPlaceholderBundleIdentifier = isOverGroup
      ? nil : placeholder?.bundleIdentifier
    if isOverGroup {
      NSCursor.openHand.set()
    } else if wasOverGroup || wasOverResizeHandle {
      NSCursor.arrow.set()
    }
  }

  private func clearGroupSelection() {
    groupSelectionIDs.removeAll()
    resizingGroupSelectionWorldRect = nil
    hoveredSelectionResizeHandle = nil
    if isHoveringGroupSelection { setHoveredWindow(nil) }
    needsDisplay = true
  }

  private var itemFrames: [String: CGRect] {
    Dictionary(uniqueKeysWithValues: navigationTargets.map { ($0.key, $0.worldFrame) })
  }

  private var selectedItemFrames: [String: CGRect] {
    itemFrames.filter { groupSelectionIDs.contains($0.key) }
  }

  private func toggleGroupSelection(_ target: NavigationTarget) {
    if !groupSelectionIDs.insert(target.key).inserted {
      groupSelectionIDs.remove(target.key)
    }
    if nativeCameraTravel, !groupSelectionIDs.isEmpty, let animation = cameraAnimation {
      // The group overlay follows screen-space geometry, so keep its existing frame updates.
      animateCamera(to: animation.target,
        duration: max(0.001, animation.duration - (CACurrentMediaTime() - animation.startedAt)),
        completion: animation.completion)
    }
    fitGroupSelectionToItems()
  }

  private func fitGroupSelectionToItems() {
    // Once released, the frame follows current rendered geometry at every zoom.
    resizingGroupSelectionWorldRect = nil
    if groupSelectionIDs.isEmpty { clearGroupSelection() }
    needsDisplay = true
  }

  private func selectionResizeHandle(at point: CGPoint) -> SelectionResizeHandle? {
    guard groupSelectionWorldRect != nil, let selectionBounds = groupSelectionBounds() else {
      return nil
    }
    let hitFrames = CanvasMath.selectionResizeHandleFrames(
      for: selectionBounds,
      size: Self.selectionHandleHitSize
    )
    if let handle = SelectionResizeHandle.allCases.first(where: { handle in
      hitFrames[handle]?.contains(point) == true
    }) {
      return handle
    }

    let tolerance = Self.selectionHandleHitSize / 2
    if abs(point.y - selectionBounds.maxY) <= tolerance,
      point.x >= selectionBounds.minX,
      point.x <= selectionBounds.maxX
    {
      return .top
    }
    if abs(point.y - selectionBounds.minY) <= tolerance,
      point.x >= selectionBounds.minX,
      point.x <= selectionBounds.maxX
    {
      return .bottom
    }
    if abs(point.x - selectionBounds.minX) <= tolerance,
      point.y >= selectionBounds.minY,
      point.y <= selectionBounds.maxY
    {
      return .left
    }
    if abs(point.x - selectionBounds.maxX) <= tolerance,
      point.y >= selectionBounds.minY,
      point.y <= selectionBounds.maxY
    {
      return .right
    }
    return nil
  }

  private func resizeGroupSelection(
    handle: SelectionResizeHandle,
    from start: CGPoint,
    originalRect: CGRect,
    to point: CGPoint
  ) {
    let translation = CanvasMath.worldTranslation(
      forViewTranslation: CGPoint(x: point.x - start.x, y: point.y - start.y),
      zoom: camera.zoom
    )
    let resizedRect = CanvasMath.resizedSelectionRect(
      originalRect,
      dragging: handle,
      by: translation,
      minimumSize: CGSize(
        width: Self.minimumGroupSize / camera.zoom,
        height: Self.minimumGroupSize / camera.zoom
      )
    )
    resizingGroupSelectionWorldRect = resizedRect
    groupSelectionIDs = CanvasMath.itemIDs(
      containedIn: CanvasMath.viewRect(for: resizedRect, camera: camera, bounds: bounds),
      frames: itemFrames,
      camera: camera,
      bounds: bounds
    )
    needsDisplay = true
  }

  private func resizeCursor(for handle: SelectionResizeHandle) -> NSCursor {
    let position: NSCursor.FrameResizePosition = switch handle {
    case .topLeft: .topLeft
    case .top: .top
    case .topRight: .topRight
    case .right: .right
    case .bottomRight: .bottomRight
    case .bottom: .bottom
    case .bottomLeft: .bottomLeft
    case .left: .left
    }
    return NSCursor.frameResize(position: position, directions: .all)
  }

  private func moveSelection(_ direction: CanvasDirection) {
    // Selection, navigator and camera changes belong to one event/one layer commit.
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    defer { CATransaction.commit() }
    if isChronological, direction == .up || direction == .down {
      stepRecent(by: direction == .up ? -1 : 1, wrapping: false)
      return
    }
    let targets = navigationTargets
    guard !targets.isEmpty else { return }

    guard let selected = selectedNavigationTarget else {
      if let closest = targets.min(by: {
        hypot($0.center.x - camera.center.x, $0.center.y - camera.center.y)
          < hypot($1.center.x - camera.center.x, $1.center.y - camera.center.y)
      }) {
        selectNavigationTarget(closest)
        centerCamera(on: closest)
      }
      return
    }

    let candidates = targets.filter { $0.key != selected.key }.map {
      (id: $0.key, frame: $0.worldFrame)
    }
    guard
      let nextKey = CanvasMath.directionalNeighbor(
        from: selected.worldFrame,
        candidates: candidates,
        direction: direction
      ),
      let next = targets.first(where: { $0.key == nextKey })
    else { return }

    selectNavigationTarget(next)
    centerCamera(on: next)
  }

  private func centerCamera(on target: NavigationTarget) {
    let targetCamera = CanvasMath.cameraCentered(
      on: target.worldFrame,
      preserving: camera
    )
    if targetCamera != camera {
      animateCamera(
        to: targetCamera,
        duration: Self.selectionTransitionDuration,
        completion: {}
      )
    }
  }

  private var navigationTargets: [NavigationTarget] {
    if isChronological {
      let byID = Dictionary(uniqueKeysWithValues: displayedNodes.map { ($0.id, $0) })
      return recentWindows.visible.compactMap { byID[$0].map(NavigationTarget.window) }
        + appPlaceholders.map(NavigationTarget.placeholder)
    }
    return nodes.map(NavigationTarget.window) + appPlaceholders.map(NavigationTarget.placeholder)
  }

  private var selectedNavigationTarget: NavigationTarget? {
    if let selectedWindowID,
      let node = nodes.first(where: { $0.id == selectedWindowID })
    {
      return .window(node)
    }
    if let selectedPlaceholderBundleIdentifier,
      let placeholder = appPlaceholders.first(where: {
        $0.bundleIdentifier == selectedPlaceholderBundleIdentifier
      })
    {
      return .placeholder(placeholder)
    }
    return nil
  }

  private func selectNavigationTarget(_ target: NavigationTarget) {
    switch target {
    case .window(let node): selectedWindowID = node.id
    case .placeholder(let placeholder): selectPlaceholder(placeholder.bundleIdentifier)
    }
  }

  private func miniMapProjection(camera: CameraState? = nil, itemBounds: CGRect? = nil) -> MiniMapProjection? {
    let camera = camera ?? self.camera
    let itemBounds = itemBounds ?? canvasItemFrames.reduce(CGRect.null) { $0.union($1) }
    guard !itemBounds.isNull, bounds.width >= 480, bounds.height >= 320 else { return nil }

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
    let worldBounds = itemBounds.union(viewportWorldFrame)
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
    let hover: CGFloat = isHoveringGroupSelection ? 1 : 0
    drawSelectionBox(
      bounds,
      fillAlpha: 0.14 + 0.05 * hover,
      strokeAlpha: 0.72 + 0.2 * hover
    )
  }

  private func groupSelectionBounds() -> CGRect? {
    if let resizingGroupSelectionWorldRect {
      return CanvasMath.viewRect(
        for: resizingGroupSelectionWorldRect, camera: camera, bounds: bounds)
    }
    return CanvasMath.groupSelectionBounds(
      for: navigationTargets.filter { groupSelectionIDs.contains($0.key) }.map { target in
        let rect: CGRect
        let hasIcon: Bool
        let hasTitle: Bool
        var borderOutset: CGFloat
        switch target {
        case .window(let node):
          rect = previewViewRect(for: node)
          hasIcon = node.icon != nil
          hasTitle = !node.displayTitle.isEmpty
          let progress = selectionProgress(for: node.id) ?? (node.id == selectedWindowID ? 1 : 0)
          if selectionStaysWithinApplication,
            nodes.first(where: { $0.id == selectedWindowID })?.processID == node.processID
          {
            borderOutset =
              2 + CanvasMath.sameApplicationSelectionMetrics(primaryProgress: progress).borderWidth
          } else {
            borderOutset = node.id == selectedWindowID || progress > 0 ? 6 : 4
          }
        case .placeholder(let placeholder):
          rect = CanvasMath.viewRect(for: placeholder.worldFrame, camera: camera, bounds: bounds)
          hasIcon = placeholder.icon != nil
          hasTitle = !placeholder.applicationName.isEmpty
          borderOutset = placeholder.bundleIdentifier == selectedPlaceholderBundleIdentifier ? 6 : 4
        }
        return CanvasMath.previewVisualBounds(
          for: rect, zoom: camera.zoom,
          titleLift: previewTitlePresentation(for: target).lift, borderOutset: borderOutset,
          hasIcon: hasIcon, hasTitle: hasTitle
        )
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
    path.lineCapStyle = .round
    path.setLineDash([0, 6], count: 2, phase: 0)
    path.stroke()
  }

  private func drawPrivatePreview(in rect: CGRect) {
    let title = "PRIVATE WINDOW" as NSString
    let subtitle = "Preview hidden" as NSString
    let titleFont = NSFont.systemFont(
      ofSize: max(8, min(15, rect.height * 0.08)),
      weight: .semibold
    )
    let subtitleFont = NSFont.systemFont(
      ofSize: max(7, min(12, rect.height * 0.06)),
      weight: .regular
    )
    let titleAttributes: [NSAttributedString.Key: Any] = [
      .font: titleFont,
      .foregroundColor: NSColor.white.withAlphaComponent(0.78),
    ]
    let subtitleAttributes: [NSAttributedString.Key: Any] = [
      .font: subtitleFont,
      .foregroundColor: NSColor.white.withAlphaComponent(0.45),
    ]
    let titleSize = title.size(withAttributes: titleAttributes)
    let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
    title.draw(
      at: CGPoint(x: rect.midX - titleSize.width / 2, y: rect.midY + 2),
      withAttributes: titleAttributes
    )
    subtitle.draw(
      at: CGPoint(x: rect.midX - subtitleSize.width / 2, y: rect.midY - subtitleSize.height - 4),
      withAttributes: subtitleAttributes
    )
  }

  private func previewViewRect(for node: WindowNode) -> CGRect {
    let rect = CanvasMath.viewRect(for: node.worldFrame, camera: camera, bounds: bounds)
    let expansion = 3 * (windowHoverProgress[node.id] ?? 0)
    return rect.insetBy(dx: -expansion, dy: -expansion)
  }

  private func previewTitlePresentation(for target: NavigationTarget) -> (
    progress: CGFloat, lift: CGFloat
  ) {
    switch target {
    case .placeholder(let placeholder):
      let isSelected = selectedPlaceholderBundleIdentifier == placeholder.bundleIdentifier
      let progress: CGFloat = isSelected || groupSelectionIDs.contains(target.key) ? 1 : 0
      return (progress, CanvasMath.selectionTitleLift(progress: progress, isPrimary: isSelected))
    case .window(let node):
      let isSelected = node.id == selectedWindowID
      let isSelectedApplication =
        nodes.first(where: { $0.id == selectedWindowID })?.processID == node.processID
      if selectionStaysWithinApplication && isSelectedApplication {
        let progress = selectionProgress(for: node.id) ?? (isSelected ? 1 : 0)
        return (1, CanvasMath.sameApplicationSelectionMetrics(primaryProgress: progress).titleLift)
      }
      let progress: CGFloat
      if groupSelectionIDs.contains(target.key) {
        progress = 1
      } else {
        let selection =
          isSelectedApplication && !isSelected
          ? selectedWindowID.flatMap { selectionProgress(for: $0) } ?? 1
          : selectionProgress(for: node.id) ?? (isSelected ? 1 : 0)
        progress =
          CanvasMath.selectionAnimationPhases(
            progress: selection
          ).title
      }
      return (
        progress,
        CanvasMath.selectionTitleLift(
          progress: progress, isPrimary: isSelected || selectionStartProgress[node.id] != nil
        )
      )
    }
  }

  private func drawAppIcon(_ icon: NSImage?, in badgeFrame: CGRect) {
    guard let icon else { return }
    let badgeSize = badgeFrame.width
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
    shadow.shadowBlurRadius = 7.5 * badgeSize / CanvasMath.appIconSize
    shadow.shadowOffset = CGSize(width: 0, height: -2.25 * badgeSize / CanvasMath.appIconSize)
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

  private func scheduleCameraMaintenance() {
    cameraChangedAt = CACurrentMediaTime()
    guard !cameraMaintenancePending else { return }
    cameraMaintenanceStarts += 1
    previewToolTipUpdateTask?.cancel()
    previewToolTipUpdateTask = nil
    NSObject.cancelPreviousPerformRequests(
      withTarget: self, selector: #selector(persistDesktopPages), object: nil)
    cameraMaintenancePending = true
    perform(#selector(performCameraMaintenance), with: nil, afterDelay: 0.3)
  }

  @objc private func performCameraMaintenance() {
    guard CACurrentMediaTime() - cameraChangedAt >= 0.3,
      cameraAnimation == nil, keyboardZoomGesture == nil,
      keyboardTapZoomAnimation == nil, desktopTransitionStartedAt == nil,
      interaction == nil else {
      perform(#selector(performCameraMaintenance), with: nil, afterDelay: 0.3)
      return
    }
    cameraMaintenancePending = false
    cameraMaintenanceRuns += 1
    persistDesktopPages()
    updatePreviewToolTips()
  }

  private func schedulePreviewToolTipUpdate() {
    guard !cameraMaintenancePending else { return }
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

    for node in displayedNodes {
      guard node.previewState != .current, node.previewState != .redacted else { continue }
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

  private func drawDesktopTitleNudge() {
    let width = CanvasMath.desktopTitleNudgeWidth(
      textWidth: desktopTabsScrollView.frame.width - 24,
      availableWidth: bounds.width - 64
    )
    let cornerRadius: CGFloat = 22
    let layout = desktopTitleNudgeLayout
    let frame = CGRect(
      x: bounds.midX - width / 2,
      y: bounds.maxY - layout.depth,
      width: width,
      height: layout.depth + cornerRadius
    )
    let path = NSBezierPath(
      roundedRect: frame,
      xRadius: cornerRadius,
      yRadius: cornerRadius
    )
    background.color.withAlphaComponent(0.75).setFill()
    path.fill()
  }

  private var desktopTitleNudgeLayout: CanvasMath.DesktopTitleNudgeLayout {
    CanvasMath.desktopTitleNudgeLayout(
      safeAreaTop: window?.screen?.safeAreaInsets.top ?? 32
    )
  }

  private func drawDebugInformation() {
    let label = String(format: "Zoom %.2f×", camera.zoom)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: debugInformationFont,
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
  }

  private func drawSearchStatus(in panel: CGRect) {
    let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let matches = searchResults
    let selectedIndex = matches.firstIndex { $0.key == selectedNavigationTarget?.key }
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
    let arrowCount = [previousSearchResultButton, nextSearchResultButton].filter { !$0.isHidden }.count
    let statusX = panel.minX + 18 + CGFloat(arrowCount) * 28
    let statusFrame = CGRect(
      x: statusX,
      y: panel.minY,
      width: panel.maxX - 12 - statusX,
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
    desktopTitleField.wantsLayer = true
    desktopTitleField.layer?.cornerRadius = 10
    desktopTabsScrollView.drawsBackground = false
    desktopTabsScrollView.hasHorizontalScroller = true
    desktopTabsScrollView.autohidesScrollers = true
    desktopTabsScrollView.scrollerStyle = .overlay
    desktopTabsScrollView.horizontalScrollElasticity = .allowed
    desktopTabsScrollView.verticalScrollElasticity = .none
    desktopTabsScrollView.documentView = desktopTabsContent
    desktopTabsScrollView.setAccessibilityLabel("Desktops")
    addSubview(desktopTabsScrollView)
    desktopTabsContent.addSubview(desktopTitleField)
    addDesktopButton.title = ""
    addDesktopButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New desktop")
    addDesktopButton.isBordered = false
    addDesktopButton.contentTintColor = .white.withAlphaComponent(0.7)
    addDesktopButton.toolTip = "New desktop (+)"
    addDesktopButton.setAccessibilityLabel("New desktop")
    addDesktopButton.target = self
    addDesktopButton.action = #selector(addDesktopPage(_:))
    desktopTabsContent.addSubview(addDesktopButton)
    rebuildDesktopTabs()
  }

  private func rebuildDesktopTabs() {
    desktopTabButtons.forEach { $0.removeFromSuperview() }
    desktopTabButtons = desktopPages.pages.enumerated().map { index, page in
      let button = NSButton(title: page.displayTitle, target: self, action: #selector(selectDesktopTab(_:)))
      button.tag = index
      button.isBordered = false
      button.font = Self.desktopTabFont
      button.contentTintColor = .white.withAlphaComponent(0.65)
      button.cell?.lineBreakMode = .byTruncatingTail
      button.toolTip = "Switch to \(page.displayTitle)"
      button.setAccessibilityLabel(button.toolTip)
      desktopTabsContent.addSubview(button)
      return button
    }
    updateDesktopTabs()
  }

  private func updateDesktopTabs() {
    let multiple = desktopPages.pages.count > 1
    desktopTitleField.stringValue = desktopPages.selectedPage.title
    desktopTitleField.font = multiple ? Self.desktopTabFont : Self.desktopTitleFont
    if let placeholder = desktopTitleField.placeholderAttributedString?.mutableCopy() as? NSMutableAttributedString {
      placeholder.addAttribute(.font, value: desktopTitleField.font!, range: NSRange(location: 0, length: placeholder.length))
      desktopTitleField.placeholderAttributedString = placeholder
      desktopTitleField.placeholderAttributedStrings = [placeholder]
    }
    desktopTitleField.layer?.backgroundColor = multiple
      ? NSColor.white.withAlphaComponent(0.14).cgColor : NSColor.clear.cgColor
    desktopTitleField.toolTip = "Rename this desktop"
    for (button, page) in zip(desktopTabButtons, desktopPages.pages) {
      button.title = page.displayTitle
      button.toolTip = "Switch to \(page.displayTitle)"
      button.setAccessibilityLabel(button.toolTip)
      button.isHidden = page.id == desktopPages.selectedID
    }
    layoutDesktopTabs()
    desktopTabsScrollView.layoutSubtreeIfNeeded()
    desktopTabsContent.scrollToVisible(desktopTitleField.frame)
    needsDisplay = true
  }

  private func layoutDesktopTabs() {
    let multiple = desktopPages.pages.count > 1
    let font = multiple ? Self.desktopTabFont : Self.desktopTitleFont
    let widths = desktopPages.pages.map { page in
      let title = page.title.isEmpty ? "Name this desktop" : page.displayTitle
      let textWidth = title.size(withAttributes: [.font: font]).width
      // Whole-point widths keep the last tab fully inside AppKit's rounded scroll bounds.
      return ceil(min(multiple ? 260 : 720, max(multiple ? 96 : 180, textWidth + 32)))
    }
    let gap: CGFloat = 8
    let contentWidth = widths.reduce(0, +) + CGFloat(widths.count) * gap + 36
    let layout = desktopTitleNudgeLayout
    let visibleWidth = min(contentWidth, max(0, bounds.width - 96))
    desktopTabsScrollView.frame = CGRect(
      x: bounds.midX - visibleWidth / 2,
      y: bounds.maxY - layout.titleTopInset - layout.titleBoxHeight,
      width: visibleWidth, height: layout.titleBoxHeight
    )
    desktopTabsContent.frame = CGRect(x: 0, y: 0, width: contentWidth, height: layout.titleBoxHeight)
    var x: CGFloat = 0
    for (index, width) in widths.enumerated() {
      let frame = CGRect(x: x, y: 0, width: width, height: layout.titleBoxHeight)
      desktopTabButtons[index].frame = frame
      if desktopPages.pages[index].id == desktopPages.selectedID {
        desktopTitleField.frame = frame
      }
      x += width + gap
    }
    addDesktopButton.frame = CGRect(x: x, y: 0, width: 36, height: layout.titleBoxHeight)
  }

  @objc private func selectDesktopTab(_ sender: NSButton) {
    guard desktopPages.pages.indices.contains(sender.tag) else { return }
    selectDesktop(id: desktopPages.pages[sender.tag].id)
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
    menuButton.image = Self.settingsImage()
    menuButton.contentTintColor = .white.withAlphaComponent(0.82)
    menuButton.imagePosition = .imageOnly
    menuButton.imageScaling = .scaleProportionallyDown
    menuButton.isBordered = false
    menuButton.focusRingType = .none
    menuButton.toolTip = "Settings"
    menuButton.setAccessibilityLabel("Settings")
    menuButton.target = self
    menuButton.action = #selector(showSettings(_:))
    addSubview(menuButton)

    expandLandscapePreviewsMenuItem.title = "Expand previews"
    expandLandscapePreviewsMenuItem.target = self
    expandLandscapePreviewsMenuItem.action = #selector(toggleLandscapePreviewExpansion(_:))
    debugInformationMenuItem.title = "Show Debug Information"
    debugInformationMenuItem.target = self
    debugInformationMenuItem.action = #selector(toggleDebugInformation(_:))
    gridMenuItem.title = "Show Grid Dots"
    gridMenuItem.target = self
    gridMenuItem.action = #selector(toggleGrid(_:))
    centerGuideMenuItem.title = "Show Center Guide"
    centerGuideMenuItem.target = self
    centerGuideMenuItem.action = #selector(toggleCenterGuide(_:))
    lightClosedCardsMenuItem.title = "Use Light Closed Cards"
    lightClosedCardsMenuItem.target = self
    lightClosedCardsMenuItem.action = #selector(toggleLightClosedCards(_:))
    privateBrowserPreviewsMenuItem.title = "Show Private Browser Previews"
    privateBrowserPreviewsMenuItem.target = self
    privateBrowserPreviewsMenuItem.action = #selector(togglePrivateBrowserPreviews(_:))
    commandTabShortcutMenuItem.title = "Use ⌘Tab for OpenPlane"
    commandTabShortcutMenuItem.target = self
    commandTabShortcutMenuItem.action = #selector(toggleCommandTabShortcut(_:))
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
    nextSearchResultButton.usesOpacityOnlyHover = true
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
    previousSearchResultButton.usesOpacityOnlyHover = true
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
    let previousVisibility = [backButton.isHidden, forwardButton.isHidden]
    let selectedNode = nodes.first(where: { $0.id == selectedWindowID })
    let selectedPlaceholder = selectedPlaceholderBundleIdentifier.flatMap { bundleIdentifier in
      appPlaceholders.first { $0.bundleIdentifier == bundleIdentifier }
    }
    let previewNode =
      isHoveringBackButton ? backNavigationTarget
      : isHoveringForwardButton ? forwardNavigationTarget : selectedNode
    let title = previewNode?.applicationName
      ?? selectedPlaceholder?.applicationName
      ?? "No app selected"
    let icon = previewNode?.icon ?? selectedPlaceholder?.icon
    let contentID = previewNode.map { "window:\($0.id)" }
      ?? selectedPlaceholder.map { "app:\($0.bundleIdentifier)" }
    focusButton.isEnabled = selectedNode != nil || selectedPlaceholder != nil
    if !hasDisplayedNavigatorContent || displayedNavigatorContentID != contentID {
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
          .foregroundColor: NSColor.white.withAlphaComponent(contentID == nil ? 0.42 : 0.92),
        ]
      )
      if let icon = icon?.copy() as? NSImage {
        icon.size = CGSize(width: 22, height: 22)
        focusButton.image = icon
      } else {
        focusButton.image = nil
      }
      displayedNavigatorContentID = contentID
      hasDisplayedNavigatorContent = true
    }
    let selectedApplicationName = selectedNode?.applicationName
      ?? selectedPlaceholder?.applicationName
    focusButton.toolTip = selectedApplicationName.map { "Open \($0)" }
    focusButton.setAccessibilityLabel(selectedApplicationName.map { "Open \($0)" } ?? title)
    backButton.isEnabled = backNavigationTarget != nil
    backButton.isHidden = isSearching || backNavigationTarget == nil
    backButton.toolTip = backNavigationTarget.map { "Select \($0.applicationName)" }
    backButton.setAccessibilityLabel(backButton.toolTip ?? "Select previous app")
    forwardButton.isEnabled = forwardNavigationTarget != nil
    forwardButton.isHidden = isSearching || forwardNavigationTarget == nil
    forwardButton.toolTip = forwardNavigationTarget.map { "Select \($0.applicationName)" }
    forwardButton.setAccessibilityLabel(forwardButton.toolTip ?? "Select next app")
    expandLandscapePreviewsMenuItem.state = expandsLandscapePreviews ? .on : .off
    debugInformationMenuItem.state = showsDebugInformation ? .on : .off
    gridMenuItem.state = showsGrid ? .on : .off
    centerGuideMenuItem.state = showsCenterGuide ? .on : .off
    lightClosedCardsMenuItem.state = usesLightClosedCards ? .on : .off
    privateBrowserPreviewsMenuItem.state = showsPrivateBrowserPreviews ? .on : .off
    commandTabShortcutMenuItem.state = usesCommandTabShortcut ? .on : .off
    updateLockViewButton()
    if previousVisibility != [backButton.isHidden, forwardButton.isHidden] {
      needsLayout = true
    }
  }

  func controlTextDidChange(_ notification: Notification) {
    guard let field = notification.object as? NSTextField else { return }
    if field === desktopTitleField {
      keepDesktopTitleInsertionPointWhite()
      desktopPages.renameSelectedPage(field.stringValue)
      scheduleDesktopPagesPersistence()
      needsLayout = true
      needsDisplay = true
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
    keepDesktopTitleInsertionPointWhite()
    DispatchQueue.main.async { [weak self] in
      self?.keepDesktopTitleInsertionPointWhite()
    }
  }

  private func keepDesktopTitleInsertionPointWhite() {
    guard let editor = desktopTitleField.currentEditor() as? NSTextView else { return }
    editor.insertionPointColor = .white
    editor.needsDisplay = true
  }

  func control(
    _ control: NSControl,
    textView: NSTextView,
    doCommandBy commandSelector: Selector
  ) -> Bool {
    if control === desktopTitleField {
      DispatchQueue.main.async { [weak self] in
        self?.keepDesktopTitleInsertionPointWhite()
      }
      return false
    }
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

  private func matchesSearch(_ target: NavigationTarget) -> Bool {
    switch target {
    case .window(let node):
      CanvasSearch.matches(
        query: searchField.stringValue, applicationName: node.applicationName, title: node.displayTitle)
    case .placeholder(let placeholder):
      CanvasSearch.matches(
        query: searchField.stringValue, applicationName: placeholder.applicationName, title: "")
    }
  }

  private func searchOpacity(for target: NavigationTarget) -> CGFloat {
    // Closed cards already have their subdued appearance; search must not dim them again.
    guard case .window = target else { return 1 }
    return isSearching && !matchesSearch(target) ? 0.14 : 1
  }

  private var searchResults: [NavigationTarget] {
    let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    return query.isEmpty ? [] : navigationTargets.filter(matchesSearch)
  }

  private func updateSearchResults(centerSelection: Bool) {
    guard isSearching else { return }
    if showingAllApps { refreshRecentPlaceholders() }
    let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      if showingAllApps, let first = appPlaceholders.first {
        selectPlaceholder(first.bundleIdentifier)
        if centerSelection { centerCamera(on: .placeholder(first)) }
      }
      updateSearchNavigationButtons()
      needsDisplay = true
      return
    }

    let matches = searchResults
    let currentMatch = matches.first { $0.key == selectedNavigationTarget?.key }
    guard let result = currentMatch ?? matches.first else {
      selectedWindowID = nil
      selectedPlaceholderBundleIdentifier = nil
      updateSearchNavigationButtons()
      return
    }

    let changed = selectedNavigationTarget?.key != result.key
    selectNavigationTarget(result)
    updateSearchNavigationButtons()
    if centerSelection, changed || showingAllApps {
      centerCamera(on: result)
    }
  }

  private func moveSearchSelection(by offset: Int) {
    let matches = searchResults
    guard let currentIndex = matches.firstIndex(where: { $0.key == selectedNavigationTarget?.key }) else {
      return
    }
    let nextIndex = currentIndex + offset
    guard matches.indices.contains(nextIndex) else { return }
    let result = matches[nextIndex]
    selectNavigationTarget(result)
    updateSearchNavigationButtons()
    centerCamera(on: result)
  }

  private func updateSearchNavigationButtons() {
    let matches = searchResults
    let selectedIndex = matches.firstIndex { $0.key == selectedNavigationTarget?.key }
    nextSearchResultButton.isEnabled = isSearching && (selectedIndex.map { $0 < matches.count - 1 } ?? false)
    previousSearchResultButton.isEnabled = isSearching && (selectedIndex.map { $0 > 0 } ?? false)
    for button in [nextSearchResultButton, previousSearchResultButton] {
      button.isHidden = !button.isEnabled
      button.contentTintColor = .white
    }
    needsLayout = true
    needsDisplay = true
  }

  private func beginSearch(with text: String = "") {
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
    lockViewButton.isHidden = visible
    menuButton.isHidden = visible
    nextSearchResultButton.isHidden = true
    previousSearchResultButton.isHidden = true
    if visible {
      updateSearchNavigationButtons()
    } else {
      updateNavigatorPanel()
    }
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

  @objc private func toggleGrid(_ sender: NSMenuItem) {
    showsGrid.toggle()
    UserDefaults.standard.set(showsGrid, forKey: "showGrid")
    sender.state = showsGrid ? .on : .off
    gridZoom = nil
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    updateGrid(camera: camera)
    CATransaction.commit()
  }

  @objc private func toggleCenterGuide(_ sender: NSMenuItem) {
    showsCenterGuide.toggle()
    UserDefaults.standard.set(showsCenterGuide, forKey: Self.centerGuidePreferenceKey)
    sender.state = showsCenterGuide ? .on : .off
    needsDisplay = true
  }

  @objc private func toggleLightClosedCards(_ sender: NSMenuItem) {
    usesLightClosedCards.toggle()
    UserDefaults.standard.set(usesLightClosedCards, forKey: Self.lightClosedCardsPreferenceKey)
    sender.state = usesLightClosedCards ? .on : .off
    needsDisplay = true
  }

  @objc private func togglePrivateBrowserPreviews(_ sender: NSMenuItem) {
    showsPrivateBrowserPreviews.toggle()
    UserDefaults.standard.set(
      showsPrivateBrowserPreviews,
      forKey: OpenPlanePreferences.showPrivateBrowserPreviews
    )
    sender.state = showsPrivateBrowserPreviews ? .on : .off
    delegate?.canvasView(self, setPrivateBrowserPreviews: showsPrivateBrowserPreviews)
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
    guard searchResults.contains(where: { $0.key == selectedNavigationTarget?.key }) else { return }
    focusSelectedWindow()
  }

  @objc private func selectNextSearchResult(_ sender: NSButton) {
    moveSearchSelection(by: 1)
  }

  @objc private func selectPreviousSearchResult(_ sender: NSButton) {
    moveSearchSelection(by: -1)
  }

  @objc private func fitAllWindows(_ sender: NSButton) {
    if !isChronological, let lockedCamera = desktopPages.selectedPage.lockedCamera {
      animateCamera(to: lockedCamera) {}
      return
    }
    guard !canvasItemFrames.isEmpty else { return }
    let target = CanvasMath.fitCamera(frames: canvasItemFrames, in: bounds)
    animateCamera(to: target) {}
  }

  @objc private func commitDesktopTitle(_ sender: NSTextField) {
    desktopPages.renameSelectedPage(sender.stringValue)
    persistDesktopPages()
    window?.makeFirstResponder(self)
    updateDesktopTabs()
  }

  @objc private func toggleLockedView(_ sender: NSButton) {
    guard !isChronological else { return }
    desktopPages.toggleSelectedPageLock(at: camera)
    persistDesktopPages()
    updateLockViewButton()
  }

  @objc private func addDesktopPage(_ sender: Any?) {
    guard !isChronological else { return }
    transitionDesktop { [weak self] in
      guard let self else { return }
      // Desktops are independent arrangements, not adjacent regions of one plane.
      _ = self.desktopPages.addPage(camera: self.camera)
      self.rebuildDesktopTabs()
      self.applySelectedDesktop(camera: self.camera)
    }
  }

  private func selectDesktop(id: UUID) {
    guard !isChronological else { return }
    guard desktopPages.pages.contains(where: { $0.id == id }) else { return }
    guard id != desktopPages.selectedID || desktopTransitionStartedAt != nil else { return }
    transitionDesktop { [weak self] in
      guard let self else { return }
      let target = self.desktopPages.select(id) ?? self.camera
      self.applySelectedDesktop(camera: target)
    }
  }

  private func applySelectedDesktop(camera target: CameraState) {
    clearGroupSelection()
    selectedWindowID = nil
    selectedPlaceholderBundleIdentifier = nil
    // Assign, don't interpolate: Core Animation crossfades the old and new scenes.
    camera = target
    applySelectedDesktopLayout(around: target.center)
    updateDesktopTabs()
    updateNavigatorPanel()
    persistDesktopPages()
    updateLockViewButton()
  }

  private func transitionDesktop(direction: Int? = nil, _ change: @escaping () -> Void) {
    if desktopTransitionStartedAt != nil {
      pendingDesktopChanges.append((direction, change))
      return
    }
    window?.makeFirstResponder(self)
    dismissSearch()
    stopKeyboardZoom(completingTap: false)
    stopKeyboardTapZoom()
    stopNativeCameraTravel()
    animationDisplayLink?.invalidate()
    animationDisplayLink = nil
    cameraAnimation = nil
    isPresentingFinalAnimationFrame = false
    endFocusTransition()
    interaction = nil
    setHoveredWindow(nil)
    synchronizeManifestedPlacements()
    persistDesktopPages()

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let previousIndex = desktopPages.pages.firstIndex(where: { $0.id == desktopPages.selectedID }) ?? 0
    change()
    let nextIndex = desktopPages.pages.firstIndex(where: { $0.id == desktopPages.selectedID }) ?? previousIndex
    synchronizeScene()
    if nextIndex != previousIndex {
      let forward = direction.map { $0 > 0 } ?? (nextIndex > previousIndex)
      let offset: CGFloat = forward ? -40 : 40
      for layer in [cameraLayer, gridLayer] {
        let slide = CABasicAnimation(keyPath: "position")
        slide.fromValue = NSValue(point: CGPoint(x: layer.position.x + offset, y: layer.position.y))
        slide.toValue = NSValue(point: layer.position)
        slide.duration = Self.desktopTransitionDuration
        slide.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(slide, forKey: "desktopSlide")
      }
    }
    hudView.needsDisplay = true
    hudView.displayIfNeeded()
    for layer in [sceneView.layer, hudView.layer].compactMap({ $0 }) {
      let fade = CATransition()
      fade.type = .fade
      fade.duration = Self.desktopTransitionDuration
      fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      layer.add(fade, forKey: "desktopCrossfade")
    }
    CATransaction.commit()
    desktopTransitionStartedAt = CACurrentMediaTime()
    let link = displayLink(target: self, selector: #selector(stepDesktopTransition(_:)))
    desktopTransitionDisplayLink = link
    link.add(to: .main, forMode: .common)
  }

  @objc private func stepDesktopTransition(_ displayLink: CADisplayLink) {
    guard let startedAt = desktopTransitionStartedAt else {
      displayLink.invalidate()
      return
    }
    advanceDesktopTransition(to: (CACurrentMediaTime() - startedAt) / Self.desktopTransitionDuration)
  }

  // Core Animation draws the fade; this clock only gates input and pending switches.
  func advanceDesktopTransition(to progress: CGFloat) {
    guard desktopTransitionStartedAt != nil else { return }
    if progress >= 1 {
      finishDesktopTransition(completingQueuedChanges: false)
      if !pendingDesktopChanges.isEmpty {
        let pending = pendingDesktopChanges.removeFirst()
        transitionDesktop(direction: pending.direction, pending.change)
      }
    }
  }

  private func finishDesktopTransition(completingQueuedChanges: Bool = true) {
    guard desktopTransitionStartedAt != nil else { return }
    desktopTransitionStartedAt = nil
    desktopTransitionDisplayLink?.invalidate()
    desktopTransitionDisplayLink = nil
    if completingQueuedChanges {
      let pending = pendingDesktopChanges
      pendingDesktopChanges.removeAll()
      for pending in pending { pending.change() }
    }
    for layer in [sceneView.layer, hudView.layer].compactMap({ $0 }) {
      layer.removeAnimation(forKey: "desktopCrossfade")
    }
    for layer in [cameraLayer, gridLayer] {
      layer.removeAnimation(forKey: "desktopSlide")
    }
    needsDisplay = true
  }

  private func updateLockViewButton() {
    let locked = desktopPages.isSelectedPageLocked
    guard displayedLockState != locked else { return }
    displayedLockState = locked
    lockViewButton.image = Self.lockViewImage(locked: locked)
    lockViewButton.toolTip = locked ? "Unlock desktop view" : "Lock current desktop view"
    lockViewButton.setAccessibilityLabel(lockViewButton.toolTip ?? "Lock desktop view")
    fitAllButton.toolTip = locked && !isChronological ? "Return to locked view" : "Fit all windows"
    fitAllButton.setAccessibilityLabel(fitAllButton.toolTip ?? "Fit all windows")
  }

  private func scheduleDesktopPagesPersistence() {
    guard !cameraMaintenancePending else { return }
    NSObject.cancelPreviousPerformRequests(
      withTarget: self,
      selector: #selector(persistDesktopPages),
      object: nil
    )
    perform(#selector(persistDesktopPages), with: nil, afterDelay: 0.3)
  }

  private func currentWindowSnapshots() -> [WindowPlacementSnapshot] {
    nodes.map { node in
      WindowPlacementSnapshot(
        windowID: node.id,
        bundleIdentifier: node.bundleIdentifier,
        title: node.displayTitle,
        center: CGPoint(x: node.worldFrame.midX, y: node.worldFrame.midY),
        size: node.worldFrame.size
      )
    }
  }

  private func synchronizeManifestedPlacements() {
    guard !isChronological else { return }
    let snapshots = currentWindowSnapshots()
    let placements = desktopPages.selectedAppPlacements
    guard !snapshots.isEmpty, !placements.isEmpty else { return }
    let before = desktopPages
    for placement in placements {
      let windows = snapshots.filter { $0.bundleIdentifier == placement.bundleIdentifier }
      guard !windows.isEmpty else { continue }
      let applicationName = nodes.first(where: {
        $0.bundleIdentifier == placement.bundleIdentifier
      })?.applicationName ?? placement.applicationName
      desktopPages.updateSelectedAppPlacement(
        bundleIdentifier: placement.bundleIdentifier,
        applicationName: applicationName,
        home: placement.home,
        windows: windows
      )
    }
    if desktopPages != before { scheduleDesktopPagesPersistence() }
  }

  private func manifestMovedItems(originalFrames: [String: CGRect], primaryTarget: NavigationTarget?) {
    guard !isChronological else { return }
    // Save closed homes before refreshing placeholders as part of window persistence.
    for placeholder in appPlaceholders
    where originalFrames[NavigationTarget.placeholder(placeholder).key] != nil {
      desktopPages.moveSelectedAppPlacement(
        bundleIdentifier: placeholder.bundleIdentifier,
        to: CGPoint(x: placeholder.worldFrame.midX, y: placeholder.worldFrame.midY)
      )
    }
    let windowFrames = Dictionary(uniqueKeysWithValues: nodes.compactMap { node in
      originalFrames[NavigationTarget.window(node).key].map { (node.id, $0) }
    })
    let primaryWindowID: CGWindowID? = if case .window(let node) = primaryTarget { node.id } else { nil }
    manifestMovedWindows(Set(windowFrames.keys), primaryWindowID: primaryWindowID, originalFrames: windowFrames)
  }

  private func manifestMovedWindows(
    _ movedWindowIDs: Set<CGWindowID>,
    primaryWindowID: CGWindowID?,
    originalFrames: [CGWindowID: CGRect]
  ) {
    let movedNodes = nodes.filter { movedWindowIDs.contains($0.id) }
    for bundleIdentifier in Set(movedNodes.map(\.bundleIdentifier)) {
      let applicationNodes = nodes.filter { $0.bundleIdentifier == bundleIdentifier }
      guard !applicationNodes.isEmpty else { continue }
      let existing = desktopPages.selectedAppPlacement(for: bundleIdentifier)
      let movedAllApplicationWindows = Set(applicationNodes.map(\.id)).isSubset(
        of: movedWindowIDs
      )
      let preferredNode = primaryWindowID.flatMap { id in
        applicationNodes.first(where: { $0.id == id })
      } ?? movedNodes.first(where: { $0.bundleIdentifier == bundleIdentifier })
        ?? applicationNodes.min(by: { $0.id < $1.id })!

      let home: CGPoint
      if let existing, movedAllApplicationWindows,
        let original = originalFrames[preferredNode.id]
      {
        home = CGPoint(
          x: existing.home.x + preferredNode.worldFrame.midX - original.midX,
          y: existing.home.y + preferredNode.worldFrame.midY - original.midY
        )
      } else if let existing {
        home = existing.home
      } else {
        home = CGPoint(x: preferredNode.worldFrame.midX, y: preferredNode.worldFrame.midY)
      }

      desktopPages.updateSelectedAppPlacement(
        bundleIdentifier: bundleIdentifier,
        applicationName: preferredNode.applicationName,
        home: home,
        windows: applicationNodes.map(windowSnapshot)
      )
    }
    persistDesktopPages()
    refreshPlaceholders()
  }

  private func windowSnapshot(_ node: WindowNode) -> WindowPlacementSnapshot {
    WindowPlacementSnapshot(
      windowID: node.id,
      bundleIdentifier: node.bundleIdentifier,
      title: node.displayTitle,
      center: CGPoint(x: node.worldFrame.midX, y: node.worldFrame.midY),
      size: node.worldFrame.size
    )
  }

  private func applySelectedDesktopLayout(around anchor: CGPoint) {
    refreshPlaceholders()
    let centers = desktopPages.selectedWindowCenters(for: currentWindowSnapshots())
    var occupied = reservedAppFrames()

    for node in nodes {
      guard let center = centers[node.id] else { continue }
      node.worldFrame = CGRect(
        x: center.x - node.worldFrame.width / 2,
        y: center.y - node.worldFrame.height / 2,
        width: node.worldFrame.width,
        height: node.worldFrame.height
      )
      occupied.append(node.worldFrame)
    }
    for node in nodes where centers[node.id] == nil {
      node.worldFrame = CanvasMath.nearestAvailableFrame(
        size: node.worldFrame.size,
        centeredAt: anchor,
        avoiding: occupied
      )
      occupied.append(node.worldFrame)
    }
    needsDisplay = true
    schedulePreviewToolTipUpdate()
  }

  private func refreshPlaceholders() {
    if isChronological { refreshRecentPlaceholders(); return }
    for placeholder in appPlaceholders
    where groupSelectionIDs.contains(NavigationTarget.placeholder(placeholder).key) {
      if let node = nodes.first(where: { $0.bundleIdentifier == placeholder.bundleIdentifier }) {
        groupSelectionIDs.insert(NavigationTarget.window(node).key)
      }
    }
    let previousFrames = itemFrames
    let liveBundles = Set(nodes.map(\.bundleIdentifier))
    appPlaceholders = desktopPages.selectedAppPlacements.compactMap { placement in
      guard !liveBundles.contains(placement.bundleIdentifier) else { return nil }
      let applicationURL = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: placement.bundleIdentifier
      ).flatMap {
        FileManager.default.fileExists(atPath: $0.path) ? $0 : nil
      }
      let icon = appIconsByBundle[placement.bundleIdentifier] ?? applicationURL.map {
        NSWorkspace.shared.icon(forFile: $0.path)
      } ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: "Application")
      if let icon { appIconsByBundle[placement.bundleIdentifier] = icon }
      let applicationName = applicationURL?.deletingPathExtension().lastPathComponent
        ?? placement.applicationName
      let size = fullviewPreviewSize
      return AppPlaceholder(
        bundleIdentifier: placement.bundleIdentifier,
        applicationName: applicationName,
        worldFrame: CGRect(
          x: placement.home.x - size.width / 2,
          y: placement.home.y - size.height / 2,
          width: size.width,
          height: size.height
        ),
        icon: icon,
        isAvailable: applicationURL != nil,
        isLaunching: launchingPlaceholderBundles.contains(placement.bundleIdentifier),
        errorMessage: placeholderErrors[placement.bundleIdentifier]
      )
    }.sorted { $0.applicationName.localizedStandardCompare($1.applicationName) == .orderedAscending }
    if case .items(_, _, let frames, _, true) = interaction {
      for index in appPlaceholders.indices {
        let key = NavigationTarget.placeholder(appPlaceholders[index]).key
        if frames[key] != nil, let frame = previousFrames[key] {
          appPlaceholders[index].worldFrame = frame
        }
      }
    }
    groupSelectionIDs.formIntersection(itemFrames.keys)
    if interaction == nil { fitGroupSelectionToItems() }
    needsDisplay = true
  }

  private func selectPlaceholder(_ bundleIdentifier: String) {
    selectedWindowID = nil
    selectedPlaceholderBundleIdentifier = bundleIdentifier
  }

  private func activatePlaceholder(_ bundleIdentifier: String) {
    if bundleIdentifier == Self.allAppsID { openCatalog(); return }
    guard let placeholder = appPlaceholders.first(where: {
      $0.bundleIdentifier == bundleIdentifier
    }) else { return }
    selectPlaceholder(bundleIdentifier)
    guard !launchingPlaceholderBundles.contains(bundleIdentifier) else { return }
    guard placeholder.isAvailable else {
      placeholderErrors[bundleIdentifier] = "App unavailable"
      refreshPlaceholders()
      return
    }
    placeholderErrors[bundleIdentifier] = nil
    launchingPlaceholderBundles.insert(bundleIdentifier)
    refreshPlaceholders()
    delegate?.canvasView(
      self,
      didRequestLaunch: bundleIdentifier,
      applicationName: placeholder.applicationName,
      at: CGPoint(x: placeholder.worldFrame.midX, y: placeholder.worldFrame.midY)
    )
  }

  func showLaunchError(for bundleIdentifier: String, message: String) {
    launchingPlaceholderBundles.remove(bundleIdentifier)
    placeholderErrors[bundleIdentifier] = message
    refreshPlaceholders()
  }

  func completePlaceholderLaunch(for bundleIdentifier: String) {
    launchingPlaceholderBundles.remove(bundleIdentifier)
    placeholderErrors[bundleIdentifier] = nil
    refreshPlaceholders()
  }

  var hasCanvasSelection: Bool {
    if let selectedWindowID, nodes.contains(where: { $0.id == selectedWindowID }) { return true }
    if let selectedPlaceholderBundleIdentifier {
      return appPlaceholders.contains {
        $0.bundleIdentifier == selectedPlaceholderBundleIdentifier
      }
    }
    return false
  }

  var hasManifestedAppPlacements: Bool {
    desktopPages.hasSelectedAppPlacements
  }

  func restoredWindowCenters(
    for windows: [WindowPlacementSnapshot]
  ) -> [CGWindowID: CGPoint] {
    desktopPages.selectedWindowCenters(for: windows)
  }

  func manifestedAppHome(for bundleIdentifier: String) -> CGPoint? {
    desktopPages.selectedAppPlacement(for: bundleIdentifier)?.home
  }

  func reservedAppFrames(excluding bundleIdentifier: String? = nil) -> [CGRect] {
    return desktopPages.selectedAppPlacements.compactMap { placement in
      guard placement.bundleIdentifier != bundleIdentifier else { return nil }
      let size = fullviewPreviewSize
      return CGRect(
        x: placement.home.x - size.width / 2,
        y: placement.home.y - size.height / 2,
        width: size.width,
        height: size.height
      )
    }
  }

  private var fullviewPreviewSize: CGSize {
    let size = bounds.size
    return size.width > 0 && size.height > 0
      ? size : CGSize(width: 960, height: 600)
  }

  private var canvasItemFrames: [CGRect] {
    displayedNodes.map(\.worldFrame) + appPlaceholders.map(\.worldFrame)
  }

  @objc private func persistDesktopPages() {
    if let data = try? JSONEncoder().encode(chronologicalCamera) {
      UserDefaults.standard.set(data, forKey: "chronologicalCamera")
    }
    guard let data = try? JSONEncoder().encode(desktopPages) else { return }
    UserDefaults.standard.set(data, forKey: Self.desktopPagesPreferenceKey)
  }

  private static func loadDesktopPages(from defaults: UserDefaults) -> DesktopPages {
    guard let data = defaults.data(forKey: desktopPagesPreferenceKey),
      let decoded = try? JSONDecoder().decode(DesktopPages.self, from: data)
    else { return DesktopPages() }
    return DesktopPages(pages: decoded.pages, selectedID: decoded.selectedID)
  }

  func revealCatalogWindowForFocus(_ id: CGWindowID) {
    guard showingAllApps else { return }
    _ = closeCatalog()
    selectedWindowID = id
    if let target = selectedNavigationTarget { camera = CanvasMath.cameraCentered(on: target.worldFrame, preserving: camera) }
  }

  func focusSelectedWindow() {
    if let selectedWindowID,
      let node = nodes.first(where: { $0.id == selectedWindowID })
    {
      delegate?.canvasView(self, didRequestFocus: node)
    } else if let selectedPlaceholderBundleIdentifier {
      activatePlaceholder(selectedPlaceholderBundleIdentifier)
    }
  }

  private func quitSelectedApplication() {
    guard let selectedWindowID,
      let node = nodes.first(where: { $0.id == selectedWindowID })
    else { return }
    delegate?.canvasView(self, didRequestQuit: node)
  }

  private func rememberCamera(_ value: CameraState) {
    if isChronological {
      if !showingAllApps, focusTransitionWindowID == nil { chronologicalCamera = value }
    } else { desktopPages.updateSelectedCamera(value) }
  }

  @objc private func changeMode(_ sender: NSSegmentedControl) {
    setChronological(sender.selectedSegment == 1)
  }

  func setChronological(_ enabled: Bool) {
    guard enabled != isChronological else { return }
    onModeChange?()
    dismissSearch()
    if showingAllApps { _ = closeCatalog() }
    finishDesktopTransition()
    cancelLayoutAnimation()
    clearGroupSelection()
    interaction = nil
    if enabled {
      synchronizeManifestedPlacements()
      persistDesktopPages()
      freeFrames = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.worldFrame) })
      isChronological = true
      camera = chronologicalCamera
      arrangeRecentWindows(reorder: true, selectFirst: true)
    } else {
      chronologicalCamera = camera
      isChronological = false
      for node in nodes { if let frame = freeFrames[node.id] { node.worldFrame = frame } }
      camera = desktopPages.selectedPage.camera ?? CameraState()
      refreshPlaceholders()
    }
    modeControl.selectedSegment = enabled ? 1 : 0
    UserDefaults.standard.set(enabled, forKey: "chronologicalMode")
    updateModeControls()
    displayedLockState = nil
    updateLockViewButton()
    persistDesktopPages()
    needsDisplay = true
  }

  private func updateModeControls() {
    desktopTabsScrollView.isHidden = isChronological
    desktopTitleField.isHidden = isChronological
    addDesktopButton.isHidden = isChronological
    lockViewButton.isHidden = isChronological
  }

  func cancelLayoutAnimation() {
    stopKeyboardZoom(completingTap: false)
    stopKeyboardTapZoom()
    stopNativeCameraTravel()
    animationDisplayLink?.invalidate()
    animationDisplayLink = nil
    cameraAnimation = nil
    isPresentingFinalAnimationFrame = false
    endFocusTransition()
  }

  func restoreChronologicalCamera() {
    let saved = chronologicalCamera
    cancelLayoutAnimation()
    camera = saved
  }

  func prepareChronologicalOverview() {
    guard isChronological else { return }
    if showingAllApps { _ = closeCatalog() }
    restoreChronologicalCamera()
    arrangeRecentWindows(reorder: true, selectFirst: true)
    updateModeControls()
  }

  private func arrangeRecentWindows(reorder: Bool, selectFirst: Bool = false) {
    let previousIndex = selectedWindowID.flatMap { recentWindows.visible.firstIndex(of: $0) } ?? 0
    let selectedBefore = selectedNavigationTarget
    let oldCenter = selectedBefore?.center
    let oldCamera = camera
    recentWindows.reconcile(nodes.map(\.id), reorder: reorder)
    let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    let ordered = recentWindows.visible.compactMap { byID[$0] }
    let frames = RecentWindowOrder.frames(sizes: ordered.map { $0.worldFrame.size })
    for (node, frame) in zip(ordered, frames) { node.worldFrame = frame }
    refreshRecentPlaceholders()
    guard !showingAllApps else { return }
    cancelLayoutAnimation()
    if selectFirst {
      selectedWindowID = ordered.first?.id
      if ordered.isEmpty { selectPlaceholder(Self.allAppsID) }
    } else if selectedWindowID != nil && byID[selectedWindowID!] == nil {
      selectedWindowID = ordered.isEmpty ? nil : ordered[min(previousIndex, ordered.count - 1)].id
      if ordered.isEmpty { selectPlaceholder(Self.allAppsID) }
    }
    if let selected = selectedNavigationTarget {
      if selectFirst || selected.key != selectedBefore?.key {
        camera = CanvasMath.cameraCentered(on: selected.worldFrame, preserving: oldCamera)
      } else if let oldCenter {
        camera = CameraState(center: CGPoint(x: oldCamera.center.x + selected.center.x - oldCenter.x,
          y: oldCamera.center.y + selected.center.y - oldCenter.y), zoom: oldCamera.zoom)
      }
    }
    fitGroupSelectionToItems()
    needsDisplay = true
  }

  func stepRecent(by offset: Int, wrapping: Bool, windowsOnly: Bool = false) {
    let targets = windowsOnly ? navigationTargets.filter {
      if case .window = $0 { return true }; return false
    } : navigationTargets
    guard !targets.isEmpty else { return }
    let index = targets.firstIndex { $0.key == selectedNavigationTarget?.key }
    var next = (index ?? (offset > 0 ? -1 : targets.count)) + offset
    if wrapping { next = (next % targets.count + targets.count) % targets.count }
    guard targets.indices.contains(next) else { return }
    selectNavigationTarget(targets[next])
    centerCamera(on: targets[next])
  }

  private func refreshRecentPlaceholders() {
    let query = isSearching ? searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    let matchingApps = catalog.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    let entries: [(String, String, URL?)] = showingAllApps
      ? matchingApps.map { ($0.id, $0.name, Optional($0.url)) }
      : [(Self.allAppsID, "All apps", nil)]
    let size = showingAllApps ? CGSize(width: 640, height: 180) : CGSize(width: 800, height: 260)
    let start = showingAllApps ? CGFloat(0) : (nodes.map { $0.worldFrame.minY }.min() ?? 100) - 100
    appPlaceholders = entries.enumerated().map { index, entry in
      let icon = appIconsByBundle[entry.0] ?? entry.2.map { NSWorkspace.shared.icon(forFile: $0.path) }
        ?? NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: entry.1)
      if let icon { appIconsByBundle[entry.0] = icon }
      return AppPlaceholder(bundleIdentifier: entry.0, applicationName: entry.1,
        worldFrame: CGRect(x: -size.width / 2, y: start - size.height - CGFloat(index) * (size.height + 100),
          width: size.width, height: size.height), icon: icon,
        isAvailable: true, isLaunching: launchingPlaceholderBundles.contains(entry.0),
        errorMessage: placeholderErrors[entry.0])
    }
    needsDisplay = true
  }

  private func openCatalog() {
    guard !showingAllApps else { return }
    cancelLayoutAnimation()
    clearGroupSelection()
    catalogReturnCamera = camera
    catalogReturnSelection = selectedWindowID
    showingAllApps = true
    selectedWindowID = nil
    selectedPlaceholderBundleIdentifier = nil
    catalogBackButton.isHidden = false
    refreshRecentPlaceholders()
    camera = CameraState(center: CGPoint(x: 0, y: -90), zoom: 0.7)
    if let first = catalog.first { selectPlaceholder(first.id) }
    catalogTask?.cancel()
    catalogTask = Task { [weak self] in
      let apps = await Task.detached(priority: .userInitiated) { InstalledApp.catalog() }.value
      guard let self, !Task.isCancelled else { return }
      self.catalog = apps
      guard self.showingAllApps else { return }
      self.refreshRecentPlaceholders()
      if let first = apps.first { self.selectPlaceholder(first.id) }
    }
  }

  @objc private func backFromCatalog(_ sender: NSButton) { _ = closeCatalog() }

  @discardableResult func closeCatalog() -> Bool {
    guard showingAllApps else { return false }
    dismissSearch()
    cancelLayoutAnimation()
    catalogTask?.cancel()
    showingAllApps = false
    catalogBackButton.isHidden = true
    selectedWindowID = catalogReturnSelection.flatMap { id in nodes.contains { $0.id == id } ? id : nil }
    refreshRecentPlaceholders()
    if selectedWindowID == nil { selectPlaceholder(Self.allAppsID) }
    camera = catalogReturnCamera ?? chronologicalCamera
    return true
  }

  @objc private func closeSelectedWindow(_ sender: Any?) {
    guard let id = selectedWindowID, let node = nodes.first(where: { $0.id == id }),
      let element = node.accessibilityElement else { statusMessage = "Window close unavailable"; return }
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXCloseButtonAttribute as CFString, &value) == .success,
      let value, CFGetTypeID(value) == AXUIElementGetTypeID(),
      AXUIElementPerformAction(value as! AXUIElement, kAXPressAction as CFString) == .success
    else { statusMessage = "Window close unavailable"; return }
  }

  @objc private func quitFromMenu(_ sender: Any?) { quitSelectedApplication() }

  @objc private func showSettings(_ sender: NSButton) {
    if dismissSettings() { return }

    guard let host = settingsWorkspace else { return }
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

    updateNavigatorPanel()
    let panel = CanvasSettingsPanel(modeControl: modeControl, palette: paletteView, groups: [
      ("Appearance", [
        ("Expand previews", "rectangle.expand.vertical", expandLandscapePreviewsMenuItem),
        ("Grid dots", "circle.grid.3x3", gridMenuItem),
        ("Center guide", "plus", centerGuideMenuItem),
        ("Light closed cards", "rectangle", lightClosedCardsMenuItem),
      ]),
      ("Navigation", [
        ("Use ⌘Tab for OpenPlane", "command", commandTabShortcutMenuItem),
      ]),
      ("Privacy", [
        ("Private browser previews", "eye", privateBrowserPreviewsMenuItem),
      ]),
      ("Advanced", [
        ("Debug information", "waveform.path", debugInformationMenuItem),
      ]),
    ])
    panel.onClose = { [weak self] in self?.dismissSettings() }
    host.showSettings(panel)
  }

  private static func settingsImage() -> NSImage? {
    guard let symbol = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings") else { return nil }
    // Bake the light color into the icon so AppKit appearance cannot turn it black.
    let image = NSImage(size: CGSize(width: 22, height: 22), flipped: false) { rect in
      symbol.draw(in: rect)
      NSColor.white.withAlphaComponent(0.9).setFill()
      rect.fill(using: .sourceIn)
      return true
    }
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
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    guard let button = swatches.first(where: { $0.identifier?.rawValue == selectedID }) else { return }
    NSColor(cgColor: selectedBorderColor)?.setStroke()
    let ring = NSBezierPath(roundedRect: button.frame.insetBy(dx: -3, dy: -3), xRadius: 13, yRadius: 13)
    ring.lineWidth = 2
    ring.stroke()
  }

}

// The canvas keeps its world coordinates; only its viewport gives space to settings.
@MainActor
final class CanvasWorkspaceView: NSView {
  let canvas: CanvasView
  private var settings: NSView?
  var isSettingsVisible: Bool { settings != nil }

  init(canvas: CanvasView) {
    self.canvas = canvas
    super.init(frame: canvas.frame)
    wantsLayer = true
    layer?.masksToBounds = true
    addSubview(canvas)
  }

  required init?(coder: NSCoder) { nil }

  private var transitionGeneration = 0
  private var isAnimatingSettings = false
  private var panelWidth: CGFloat { min(440, bounds.width * 0.45) }

  func showSettings(_ panel: NSView) {
    subviews.filter { $0 !== canvas }.forEach { $0.removeFromSuperview() }
    settings = panel
    panel.frame = CGRect(x: bounds.width, y: 0, width: panelWidth, height: bounds.height)
    addSubview(panel)
    animateSettings(panel, opening: true)
  }

  func hideSettings() {
    guard let panel = settings else { return }
    settings = nil
    animateSettings(panel, opening: false)
    window?.makeFirstResponder(canvas)
  }

  private func animateSettings(_ panel: NSView, opening: Bool) {
    transitionGeneration += 1
    let generation = transitionGeneration
    isAnimatingSettings = true
    let width = opening ? panelWidth : 0
    NSAnimationContext.runAnimationGroup { context in
      context.duration = window == nil || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.18
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      canvas.animator().frame = CGRect(x: 0, y: 0, width: bounds.width - width, height: bounds.height)
      panel.animator().frame = CGRect(x: bounds.width - width, y: 0, width: panelWidth, height: bounds.height)
    } completionHandler: { [weak self, weak panel] in
      guard let self else { return }
      if !opening, let panel, self.settings !== panel { panel.removeFromSuperview() }
      guard self.transitionGeneration == generation else { return }
      self.isAnimatingSettings = false
      self.needsLayout = true
    }
  }

  override func layout() {
    super.layout()
    guard !isAnimatingSettings else { return }
    let width: CGFloat = settings == nil ? 0 : panelWidth
    canvas.frame = CGRect(x: 0, y: 0, width: bounds.width - width, height: bounds.height)
    settings?.frame = CGRect(x: bounds.width - width, y: 0, width: width, height: bounds.height)
  }

}

@MainActor
private final class SettingsDocumentView: NSView {
  override var isFlipped: Bool { true }
}

@MainActor
final class SettingsSwitch: NSButton {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setButtonType(.switch)
    title = ""
    isBordered = false
  }

  required init?(coder: NSCoder) { nil }

  override var state: NSControl.StateValue {
    didSet { needsDisplay = true }
  }

  override func draw(_ dirtyRect: NSRect) {
    let track = CGRect(x: bounds.midX - 19, y: bounds.midY - 11, width: 38, height: 22)
    let active = state == .on
    (active ? NSColor.systemBlue : NSColor(white: 0.76, alpha: 1))
      .withAlphaComponent(isEnabled ? (isHighlighted ? 0.75 : 1) : 0.4).setFill()
    NSBezierPath(roundedRect: track, xRadius: 11, yRadius: 11).fill()
    let thumb = CGRect(x: active ? track.maxX - 20 : track.minX + 2,
      y: track.minY + 2, width: 18, height: 18)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: thumb).fill()
  }
}

@MainActor
private final class SettingsToggleRow: NSView {
  private let item: NSMenuItem
  private let control = SettingsSwitch()
  private let rowButton = NSButton()

  init(title: String, symbol: String, item: NSMenuItem, width: CGFloat) {
    self.item = item
    super.init(frame: CGRect(x: 24, y: 0, width: width, height: 52))
    rowButton.frame = bounds
    rowButton.autoresizingMask = [.width, .height]
    rowButton.title = ""
    rowButton.isBordered = false
    rowButton.setAccessibilityElement(false)
    rowButton.target = self
    rowButton.action = #selector(toggle(_:))
    addSubview(rowButton)
    let icon = NSImageView(frame: CGRect(x: 2, y: 13, width: 26, height: 26))
    icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    icon.imageScaling = .scaleProportionallyUpOrDown
    icon.contentTintColor = NSColor(srgbRed: 0.43, green: 0.48, blue: 0.55, alpha: 1)
    addSubview(icon)
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 16, weight: .medium)
    label.textColor = NSColor(srgbRed: 0.12, green: 0.17, blue: 0.23, alpha: 1)
    label.frame = CGRect(x: 42, y: 16, width: width - 88, height: 22)
    label.autoresizingMask = [.width]
    addSubview(label)
    control.frame = CGRect(x: width - 38, y: 12, width: 38, height: 28)
    control.autoresizingMask = [.minXMargin]
    control.state = item.state
    control.target = self
    control.action = #selector(toggle(_:))
    control.identifier = NSUserInterfaceItemIdentifier(title)
    control.setAccessibilityLabel(title)
    if title == "Expand previews" {
      let explanation = "Enlarge smaller previews proportionally to the largest window dimensions. Actual windows stay unchanged."
      toolTip = explanation
      control.toolTip = explanation
      rowButton.toolTip = explanation
    }
    addSubview(control)
  }

  required init?(coder: NSCoder) { nil }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard let hit = super.hitTest(point) else { return nil }
    return hit === control ? control : rowButton
  }

  @objc private func toggle(_ sender: Any?) {
    if let action = item.action { NSApp.sendAction(action, to: item.target, from: item) }
    control.state = item.state
  }

}

@MainActor
private final class CanvasSettingsPanel: NSView {
  var onClose: (() -> Void)?
  private let scroll = NSScrollView()
  private let closeButton = NSButton()
  override var isFlipped: Bool { true }

  init(modeControl: NSView, palette: NSView, groups: [(String, [(String, String, NSMenuItem)])]) {
    super.init(frame: CGRect(x: 0, y: 0, width: 440, height: 900))
    appearance = NSAppearance(named: .aqua)
    wantsLayer = true
    layer?.backgroundColor = NSColor.white.cgColor
    let title = NSTextField(labelWithString: "Settings")
    title.font = .systemFont(ofSize: 28, weight: .semibold)
    title.textColor = NSColor(srgbRed: 0.12, green: 0.17, blue: 0.23, alpha: 1)
    title.frame = CGRect(x: 24, y: 38, width: 270, height: 34)
    addSubview(title)
    closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close settings")
    closeButton.isBordered = false
    closeButton.contentTintColor = .secondaryLabelColor
    closeButton.target = self
    closeButton.action = #selector(close(_:))
    closeButton.setAccessibilityLabel("Close settings")
    addSubview(closeButton)
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    let document = SettingsDocumentView(frame: .zero)
    var y: CGFloat = 10
    func section(_ text: String) {
      let label = NSTextField(labelWithString: text)
      label.font = .systemFont(ofSize: 14, weight: .medium)
      label.textColor = .secondaryLabelColor
      label.frame = CGRect(x: 24, y: y, width: 310, height: 20)
      document.addSubview(label)
      y += 30
    }
    section("View mode")
    modeControl.frame = CGRect(x: 24, y: y, width: 350, height: 30)
    document.addSubview(modeControl)
    y += 52
    section("Background")
    palette.frame.origin = CGPoint(x: 4, y: y)
    document.addSubview(palette)
    y += palette.frame.height + 12
    for (heading, rows) in groups {
      section(heading)
      for (title, symbol, item) in rows {
        let row = SettingsToggleRow(title: title, symbol: symbol, item: item, width: 392)
        row.frame.origin.y = y
        document.addSubview(row)
        y += row.frame.height
      }
      y += 20
    }
    document.frame = CGRect(x: 0, y: 0, width: 440, height: y + 12)
    scroll.documentView = document
    addSubview(scroll)
  }

  required init?(coder: NSCoder) { nil }

  override func resetCursorRects() {
    super.resetCursorRects()
    addCursorRect(bounds, cursor: .arrow)
  }

  override func layout() {
    super.layout()
    closeButton.frame = CGRect(x: bounds.width - 54, y: 38, width: 30, height: 30)
    scroll.frame = CGRect(x: 0, y: 92, width: bounds.width, height: max(0, bounds.height - 92))
    if let document = scroll.documentView {
      document.frame.size.width = scroll.contentSize.width
      for row in document.subviews where row is SettingsToggleRow {
        row.frame.size.width = max(0, document.bounds.width - 48)
      }
    }
  }

  @objc private func close(_ sender: NSButton) { onClose?() }
}
