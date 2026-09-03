@preconcurrency import AppKit
@preconcurrency import ApplicationServices
@preconcurrency import ScreenCaptureKit

struct CameraState: Codable, Equatable {
  var center: CGPoint = .zero
  var zoom: CGFloat = 1
}

struct DesktopPage: Codable, Equatable, Identifiable {
  let id: UUID
  var title: String
  var camera: CameraState?
  var lockedCamera: CameraState?

  init(
    id: UUID = UUID(),
    title: String,
    camera: CameraState? = nil,
    lockedCamera: CameraState? = nil
  ) {
    self.id = id
    self.title = title
    self.camera = camera
    self.lockedCamera = lockedCamera
  }

  var displayTitle: String {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return title.isEmpty ? "Untitled Desktop" : title
  }
}

struct DesktopPages: Codable, Equatable {
  private(set) var pages: [DesktopPage]
  private(set) var selectedID: UUID

  init(pages: [DesktopPage] = [DesktopPage(title: "Desktop 1")], selectedID: UUID? = nil) {
    let pages = pages.isEmpty ? [DesktopPage(title: "Desktop 1")] : pages
    self.pages = pages
    self.selectedID = selectedID.flatMap { id in pages.contains { $0.id == id } ? id : nil }
      ?? pages[0].id
  }

  var selectedPage: DesktopPage { pages[selectedIndex] }
  var isSelectedPageLocked: Bool { selectedPage.lockedCamera != nil }

  mutating func renameSelectedPage(_ title: String) {
    pages[selectedIndex].title = title
  }

  mutating func updateSelectedCamera(_ camera: CameraState) {
    pages[selectedIndex].camera = camera
  }

  @discardableResult
  mutating func toggleSelectedPageLock(at camera: CameraState) -> Bool {
    if pages[selectedIndex].lockedCamera == nil {
      pages[selectedIndex].lockedCamera = camera
    } else {
      pages[selectedIndex].lockedCamera = nil
    }
    return pages[selectedIndex].lockedCamera != nil
  }

  mutating func addPage(camera: CameraState) -> DesktopPage {
    let usedTitles = Set(pages.map(\.title))
    var number = pages.count + 1
    while usedTitles.contains("Desktop \(number)") { number += 1 }
    let page = DesktopPage(title: "Desktop \(number)", camera: camera)
    pages.append(page)
    selectedID = page.id
    return page
  }

  mutating func select(_ id: UUID) -> CameraState? {
    guard pages.contains(where: { $0.id == id }) else { return nil }
    selectedID = id
    return selectedPage.camera
  }

  private var selectedIndex: Int {
    pages.firstIndex(where: { $0.id == selectedID }) ?? 0
  }
}

enum OpenPlanePreferences {
  static let useCommandTabShortcut = "useCommandTabShortcut"
}

enum ShortcutMatcher {
  static func isCommandTab(keyCode: Int64, flags: CGEventFlags) -> Bool {
    guard keyCode == 48 else { return false }
    let modifiers = flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])
    return modifiers == [.maskCommand] || modifiers == [.maskCommand, .maskShift]
  }
}

struct AppNavigationHistory {
  private(set) var current: String?
  private var backStack: [String] = []
  private var forwardStack: [String] = []

  mutating func opened(_ bundleIdentifier: String) {
    guard bundleIdentifier != current else { return }
    if let current { backStack.append(current) }
    current = bundleIdentifier
    forwardStack.removeAll()
  }

  func canGoBack(available: Set<String>) -> Bool {
    backDestination(available: available) != nil
  }

  func backDestination(available: Set<String>) -> String? {
    backStack.last(where: available.contains)
  }

  func canGoForward(available: Set<String>) -> Bool {
    forwardDestination(available: available) != nil
  }

  func forwardDestination(available: Set<String>) -> String? {
    forwardStack.last(where: available.contains)
  }

  mutating func goBack(available: Set<String>) -> String? {
    while let bundleIdentifier = backStack.popLast() {
      guard available.contains(bundleIdentifier) else { continue }
      if let current { forwardStack.append(current) }
      current = bundleIdentifier
      return bundleIdentifier
    }
    return nil
  }

  mutating func goForward(available: Set<String>) -> String? {
    while let bundleIdentifier = forwardStack.popLast() {
      guard available.contains(bundleIdentifier) else { continue }
      if let current { backStack.append(current) }
      current = bundleIdentifier
      return bundleIdentifier
    }
    return nil
  }
}

enum CanvasDirection {
  case left
  case right
  case up
  case down
}

enum CanvasSearch {
  static func matches(query: String, applicationName: String, title: String) -> Bool {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return true }
    return applicationName.localizedCaseInsensitiveContains(query)
      || title.localizedCaseInsensitiveContains(query)
  }

  static func status(query: String, resultCount: Int, selectedIndex: Int?) -> String {
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return "ESC to cancel search"
    }
    guard resultCount > 0 else { return "0 results" }
    guard let selectedIndex else {
      return resultCount == 1 ? "1 result" : "\(resultCount) results"
    }
    return "\(selectedIndex + 1) of \(resultCount) \(resultCount == 1 ? "result" : "results")"
  }
}

struct CanvasBackground: Equatable {
  let id: String
  let name: String
  let rgb: UInt32

  var color: NSColor {
    NSColor(
      srgbRed: CGFloat((rgb >> 16) & 0xff) / 255,
      green: CGFloat((rgb >> 8) & 0xff) / 255,
      blue: CGFloat(rgb & 0xff) / 255,
      alpha: 1
    )
  }
}

enum CanvasPalette {
  static let defaultID = "slate"
  static let backgrounds = [
    CanvasBackground(id: "graphite", name: "Graphite", rgb: 0x3B3D43),
    CanvasBackground(id: "slate", name: "Slate", rgb: 0x566473),
    CanvasBackground(id: "blue", name: "Blue", rgb: 0x4F78A4),
    CanvasBackground(id: "indigo", name: "Indigo", rgb: 0x6468A3),
    CanvasBackground(id: "violet", name: "Violet", rgb: 0x8065A0),
    CanvasBackground(id: "rose", name: "Rose", rgb: 0xA06380),
    CanvasBackground(id: "red", name: "Red", rgb: 0xAA6265),
    CanvasBackground(id: "orange", name: "Orange", rgb: 0xB07850),
    CanvasBackground(id: "amber", name: "Amber", rgb: 0x9B8845),
    CanvasBackground(id: "green", name: "Green", rgb: 0x608A69),
    CanvasBackground(id: "teal", name: "Teal", rgb: 0x4F8C7F),
    CanvasBackground(id: "cyan", name: "Cyan", rgb: 0x4F8797),
  ]

  static func background(for id: String?) -> CanvasBackground {
    backgrounds.first(where: { $0.id == id })
      ?? backgrounds.first(where: { $0.id == defaultID })!
  }
}

enum CanvasMode: Equatable {
  case overview
  case focusing(CGWindowID)
  case working(CGWindowID)
}

struct CanvasStateMachine {
  private(set) var mode: CanvasMode = .overview

  mutating func beginFocus(on id: CGWindowID) -> Bool {
    guard mode == .overview else { return false }
    mode = .focusing(id)
    return true
  }

  mutating func completeFocus(on id: CGWindowID) {
    guard mode == .focusing(id) else { return }
    mode = .working(id)
  }

  mutating func returnToOverview() {
    mode = .overview
  }
}

struct PendingLaunch {
  let processID: pid_t
  let bundleIdentifier: String
  let anchor: CGPoint
  let knownWindowIDs: Set<CGWindowID>
  let deadline: Date
}

struct WindowInventoryChange: Equatable {
  let added: Set<CGWindowID>
  let retained: Set<CGWindowID>
  let removed: Set<CGWindowID>
}

struct WindowInventoryTracker {
  private var missingScanCount: [CGWindowID: Int] = [:]

  mutating func change(
    previous: Set<CGWindowID>,
    current: Set<CGWindowID>,
    existing: Set<CGWindowID> = [],
    removalThreshold: Int = 3
  ) -> WindowInventoryChange {
    missingScanCount = missingScanCount.filter { previous.contains($0.key) }
    for id in current.union(existing) { missingScanCount[id] = nil }
    let absent = previous.subtracting(current).subtracting(existing)
    for id in absent { missingScanCount[id, default: 0] += 1 }

    let removed = Set(
      absent.filter {
        missingScanCount[$0, default: 0] >= removalThreshold
      })
    for id in removed { missingScanCount[id] = nil }

    return WindowInventoryChange(
      added: current.subtracting(previous),
      retained: current.intersection(previous),
      removed: removed
    )
  }
}

struct PreviewRefreshScheduler {
  private var nextIndex = 0

  mutating func nextIDs(
    from visibleIDs: [CGWindowID],
    selectedID: CGWindowID?,
    limit: Int
  ) -> [CGWindowID] {
    guard limit > 0, !visibleIDs.isEmpty else { return [] }

    let selected = selectedID.flatMap { visibleIDs.contains($0) ? $0 : nil }
    let backgroundIDs = visibleIDs.filter { $0 != selected }
    var result = selected.map { [$0] } ?? []
    let count = min(limit - result.count, backgroundIDs.count)
    guard count > 0 else { return result }

    let start = nextIndex % backgroundIDs.count
    result.append(contentsOf: (0..<count).map { backgroundIDs[(start + $0) % backgroundIDs.count] })
    nextIndex = (start + count) % backgroundIDs.count
    return result
  }
}

enum PreviewState: Equatable {
  case loading
  case current
  case failed

  func toolTip(hasPreview: Bool) -> String {
    switch self {
    case .loading:
      "Checking for the latest preview…"
    case .current:
      "Latest preview captured successfully."
    case .failed where hasPreview:
      "Preview update failed — showing the last saved image."
    case .failed:
      "Preview unavailable."
    }
  }
}

actor PreviewCache {
  private let directoryURL: URL

  init(directoryURL: URL? = nil) {
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.yalpani.openplane.poc"
    self.directoryURL =
      directoryURL
      ?? caches.appendingPathComponent(bundleIdentifier, isDirectory: true)
        .appendingPathComponent("WindowPreviews", isDirectory: true)
  }

  func loadData(windowID: CGWindowID, bundleIdentifier: String) -> Data? {
    try? Data(contentsOf: fileURL(windowID: windowID, bundleIdentifier: bundleIdentifier))
  }

  func store(image: CGImage, windowID: CGWindowID, bundleIdentifier: String) {
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let jpeg = bitmap.representation(
      using: .jpeg,
      properties: [.compressionFactor: 0.78]
    ) else { return }

    try? FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )
    try? jpeg.write(
      to: fileURL(windowID: windowID, bundleIdentifier: bundleIdentifier),
      options: .atomic
    )
  }

  private func fileURL(windowID: CGWindowID, bundleIdentifier: String) -> URL {
    directoryURL.appendingPathComponent("\(bundleIdentifier)-\(windowID).jpg")
  }
}

@MainActor
final class WindowNode {
  let id: CGWindowID
  var processID: pid_t
  var bundleIdentifier: String
  var applicationName: String
  var title: String
  var sourceFrame: CGRect
  var worldFrame: CGRect
  var icon: NSImage?
  var preview: NSImage?
  var previewState: PreviewState
  var lastPreviewCacheWrite: Date?
  var captureWindow: SCWindow
  var accessibilityElement: AXUIElement?

  init(discovered: DiscoveredWindow, worldFrame: CGRect, cachedPreview: NSImage? = nil) {
    id = discovered.id
    processID = discovered.processID
    bundleIdentifier = discovered.bundleIdentifier
    applicationName = discovered.applicationName
    title = discovered.title
    sourceFrame = discovered.frame
    self.worldFrame = worldFrame
    icon = discovered.icon
    preview = cachedPreview
    previewState = .loading
    captureWindow = discovered.captureWindow
    accessibilityElement = discovered.accessibilityElement
  }

  func update(from discovered: DiscoveredWindow) {
    processID = discovered.processID
    bundleIdentifier = discovered.bundleIdentifier
    applicationName = discovered.applicationName
    title = discovered.title
    sourceFrame = discovered.frame
    icon = discovered.icon
    captureWindow = discovered.captureWindow
    accessibilityElement = discovered.accessibilityElement
  }
}

enum CanvasMath {
  static let minimumZoom: CGFloat = 0.06
  static let maximumZoom: CGFloat = 1.25

  static func selectionAnimationPhases(progress: CGFloat) -> (title: CGFloat, border: CGFloat) {
    let progress = min(1, max(0, progress))
    return (
      title: min(1, progress / 0.55),
      border: max(0, (progress - 0.55) / 0.45)
    )
  }

  static func selectionTitleLift(progress: CGFloat, isPrimary: Bool) -> CGFloat {
    min(1, max(0, progress)) * (isPrimary ? 6 : 4)
  }

  static func sameApplicationSelectionMetrics(
    primaryProgress: CGFloat
  ) -> (borderWidth: CGFloat, titleLift: CGFloat) {
    let progress = min(1, max(0, primaryProgress))
    return (borderWidth: 2 + 2 * progress, titleLift: 4 + 2 * progress)
  }

  static func easedTransition(_ progress: CGFloat) -> CGFloat {
    let progress = min(1, max(0, progress))
    return progress * progress * (3 - 2 * progress)
  }

  static func selectionHandoffPhase(progress: CGFloat, incoming: Bool) -> CGFloat {
    let local = incoming ? (progress - 0.5) * 2 : progress * 2
    return easedTransition(local)
  }

  static func appIconScale(at zoom: CGFloat) -> CGFloat {
    let progress = (zoom - minimumZoom) / (0.18 - minimumZoom)
    return 0.5 + 0.5 * easedTransition(progress)
  }

  static func gridSpacing(at zoom: CGFloat) -> CGFloat {
    52 * zoom
  }

  static func gridDotSize(at zoom: CGFloat) -> CGFloat {
    max(1, 2 * zoom)
  }

  static func gridOpacity(at zoom: CGFloat) -> CGFloat {
    guard zoom >= 0.15 else { return 0 }
    return 0.5 + 0.5 * easedTransition((zoom - 0.25) / 0.15)
  }

  static func titleVisibility(at zoom: CGFloat, availableWidth: CGFloat) -> CGFloat {
    let zoomProgress = easedTransition((zoom - minimumZoom) / (0.14 - minimumZoom))
    let widthProgress = easedTransition((availableWidth - 32) / 40)
    let visibility = min(zoomProgress, widthProgress)
    return visibility < 0.5 ? 0 : visibility
  }

  static func clampedZoom(_ value: CGFloat) -> CGFloat {
    min(maximumZoom, max(minimumZoom, value))
  }

  static func focusBackdropOpacity(progress: CGFloat) -> CGFloat {
    1 - easedTransition(progress)
  }

  static func focusOverlayOpacity(progress: CGFloat) -> CGFloat {
    1 - easedTransition((progress - 0.5) * 2)
  }

  static func previewPixelLength(
    displaySize: CGSize,
    backingScale: CGFloat
  ) -> Int {
    let requiredLength = ceil(
      max(displaySize.width, displaySize.height) * max(1, backingScale)
    )
    return Int(min(3_840, max(1_200, requiredLength)))
  }

  static func clampedOrigin(_ origin: CGPoint, size: CGSize, in bounds: CGRect) -> CGPoint {
    CGPoint(
      x: min(max(bounds.minX, bounds.maxX - size.width), max(bounds.minX, origin.x)),
      y: min(max(bounds.minY, bounds.maxY - size.height), max(bounds.minY, origin.y))
    )
  }

  static func worldToView(_ point: CGPoint, camera: CameraState, bounds: CGRect) -> CGPoint {
    CGPoint(
      x: bounds.midX + (point.x - camera.center.x) * camera.zoom,
      y: bounds.midY + (point.y - camera.center.y) * camera.zoom
    )
  }

  static func viewToWorld(_ point: CGPoint, camera: CameraState, bounds: CGRect) -> CGPoint {
    CGPoint(
      x: camera.center.x + (point.x - bounds.midX) / camera.zoom,
      y: camera.center.y + (point.y - bounds.midY) / camera.zoom
    )
  }

  static func interpolatedCamera(
    from start: CameraState,
    to target: CameraState,
    tracking worldPoint: CGPoint?,
    progress: CGFloat,
    in bounds: CGRect
  ) -> CameraState {
    let progress = min(1, max(0, progress))
    let zoom = start.zoom + (target.zoom - start.zoom) * progress
    guard let worldPoint else {
      return CameraState(
        center: CGPoint(
          x: start.center.x + (target.center.x - start.center.x) * progress,
          y: start.center.y + (target.center.y - start.center.y) * progress
        ),
        zoom: zoom
      )
    }

    let startViewPoint = worldToView(worldPoint, camera: start, bounds: bounds)
    let targetViewPoint = worldToView(worldPoint, camera: target, bounds: bounds)
    let viewPoint = CGPoint(
      x: startViewPoint.x + (targetViewPoint.x - startViewPoint.x) * progress,
      y: startViewPoint.y + (targetViewPoint.y - startViewPoint.y) * progress
    )
    return CameraState(
      center: CGPoint(
        x: worldPoint.x - (viewPoint.x - bounds.midX) / zoom,
        y: worldPoint.y - (viewPoint.y - bounds.midY) / zoom
      ),
      zoom: zoom
    )
  }

  static func viewRect(for worldRect: CGRect, camera: CameraState, bounds: CGRect) -> CGRect {
    let origin = worldToView(worldRect.origin, camera: camera, bounds: bounds)
    return CGRect(
      origin: origin,
      size: CGSize(width: worldRect.width * camera.zoom, height: worldRect.height * camera.zoom)
    )
  }

  static func selectionRect(from start: CGPoint, to end: CGPoint) -> CGRect {
    CGRect(
      x: min(start.x, end.x),
      y: min(start.y, end.y),
      width: abs(end.x - start.x),
      height: abs(end.y - start.y)
    )
  }

  static func windowIDs(
    intersecting selectionRect: CGRect,
    frames: [CGWindowID: CGRect],
    camera: CameraState,
    bounds: CGRect
  ) -> Set<CGWindowID> {
    Set(frames.compactMap { id, frame in
      viewRect(for: frame, camera: camera, bounds: bounds).intersects(selectionRect) ? id : nil
    })
  }

  static func worldTranslation(forViewTranslation translation: CGPoint, zoom: CGFloat) -> CGPoint {
    CGPoint(x: translation.x / zoom, y: translation.y / zoom)
  }

  static func groupSelectionBounds(for rects: [CGRect]) -> CGRect? {
    guard let first = rects.first else { return nil }
    let union = rects.dropFirst().reduce(first) { $0.union($1) }
    return CGRect(
      x: union.minX - 22,
      y: union.minY - 10,
      width: union.width + 34,
      height: union.height + 38
    )
  }

  static func zoomedCamera(
    _ camera: CameraState,
    to proposedZoom: CGFloat,
    around viewPoint: CGPoint,
    in bounds: CGRect
  ) -> CameraState {
    let worldPoint = viewToWorld(viewPoint, camera: camera, bounds: bounds)
    let zoom = clampedZoom(proposedZoom)
    return CameraState(
      center: CGPoint(
        x: worldPoint.x - (viewPoint.x - bounds.midX) / zoom,
        y: worldPoint.y - (viewPoint.y - bounds.midY) / zoom
      ),
      zoom: zoom
    )
  }

  static func directionalNeighbor(
    from origin: CGPoint,
    candidates: [(id: CGWindowID, center: CGPoint)],
    direction: CanvasDirection
  ) -> CGWindowID? {
    candidates.compactMap { candidate -> (id: CGWindowID, score: CGFloat)? in
      let dx = candidate.center.x - origin.x
      let dy = candidate.center.y - origin.y
      let primary: CGFloat
      let cross: CGFloat
      switch direction {
      case .left:
        primary = -dx
        cross = abs(dy)
      case .right:
        primary = dx
        cross = abs(dy)
      case .up:
        primary = dy
        cross = abs(dx)
      case .down:
        primary = -dy
        cross = abs(dx)
      }
      guard primary > 1 else { return nil }
      return (candidate.id, primary + cross * 2)
    }
    .min {
      $0.score == $1.score ? $0.id < $1.id : $0.score < $1.score
    }?.id
  }

  static func gridFrames(for sizes: [CGSize], gap: CGFloat = 240) -> [CGRect] {
    guard !sizes.isEmpty else { return [] }
    let columns = Int(ceil(sqrt(Double(sizes.count))))
    let cellWidth = sizes.map(\.width).max()! + gap
    let cellHeight = sizes.map(\.height).max()! + gap

    var frames = sizes.enumerated().map { index, size in
      let column = index % columns
      let row = index / columns
      return CGRect(
        x: CGFloat(column) * cellWidth + (cellWidth - gap - size.width) / 2,
        y: -CGFloat(row) * cellHeight + (cellHeight - gap - size.height) / 2,
        width: size.width,
        height: size.height
      )
    }

    let union = frames.dropFirst().reduce(frames[0]) { $0.union($1) }
    let offset = CGPoint(x: -union.midX, y: -union.midY)
    frames = frames.map { $0.offsetBy(dx: offset.x, dy: offset.y) }
    return frames
  }

  static func previewSizes(for sizes: [CGSize], expand: Bool) -> [CGSize] {
    guard expand, !sizes.isEmpty else { return sizes }
    let available = CGSize(
      width: sizes.map(\.width).max()!,
      height: sizes.map(\.height).max()!
    )
    return sizes.map { size in
      let scale = min(available.width / size.width, available.height / size.height)
      return CGSize(width: size.width * scale, height: size.height * scale)
    }
  }

  static func fitCamera(frames: [CGRect], in bounds: CGRect, padding: CGFloat = 96) -> CameraState {
    guard !frames.isEmpty else { return CameraState() }
    let union = frames.dropFirst().reduce(frames[0]) { $0.union($1) }
    let availableWidth = max(1, bounds.width - padding * 2)
    let availableHeight = max(1, bounds.height - padding * 2)
    let zoom = clampedZoom(min(1, availableWidth / union.width, availableHeight / union.height))
    return CameraState(center: CGPoint(x: union.midX, y: union.midY), zoom: zoom)
  }

  static func cascadedFrame(
    size: CGSize,
    centeredAt anchor: CGPoint,
    avoiding frames: [CGRect],
    offset: CGFloat = 80
  ) -> CGRect {
    var candidate = CGRect(
      x: anchor.x - size.width / 2,
      y: anchor.y - size.height / 2,
      width: size.width,
      height: size.height
    )
    for _ in 0..<20 {
      guard frames.contains(where: { $0.intersects(candidate) }) else { return candidate }
      candidate = candidate.offsetBy(dx: offset, dy: -offset)
    }
    return candidate
  }
}
