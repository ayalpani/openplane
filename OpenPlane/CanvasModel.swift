@preconcurrency import AppKit
import Carbon
@preconcurrency import ApplicationServices
@preconcurrency import ScreenCaptureKit

struct CameraState: Codable, Equatable {
  var center: CGPoint = .zero
  var zoom: CGFloat = 1
}

struct PersistedWindowPosition: Codable, Equatable {
  var windowID: CGWindowID
  var bundleIdentifier: String
  var title: String
  var center: CGPoint
}

struct WindowPlacementSnapshot: Equatable {
  var windowID: CGWindowID
  var bundleIdentifier: String
  var title: String
  var center: CGPoint
  var size: CGSize
}

struct WindowSlot: Codable, Equatable, Identifiable {
  let id: UUID
  var offset: CGPoint
  var size: CGSize
  var lastWindowID: CGWindowID?
  var lastSessionID: UUID?
  var titleHint: String

  init(
    id: UUID = UUID(),
    offset: CGPoint,
    size: CGSize,
    lastWindowID: CGWindowID?,
    lastSessionID: UUID? = nil,
    titleHint: String
  ) {
    self.id = id
    self.offset = offset
    self.size = size
    self.lastWindowID = lastWindowID
    self.lastSessionID = lastSessionID
    self.titleHint = WindowIdentity.normalizedTitle(titleHint)
  }
}

struct AppPlacement: Codable, Equatable, Identifiable {
  var bundleIdentifier: String
  var applicationName: String
  var home: CGPoint
  var lastKnownSize: CGSize
  var windowSlots: [WindowSlot]

  var id: String { bundleIdentifier }
}

enum AppPlacementPersistence {
  private static let sessionID = UUID()

  static func migrated(from positions: [PersistedWindowPosition]) -> [AppPlacement] {
    Dictionary(grouping: positions, by: \.bundleIdentifier).keys.sorted().compactMap {
      bundleIdentifier in
      guard let windows = Dictionary(grouping: positions, by: \.bundleIdentifier)[
        bundleIdentifier
      ]?.sorted(by: { $0.windowID < $1.windowID }), let first = windows.first
      else { return nil }
      return AppPlacement(
        bundleIdentifier: bundleIdentifier,
        applicationName: bundleIdentifier.split(separator: ".").last.map(String.init)
          ?? bundleIdentifier,
        home: first.center,
        lastKnownSize: CGSize(width: 960, height: 600),
        windowSlots: windows.map {
          WindowSlot(
            offset: CGPoint(x: $0.center.x - first.center.x, y: $0.center.y - first.center.y),
            size: .zero,
            lastWindowID: $0.windowID,
            lastSessionID: nil,
            titleHint: $0.title
          )
        }
      )
    }
  }

  static func restoredCenters(
    for current: [WindowPlacementSnapshot],
    from placements: [AppPlacement]
  ) -> [CGWindowID: CGPoint] {
    var centers: [CGWindowID: CGPoint] = [:]
    let placementsByBundle = Dictionary(
      uniqueKeysWithValues: placements.map { ($0.bundleIdentifier, $0) }
    )
    for (bundleIdentifier, windows) in Dictionary(grouping: current, by: \.bundleIdentifier) {
      guard let placement = placementsByBundle[bundleIdentifier] else { continue }
      let matches = matches(current: windows, stored: placement.windowSlots)
      for (currentIndex, storedIndex) in matches {
        let offset = placement.windowSlots[storedIndex].offset
        centers[windows[currentIndex].windowID] = CGPoint(
          x: placement.home.x + offset.x,
          y: placement.home.y + offset.y
        )
      }
      if matches.isEmpty, let first = windows.min(by: { $0.windowID < $1.windowID }) {
        centers[first.windowID] = placement.home
      }
    }
    return centers
  }

  static func updating(
    _ placement: AppPlacement,
    applicationName: String,
    home: CGPoint,
    windows: [WindowPlacementSnapshot]
  ) -> AppPlacement {
    var result = placement
    result.applicationName = applicationName
    result.home = home
    if let primary = windows.min(by: { $0.windowID < $1.windowID }) {
      result.lastKnownSize = primary.size
    }

    var matches = matches(current: windows, stored: result.windowSlots)
    var availableStoredIndexes = Set(result.windowSlots.indices).subtracting(matches.values)
    let proximityCandidates = windows.indices
      .filter { matches[$0] == nil }
      .flatMap { currentIndex in
        availableStoredIndexes.map { storedIndex in
          let storedCenter = CGPoint(
            x: home.x + result.windowSlots[storedIndex].offset.x,
            y: home.y + result.windowSlots[storedIndex].offset.y
          )
          let dx = windows[currentIndex].center.x - storedCenter.x
          let dy = windows[currentIndex].center.y - storedCenter.y
          return (currentIndex: currentIndex, storedIndex: storedIndex, distance: dx * dx + dy * dy)
        }
      }
      .sorted {
        if $0.distance != $1.distance { return $0.distance < $1.distance }
        if $0.currentIndex != $1.currentIndex { return $0.currentIndex < $1.currentIndex }
        return $0.storedIndex < $1.storedIndex
      }
    for candidate in proximityCandidates
    where matches[candidate.currentIndex] == nil
      && availableStoredIndexes.contains(candidate.storedIndex)
    {
      matches[candidate.currentIndex] = candidate.storedIndex
      availableStoredIndexes.remove(candidate.storedIndex)
    }
    for (currentIndex, storedIndex) in matches {
      let window = windows[currentIndex]
      result.windowSlots[storedIndex].offset = CGPoint(
        x: window.center.x - home.x,
        y: window.center.y - home.y
      )
      result.windowSlots[storedIndex].size = window.size
      result.windowSlots[storedIndex].lastWindowID = window.windowID
      result.windowSlots[storedIndex].lastSessionID = sessionID
      result.windowSlots[storedIndex].titleHint = WindowIdentity.normalizedTitle(window.title)
    }
    for currentIndex in windows.indices where matches[currentIndex] == nil {
      let window = windows[currentIndex]
      result.windowSlots.append(
        WindowSlot(
          offset: CGPoint(x: window.center.x - home.x, y: window.center.y - home.y),
          size: window.size,
          lastWindowID: window.windowID,
          lastSessionID: sessionID,
          titleHint: window.title
        )
      )
    }
    return result
  }

  private static func matches(
    current: [WindowPlacementSnapshot],
    stored: [WindowSlot]
  ) -> [Int: Int] {
    var result: [Int: Int] = [:]
    var availableStoredIndexes = Set(stored.indices)

    func assign(_ currentIndex: Int, _ storedIndex: Int) {
      result[currentIndex] = storedIndex
      availableStoredIndexes.remove(storedIndex)
    }

    for currentIndex in current.indices {
      if let storedIndex = availableStoredIndexes.sorted().first(where: {
        stored[$0].lastSessionID == sessionID
          && stored[$0].lastWindowID == current[currentIndex].windowID
      }) {
        assign(currentIndex, storedIndex)
      }
    }

    for currentIndex in current.indices where result[currentIndex] == nil {
      let candidates = availableStoredIndexes.compactMap { storedIndex -> (Int, Int)? in
        WindowIdentity.titleMatchScore(
          source: stored[storedIndex].titleHint,
          candidate: current[currentIndex].title
        ).map { (storedIndex, $0) }
      }.sorted { lhs, rhs in
        lhs.1 == rhs.1 ? lhs.0 < rhs.0 : lhs.1 < rhs.1
      }
      if let candidate = candidates.first,
        candidates.count == 1 || candidate.1 < candidates[1].1
      {
        assign(currentIndex, candidate.0)
      }
    }

    let unmatchedCurrent = current.indices.filter { result[$0] == nil }
    if unmatchedCurrent.count == 1, availableStoredIndexes.count == 1,
      let currentIndex = unmatchedCurrent.first,
      let storedIndex = availableStoredIndexes.first
    {
      assign(currentIndex, storedIndex)
    }
    return result
  }
}

enum WindowPositionPersistence {
  static func restoredCenters(
    for current: [PersistedWindowPosition],
    from stored: [PersistedWindowPosition]
  ) -> [CGWindowID: CGPoint] {
    Dictionary(
      uniqueKeysWithValues: matches(current: current, stored: stored).map { currentIndex, storedIndex in
        (current[currentIndex].windowID, stored[storedIndex].center)
      }
    )
  }

  static func merging(
    _ current: [PersistedWindowPosition],
    into stored: [PersistedWindowPosition]
  ) -> [PersistedWindowPosition] {
    let matches = matches(current: current, stored: stored)
    var result = stored
    for (currentIndex, storedIndex) in matches {
      result[storedIndex] = current[currentIndex]
    }
    for currentIndex in current.indices where matches[currentIndex] == nil {
      result.append(current[currentIndex])
    }
    return result
  }

  private static func matches(
    current: [PersistedWindowPosition],
    stored: [PersistedWindowPosition]
  ) -> [Int: Int] {
    var result: [Int: Int] = [:]
    var availableStoredIndexes = Set(stored.indices)

    func assign(_ currentIndex: Int, _ storedIndex: Int) {
      result[currentIndex] = storedIndex
      availableStoredIndexes.remove(storedIndex)
    }

    for currentIndex in current.indices {
      let item = current[currentIndex]
      if let storedIndex = availableStoredIndexes.sorted().first(where: {
        stored[$0].windowID == item.windowID
          && stored[$0].bundleIdentifier == item.bundleIdentifier
      }) {
        assign(currentIndex, storedIndex)
      }
    }

    for currentIndex in current.indices where result[currentIndex] == nil {
      let item = current[currentIndex]
      let candidate = availableStoredIndexes.compactMap { storedIndex -> (Int, Int)? in
        guard stored[storedIndex].bundleIdentifier == item.bundleIdentifier,
          let score = WindowIdentity.titleMatchScore(
            source: stored[storedIndex].title,
            candidate: item.title
          )
        else { return nil }
        return (storedIndex, score)
      }.min { lhs, rhs in
        lhs.1 == rhs.1 ? lhs.0 < rhs.0 : lhs.1 < rhs.1
      }
      if let candidate { assign(currentIndex, candidate.0) }
    }

    let unmatchedBundles = Set(
      current.indices.lazy
        .filter { result[$0] == nil }
        .map { current[$0].bundleIdentifier }
    )
    for bundleIdentifier in unmatchedBundles {
      let currentIndexes = current.indices.filter {
        result[$0] == nil && current[$0].bundleIdentifier == bundleIdentifier
      }
      let storedIndexes = availableStoredIndexes.filter {
        stored[$0].bundleIdentifier == bundleIdentifier
      }
      if currentIndexes.count == 1, storedIndexes.count == 1,
        let currentIndex = currentIndexes.first,
        let storedIndex = storedIndexes.first
      {
        assign(currentIndex, storedIndex)
      }
    }

    return result
  }
}

struct DesktopPage: Codable, Equatable, Identifiable {
  let id: UUID
  var title: String
  var camera: CameraState?
  var lockedCamera: CameraState?
  var windowPositions: [PersistedWindowPosition]
  var appPlacements: [AppPlacement]

  init(
    id: UUID = UUID(),
    title: String,
    camera: CameraState? = nil,
    lockedCamera: CameraState? = nil,
    windowPositions: [PersistedWindowPosition] = [],
    appPlacements: [AppPlacement] = []
  ) {
    self.id = id
    self.title = title
    self.camera = camera
    self.lockedCamera = lockedCamera
    self.windowPositions = windowPositions
    self.appPlacements = appPlacements
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case camera
    case lockedCamera
    case windowPositions
    case appPlacements
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(UUID.self, forKey: .id)
    title = try values.decode(String.self, forKey: .title)
    camera = try values.decodeIfPresent(CameraState.self, forKey: .camera)
    lockedCamera = try values.decodeIfPresent(CameraState.self, forKey: .lockedCamera)
    windowPositions = try values.decodeIfPresent(
      [PersistedWindowPosition].self,
      forKey: .windowPositions
    ) ?? []
    if values.contains(.appPlacements) {
      appPlacements = try values.decodeIfPresent(
        [AppPlacement].self,
        forKey: .appPlacements
      ) ?? []
    } else {
      appPlacements = AppPlacementPersistence.migrated(from: windowPositions)
      windowPositions.removeAll()
    }
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
  var selectedAppPlacements: [AppPlacement] { selectedPage.appPlacements }
  var hasSelectedAppPlacements: Bool { !selectedPage.appPlacements.isEmpty }

  mutating func renameSelectedPage(_ title: String) {
    pages[selectedIndex].title = title
  }

  mutating func updateSelectedCamera(_ camera: CameraState) {
    pages[selectedIndex].camera = camera
  }

  mutating func updateSelectedWindowPositions(_ positions: [PersistedWindowPosition]) {
    pages[selectedIndex].windowPositions = WindowPositionPersistence.merging(
      positions,
      into: pages[selectedIndex].windowPositions
    )
  }

  func selectedWindowCenters(
    for positions: [PersistedWindowPosition]
  ) -> [CGWindowID: CGPoint] {
    guard selectedPage.appPlacements.isEmpty else {
      return AppPlacementPersistence.restoredCenters(
        for: positions.map {
          WindowPlacementSnapshot(
            windowID: $0.windowID,
            bundleIdentifier: $0.bundleIdentifier,
            title: $0.title,
            center: $0.center,
            size: .zero
          )
        },
        from: selectedPage.appPlacements
      )
    }
    return WindowPositionPersistence.restoredCenters(
      for: positions,
      from: selectedPage.windowPositions
    )
  }

  func selectedWindowCenters(
    for windows: [WindowPlacementSnapshot]
  ) -> [CGWindowID: CGPoint] {
    AppPlacementPersistence.restoredCenters(
      for: windows,
      from: selectedPage.appPlacements
    )
  }

  func selectedAppPlacement(for bundleIdentifier: String) -> AppPlacement? {
    selectedPage.appPlacements.first { $0.bundleIdentifier == bundleIdentifier }
  }

  mutating func updateSelectedAppPlacement(
    bundleIdentifier: String,
    applicationName: String,
    home: CGPoint,
    windows: [WindowPlacementSnapshot]
  ) {
    pages[selectedIndex].windowPositions.removeAll()
    if let index = pages[selectedIndex].appPlacements.firstIndex(where: {
      $0.bundleIdentifier == bundleIdentifier
    }) {
      pages[selectedIndex].appPlacements[index] = AppPlacementPersistence.updating(
        pages[selectedIndex].appPlacements[index],
        applicationName: applicationName,
        home: home,
        windows: windows
      )
    } else {
      let initial = AppPlacement(
        bundleIdentifier: bundleIdentifier,
        applicationName: applicationName,
        home: home,
        lastKnownSize: windows.first?.size ?? CGSize(width: 960, height: 600),
        windowSlots: []
      )
      pages[selectedIndex].appPlacements.append(
        AppPlacementPersistence.updating(
          initial,
          applicationName: applicationName,
          home: home,
          windows: windows
        )
      )
    }
  }

  mutating func moveSelectedAppPlacement(
    bundleIdentifier: String,
    to home: CGPoint
  ) {
    guard let index = pages[selectedIndex].appPlacements.firstIndex(where: {
      $0.bundleIdentifier == bundleIdentifier
    }) else { return }
    pages[selectedIndex].appPlacements[index].home = home
  }

  mutating func forgetSelectedAppPlacement(bundleIdentifier: String) {
    pages[selectedIndex].windowPositions.removeAll()
    pages[selectedIndex].appPlacements.removeAll {
      $0.bundleIdentifier == bundleIdentifier
    }
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
  static let transitionSpeedKey = "transitionAnimationSpeed"
  static var transitionSpeed: Double {
    get {
      let value = UserDefaults.standard.object(forKey: transitionSpeedKey) as? Double ?? 2
      return value.isFinite ? min(4, max(0.5, value)) : 2
    }
    set { UserDefaults.standard.set(newValue.isFinite ? min(4, max(0.5, newValue)) : 2, forKey: transitionSpeedKey) }
  }
  static func transitionDuration(_ original: TimeInterval) -> TimeInterval {
    original / transitionSpeed
  }

  static let useCommandTabShortcut = "useCommandTabShortcut"
  static let showPrivateBrowserPreviews = "showPrivateBrowserPreviews"
}

enum ShortcutMatcher {
  static func isOverviewSwipe(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
    deltaY > 0 && deltaY > abs(deltaX)
  }

  static func isCommandTab(keyCode: Int64, flags: CGEventFlags) -> Bool {
    guard keyCode == 48 else { return false }
    let modifiers = flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])
    return modifiers == [.maskCommand] || modifiers == [.maskCommand, .maskShift]
  }

  static func isPlaneBackspace(keyCode: UInt16, isRepeat: Bool) -> Bool {
    keyCode == 51 && !isRepeat
  }
}

enum CanvasDirection {
  case left
  case right
  case up
  case down
}

enum SelectionResizeHandle: CaseIterable {
  case topLeft
  case top
  case topRight
  case right
  case bottomRight
  case bottom
  case bottomLeft
  case left

  var movesLeftEdge: Bool {
    self == .topLeft || self == .bottomLeft || self == .left
  }

  var movesRightEdge: Bool {
    self == .topRight || self == .bottomRight || self == .right
  }

  var movesTopEdge: Bool {
    self == .topLeft || self == .top || self == .topRight
  }

  var movesBottomEdge: Bool {
    self == .bottomLeft || self == .bottom || self == .bottomRight
  }
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

enum WorkspaceActivationPolicy {
  static func shouldFollow(
    bundleIdentifier: String?,
    requestedLaunches: Set<String>
  ) -> Bool {
    requestedLaunches.isEmpty || bundleIdentifier.map(requestedLaunches.contains) == true
  }
}

struct WindowInventoryChange: Equatable {
  let added: Set<CGWindowID>
  let retained: Set<CGWindowID>
  let removed: Set<CGWindowID>
}

struct PendingQuitWindowSuppression {
  let knownWindowIDs: Set<CGWindowID>
  let deadline: Date
  private(set) var sawAdditionalWindow = false

  func allows(_ windowID: CGWindowID) -> Bool {
    knownWindowIDs.contains(windowID)
  }

  mutating func observe(currentWindowIDs: Set<CGWindowID>, now: Date) -> Bool {
    let hasAdditionalWindow = !currentWindowIDs.subtracting(knownWindowIDs).isEmpty
    if hasAdditionalWindow { sawAdditionalWindow = true }
    if currentWindowIDs.isEmpty || (sawAdditionalWindow && !hasAdditionalWindow) {
      return false
    }
    return sawAdditionalWindow || now < deadline
  }
}

struct WindowInventoryTracker {
  private var missingScanCount: [CGWindowID: Int] = [:]

  mutating func change(
    previous: Set<CGWindowID>,
    current: Set<CGWindowID>,
    existing: Set<CGWindowID> = [],
    removalThreshold: Int = 3,
    requestedCloseIDs: Set<CGWindowID> = []
  ) -> WindowInventoryChange {
    missingScanCount = missingScanCount.filter { previous.contains($0.key) }
    for id in current.union(existing) { missingScanCount[id] = nil }
    let absent = previous.subtracting(current).subtracting(existing)
    for id in absent { missingScanCount[id, default: 0] += 1 }

    let removed = Set(
      absent.filter {
        requestedCloseIDs.contains($0) || missingScanCount[$0, default: 0] >= removalThreshold
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
  case redacted

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
    case .redacted:
      "Browser preview hidden because non-private mode cannot be verified."
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
    // Remove browser images left by earlier versions without loading their contents.
    for file in (try? FileManager.default.contentsOfDirectory(at: self.directoryURL,
      includingPropertiesForKeys: nil)) ?? []
    where BrowserPrivacy.isBrowser(bundleIdentifier: file.lastPathComponent) {
      try? FileManager.default.removeItem(at: file)
    }
  }

  func loadData(windowID: CGWindowID, bundleIdentifier: String) -> Data? {
    guard !BrowserPrivacy.isBrowser(bundleIdentifier: bundleIdentifier) else {
      remove(windowID: windowID, bundleIdentifier: bundleIdentifier)
      return nil
    }
    return try? Data(contentsOf: fileURL(windowID: windowID, bundleIdentifier: bundleIdentifier))
  }

  func store(image: CGImage, windowID: CGWindowID, bundleIdentifier: String) {
    // Browser images are session-only, including explicitly permitted private previews.
    guard !BrowserPrivacy.isBrowser(bundleIdentifier: bundleIdentifier) else {
      remove(windowID: windowID, bundleIdentifier: bundleIdentifier)
      return
    }
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

  func remove(windowID: CGWindowID, bundleIdentifier: String) {
    try? FileManager.default.removeItem(
      at: fileURL(windowID: windowID, bundleIdentifier: bundleIdentifier)
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
  var isPrivateBrowsing: Bool
  var sourceFrame: CGRect
  var worldFrame: CGRect
  var icon: NSImage?
  var preview: NSImage?
  var previewState: PreviewState
  var lastPreviewCacheWrite: Date?
  var captureWindow: SCWindow?
  var accessibilityElement: AXUIElement?

  init(discovered: DiscoveredWindow, worldFrame: CGRect, cachedPreview: NSImage? = nil) {
    id = discovered.id
    processID = discovered.processID
    bundleIdentifier = discovered.bundleIdentifier
    applicationName = discovered.applicationName
    title = discovered.title
    isPrivateBrowsing = discovered.isPrivateBrowsing
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
    isPrivateBrowsing = discovered.isPrivateBrowsing
    sourceFrame = discovered.frame
    icon = discovered.icon
    captureWindow = discovered.captureWindow
    accessibilityElement = discovered.accessibilityElement
  }

  var displayTitle: String {
    previewState == .redacted ? "Browser preview hidden" : title
  }
}

enum CanvasMath {
  static let applicationMinimumZoom: CGFloat = 0.5
  static let itemGap: CGFloat = 240
  static func applicationTileMetrics(zoom: CGFloat) -> (icon: CGFloat, caption: CGFloat, size: CGSize) {
    let icon = max(40, 56 * zoom)
    let caption = min(1, max(0, (zoom - 0.55) / 0.3))
    return (icon, caption, CGSize(width: max(icon + 24, 128 * zoom),
      height: icon + 24 + 26 * caption))
  }

  static func applicationGridFrames(count: Int, viewport: CGSize, zoom: CGFloat = 1, topInset: CGFloat = 88) -> [CGRect] {
    let zoom = max(0.001, zoom)
    let size = applicationTileMetrics(zoom: zoom).size
    let gap: CGFloat = 16
    let columns = max(1, Int((viewport.width - 48 + gap) / (size.width + gap)))
    let columnWidth = max(size.width + gap, (viewport.width - 48 + gap) / CGFloat(columns))
    return (0..<count).map { index in
      CGRect(x: (-viewport.width / 2 + 24 + CGFloat(index % columns) * columnWidth) / zoom,
        y: (viewport.height / 2 - topInset - size.height - CGFloat(index / columns) * (size.height + gap)) / zoom,
        width: size.width / zoom, height: size.height / zoom)
    }
  }

  static func allAppsCardSize(at zoom: CGFloat) -> CGSize {
    CGSize(width: max(640, 160 / max(minimumZoom, zoom)),
      height: max(180, 48 / max(minimumZoom, zoom)))
  }

  static let minimumZoom: CGFloat = 0.06
  static let maximumZoom: CGFloat = 1.25
  static let appIconSize: CGFloat = 36
  static let groupSelectionPadding: CGFloat = 12

  static func previewHeaderFont(selected: Bool) -> NSFont {
    .systemFont(ofSize: 12, weight: selected ? .bold : .medium)
  }

  static func previewHeaderLayout(
    for rect: CGRect, zoom: CGFloat, titleLift: CGFloat
  ) -> (icon: CGRect, title: CGRect, titleVisibility: CGFloat) {
    let badgeSize = appIconSize * appIconScale(at: zoom)
    let titleX = rect.minX + badgeSize / 2 + 8
    let title = CGRect(
      x: titleX, y: rect.maxY + 2 + titleLift,
      width: max(0, rect.maxX - titleX), height: 16
    )
    return (
      CGRect(
        x: rect.minX - badgeSize / 2, y: rect.maxY - badgeSize / 2,
        width: badgeSize, height: badgeSize),
      title,
      titleVisibility(at: zoom, availableWidth: title.width)
    )
  }

  static func previewVisualBounds(
    for rect: CGRect, zoom: CGFloat, titleLift: CGFloat, borderOutset: CGFloat,
    hasIcon: Bool = true, hasTitle: Bool = true
  ) -> CGRect {
    let header = previewHeaderLayout(for: rect, zoom: zoom, titleLift: titleLift)
    // Use solid geometry; soft shadows/glow have no definite outside edge.
    var result = rect.insetBy(dx: -borderOutset, dy: -borderOutset)
    if hasIcon { result = result.union(header.icon) }
    if hasTitle && header.titleVisibility > 0 { result = result.union(header.title) }
    return result
  }

  struct DesktopTitleNudgeLayout: Equatable {
    let titleTopInset: CGFloat
    let titleBoxHeight: CGFloat
    let depth: CGFloat
  }

  static func desktopTitleNudgeLayout(
    safeAreaTop: CGFloat,
    titleBoxHeight: CGFloat = 44,
    padding: CGFloat = 8
  ) -> DesktopTitleNudgeLayout {
    let safeAreaTop = max(0, safeAreaTop)
    let titleBoxHeight = max(0, titleBoxHeight)
    let padding = max(0, padding)
    return DesktopTitleNudgeLayout(
      titleTopInset: safeAreaTop + padding,
      titleBoxHeight: titleBoxHeight,
      depth: safeAreaTop + padding + titleBoxHeight + padding
    )
  }

  static func desktopTitleNudgeWidth(textWidth: CGFloat, availableWidth: CGFloat) -> CGFloat {
    min(max(0, availableWidth), max(236, textWidth + 56))
  }

  static func selectionAnimationPhases(
    progress: CGFloat
  ) -> (title: CGFloat, border: CGFloat) {
    let progress = min(1, max(0, progress))
    return (
      title: min(1, progress / 0.55),
      border: progress
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

  static func placeholderStatusFontSize(at zoom: CGFloat) -> CGFloat {
    max(12, min(42, 42 * sqrt(clampedZoom(zoom))))
  }

  static func clampedZoom(_ value: CGFloat) -> CGFloat {
    min(maximumZoom, max(minimumZoom, value))
  }

  static func steppedZoom(_ zoom: CGFloat, inward: Bool) -> CGFloat {
    let factor = CGFloat(
      Foundation.pow(Double(maximumZoom / minimumZoom), 1.0 / 5.0)
    )
    return clampedZoom(zoom * (inward ? factor : 1 / factor))
  }

  static func heldZoomSpeed(after elapsed: TimeInterval) -> CGFloat {
    let ramp = easedTransition(CGFloat(elapsed / 0.8))
    return 0.18 + 1.45 * ramp
  }

  static func heldZoom(
    _ zoom: CGFloat,
    inward: Bool,
    elapsed: TimeInterval,
    deltaTime: TimeInterval
  ) -> CGFloat {
    let direction: CGFloat = inward ? 1 : -1
    // Double held zoom only; the base speed also seeds the separate tap animation.
    let exponent = direction * 2 * heldZoomSpeed(after: elapsed) * CGFloat(deltaTime)
    return clampedZoom(zoom * CGFloat(Foundation.exp(Double(exponent))))
  }

  static func animatedKeyboardZoom(
    from zoom: CGFloat,
    to targetZoom: CGFloat,
    velocity: CGFloat,
    deltaTime: TimeInterval
  ) -> (zoom: CGFloat, velocity: CGFloat) {
    let position = CGFloat(Foundation.log(Double(zoom)))
    let target = CGFloat(Foundation.log(Double(targetZoom)))
    let distance = target - position
    guard abs(distance) > 0.0001 || abs(velocity) > 0.001 else {
      return (targetZoom, 0)
    }

    let acceleration: CGFloat = 24
    let maximumSpeed: CGFloat = 1.8
    let direction: CGFloat = distance < 0 ? -1 : 1
    let brakingSpeed = CGFloat(Foundation.sqrt(Double(2 * acceleration * abs(distance))))
    let desiredVelocity = direction * min(maximumSpeed, brakingSpeed)
    let velocityChange = acceleration * CGFloat(deltaTime)
    let nextVelocity: CGFloat = if velocity < desiredVelocity {
      min(desiredVelocity, velocity + velocityChange)
    } else {
      max(desiredVelocity, velocity - velocityChange)
    }
    let nextPosition = position + nextVelocity * CGFloat(deltaTime)
    guard distance * (target - nextPosition) > 0 else { return (targetZoom, 0) }
    return (clampedZoom(CGFloat(Foundation.exp(Double(nextPosition)))), nextVelocity)
  }

  static func focusControlsOpacity(progress: CGFloat) -> CGFloat {
    // Hide navigation chrome before the camera flight dominates the minimap.
    1 - easedTransition(min(1, max(0, progress * 3)))
  }

  static func focusBackdropOpacity(progress: CGFloat) -> CGFloat {
    1 - easedTransition(progress)
  }

  static func focusCanvasBackgroundOpacity(progress: CGFloat) -> CGFloat {
    // The whole window performs the final handoff fade. Fading this layer earlier
    // would reveal the real window while its preview is still moving.
    1
  }

  static func focusOverlayOpacity(
    progress: CGFloat,
    handoffStart: CGFloat = 0.5
  ) -> CGFloat {
    let start = min(0.999, max(0, handoffStart))
    return 1 - easedTransition((progress - start) / (1 - start))
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

  static func worldRect(for viewRect: CGRect, camera: CameraState, bounds: CGRect) -> CGRect {
    CGRect(
      origin: viewToWorld(viewRect.origin, camera: camera, bounds: bounds),
      size: CGSize(width: viewRect.width / camera.zoom, height: viewRect.height / camera.zoom)
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

  static func itemIDs<ID: Hashable>(
    containedIn selectionRect: CGRect,
    frames: [ID: CGRect],
    camera: CameraState,
    bounds: CGRect
  ) -> Set<ID> {
    Set(frames.compactMap { id, frame in
      let previewRect = viewRect(for: frame, camera: camera, bounds: bounds)
      return selectionRect.contains(previewRect) ? id : nil
    })
  }

  static func worldTranslation(forViewTranslation translation: CGPoint, zoom: CGFloat) -> CGPoint {
    CGPoint(x: translation.x / zoom, y: translation.y / zoom)
  }

  static func groupSelectionBounds(for rects: [CGRect]) -> CGRect? {
    guard let union = groupContentBounds(for: rects) else { return nil }
    return union.insetBy(dx: -groupSelectionPadding, dy: -groupSelectionPadding)
  }

  static func groupContentBounds(for rects: [CGRect]) -> CGRect? {
    guard let first = rects.first else { return nil }
    return rects.dropFirst().reduce(first) { $0.union($1) }
  }

  static func selectionResizeHandleFrames(
    for bounds: CGRect,
    size: CGFloat
  ) -> [SelectionResizeHandle: CGRect] {
    let centers: [SelectionResizeHandle: CGPoint] = [
      .topLeft: CGPoint(x: bounds.minX, y: bounds.maxY),
      .top: CGPoint(x: bounds.midX, y: bounds.maxY),
      .topRight: CGPoint(x: bounds.maxX, y: bounds.maxY),
      .right: CGPoint(x: bounds.maxX, y: bounds.midY),
      .bottomRight: CGPoint(x: bounds.maxX, y: bounds.minY),
      .bottom: CGPoint(x: bounds.midX, y: bounds.minY),
      .bottomLeft: CGPoint(x: bounds.minX, y: bounds.minY),
      .left: CGPoint(x: bounds.minX, y: bounds.midY),
    ]
    return centers.mapValues { center in
      CGRect(
        x: center.x - size / 2,
        y: center.y - size / 2,
        width: size,
        height: size
      )
    }
  }

  static func resizedSelectionRect(
    _ originalBounds: CGRect,
    dragging handle: SelectionResizeHandle,
    by translation: CGPoint,
    minimumSize: CGSize
  ) -> CGRect {
    var minimumX = originalBounds.minX
    var maximumX = originalBounds.maxX
    var minimumY = originalBounds.minY
    var maximumY = originalBounds.maxY

    if handle.movesLeftEdge {
      minimumX = min(
        originalBounds.maxX - minimumSize.width,
        originalBounds.minX + translation.x
      )
    } else if handle.movesRightEdge {
      maximumX = max(
        originalBounds.minX + minimumSize.width,
        originalBounds.maxX + translation.x
      )
    }
    if handle.movesBottomEdge {
      minimumY = min(
        originalBounds.maxY - minimumSize.height,
        originalBounds.minY + translation.y
      )
    } else if handle.movesTopEdge {
      maximumY = max(
        originalBounds.minY + minimumSize.height,
        originalBounds.maxY + translation.y
      )
    }

    return CGRect(
      x: minimumX,
      y: minimumY,
      width: maximumX - minimumX,
      height: maximumY - minimumY
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

  static func directionalNeighbor<ID: Comparable>(
    from origin: CGRect,
    candidates: [(id: ID, frame: CGRect)],
    direction: CanvasDirection
  ) -> ID? {
    let originCenter = CGPoint(x: origin.midX, y: origin.midY)
    let scored = candidates.compactMap {
      candidate -> (id: ID, score: CGFloat, crossAxisAligned: Bool)? in
      let center = CGPoint(x: candidate.frame.midX, y: candidate.frame.midY)
      let dx = center.x - originCenter.x
      let dy = center.y - originCenter.y
      let primary: CGFloat
      let cross: CGFloat
      let crossAxisAligned: Bool
      switch direction {
      case .left:
        primary = -dx
        cross = abs(dy)
        crossAxisAligned = candidate.frame.maxY > origin.minY
          && candidate.frame.minY < origin.maxY
      case .right:
        primary = dx
        cross = abs(dy)
        crossAxisAligned = candidate.frame.maxY > origin.minY
          && candidate.frame.minY < origin.maxY
      case .up:
        primary = dy
        cross = abs(dx)
        crossAxisAligned = candidate.frame.maxX > origin.minX
          && candidate.frame.minX < origin.maxX
      case .down:
        primary = -dy
        cross = abs(dx)
        crossAxisAligned = candidate.frame.maxX > origin.minX
          && candidate.frame.minX < origin.maxX
      }
      guard primary > 0 else { return nil }

      // A sideways card needs meaningful progress to qualify as a diagonal.
      // While both centers remain inside each other's row/column band, a tiny
      // placement offset must not turn Right into Down (or any rotated equivalent).
      let minimumDiagonalProgress: CGFloat = switch direction {
      case .left, .right: min(origin.width, candidate.frame.width) / 2
      case .up, .down: min(origin.height, candidate.frame.height) / 2
      }
      guard crossAxisAligned || primary >= minimumDiagonalProgress else { return nil }
      return (candidate.id, primary + cross * 2, crossAxisAligned)
    }
    let aligned = scored.filter(\.crossAxisAligned)
    return (aligned.isEmpty ? scored : aligned).min {
      $0.score == $1.score ? $0.id < $1.id : $0.score < $1.score
    }?.id
  }

  static func gridFrames(for sizes: [CGSize], gap: CGFloat = CanvasMath.itemGap) -> [CGRect] {
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

  static func nearestAvailableFrame(
    size: CGSize,
    centeredAt anchor: CGPoint,
    avoiding frames: [CGRect],
    gap: CGFloat = CanvasMath.itemGap,
    maximumRing: Int = 24
  ) -> CGRect {
    func frame(x: Int, y: Int) -> CGRect {
      let center = CGPoint(
        x: anchor.x + CGFloat(x) * (size.width + gap),
        y: anchor.y + CGFloat(y) * (size.height + gap)
      )
      return CGRect(
        x: center.x - size.width / 2,
        y: center.y - size.height / 2,
        width: size.width,
        height: size.height
      )
    }

    func isAvailable(_ candidate: CGRect) -> Bool {
      let paddedCandidate = candidate.insetBy(dx: -gap / 2, dy: -gap / 2)
      return !frames.contains {
        $0.insetBy(dx: -gap / 2, dy: -gap / 2).intersects(paddedCandidate)
      }
    }

    let origin = frame(x: 0, y: 0)
    guard !isAvailable(origin) else { return origin }
    for ring in 1...max(1, maximumRing) {
      var coordinates: [(x: Int, y: Int)] = []
      for x in -ring...ring {
        coordinates.append((x, ring))
        coordinates.append((x, -ring))
      }
      for y in (-(ring - 1))...(ring - 1) {
        coordinates.append((ring, y))
        coordinates.append((-ring, y))
      }
      coordinates.sort {
        let lhsDistance = $0.x * $0.x + $0.y * $0.y
        let rhsDistance = $1.x * $1.x + $1.y * $1.y
        if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
        if $0.y != $1.y { return $0.y > $1.y }
        return $0.x < $1.x
      }
      if let available = coordinates.lazy.map({ frame(x: $0.x, y: $0.y) }).first(
        where: isAvailable
      ) {
        return available
      }
    }
    var fallbackColumn = max(1, maximumRing) + 1
    while true {
      let candidate = frame(x: fallbackColumn, y: 0)
      if isAvailable(candidate) { return candidate }
      fallbackColumn += 1
    }
  }

  static func cameraCentered(on worldFrame: CGRect, preserving camera: CameraState) -> CameraState {
    CameraState(
      center: CGPoint(x: worldFrame.midX, y: worldFrame.midY),
      zoom: camera.zoom
    )
  }
}

// Window identities are session-local; preview selection never changes this history.
struct RecentWindowOrder {
  private(set) var history: [CGWindowID] = []
  private(set) var visible: [CGWindowID] = []
  private var previousInventory: Set<CGWindowID> = []

  mutating func used(_ id: CGWindowID) {
    guard history.first != id else { return }
    history.removeAll { $0 == id }
    history.insert(id, at: 0)
  }

  mutating func updateInventory(_ ids: [CGWindowID]) {
    let available = Set(ids)
    // Focus can arrive before asynchronous discovery exposes a new window.
    history.removeAll { previousInventory.contains($0) && !available.contains($0) }
    previousInventory = available
    var seen = Set(history)
    history += ids.filter { seen.insert($0).inserted }
  }

  mutating func reconcile(_ ids: [CGWindowID], reorder: Bool) {
    updateInventory(ids)
    let available = Set(ids)
    if reorder { visible = history.filter { available.contains($0) } }
    else {
      visible.removeAll { !available.contains($0) }
      var shown = Set(visible)
      visible += history.filter { available.contains($0) && shown.insert($0).inserted }
    }
  }

  static func frames(sizes: [CGSize]) -> [CGRect] {
    var top: CGFloat = 0
    return sizes.map { size in
      let frame = CGRect(x: -size.width / 2, y: top - size.height, width: size.width, height: size.height)
      top = frame.minY - CanvasMath.itemGap
      return frame
    }
  }
}

struct InstalledApp: Sendable {
  let id: String
  let name: String
  let url: URL

  static func catalog() -> [InstalledApp] {
    var apps: [String: InstalledApp] = [:]
    for root in ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications"] {
      guard let iterator = FileManager.default.enumerator(at: URL(fileURLWithPath: root),
        includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
      for case let url as URL in iterator {
        guard url.pathExtension.lowercased() == "app" else { continue }
        iterator.skipDescendants()
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
          id != Bundle.main.bundleIdentifier, apps[id] == nil,
          bundle.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool != true else { continue }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
          ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
          ?? url.deletingPathExtension().lastPathComponent
        apps[id] = InstalledApp(id: id, name: name, url: url)
      }
    }
    return apps.values.sorted {
      let comparison = $0.name.localizedStandardCompare($1.name)
      return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
    }
  }
}

enum WindowBackspaceAction: Equatable {
  case closeWindow
  case quitApp

  static func resolve(windowCount: Int?) -> Self {
    // Only a confirmed last window may end the app; missing inventory closes one window.
    windowCount == 1 ? .quitApp : .closeWindow
  }
}

enum CanvasViewMode: String, CaseIterable {
  case canvas, chronological, overview
  var followsSelectionByDefault: Bool { self != .overview }
}

struct OverviewLayout {
  struct Item: Equatable {
    let id: CGWindowID
    let application: String
    let size: CGSize
  }
  let order: [CGWindowID]
  let frames: [CGWindowID: CGRect]

  static func arrange(_ items: [Item], viewport: CGSize) -> OverviewLayout {
    guard !items.isEmpty else { return OverviewLayout(order: [], frames: [:]) }
    var groups: [[Item]] = []
    for item in items {
      if let index = groups.firstIndex(where: { $0.first?.application == item.application }) {
        groups[index].append(item)
      } else { groups.append([item]) }
    }
    var bestFrames: [CGWindowID: CGRect] = [:]
    var bestScale: CGFloat = 0
    for columns in 1...groups.count {
      let rows = (groups.count + columns - 1) / columns
      let sizes = groups.map { group in
        CGSize(width: (group.map { $0.size.width }.max() ?? 0) + CGFloat(group.count - 1) * 100,
          height: (group.map { $0.size.height }.max() ?? 0) + CGFloat(group.count - 1) * 180)
      }
      var widths = Array(repeating: CGFloat(0), count: columns)
      var heights = Array(repeating: CGFloat(0), count: rows)
      for (index, size) in sizes.enumerated() {
        widths[index % columns] = max(widths[index % columns], size.width)
        heights[index / columns] = max(heights[index / columns], size.height)
      }
      let gap = CanvasMath.itemGap
      let totalWidth = widths.reduce(0, +) + CGFloat(columns - 1) * gap
      let totalHeight = heights.reduce(0, +) + CGFloat(rows - 1) * gap
      let scale = min(max(1, viewport.width) / max(1, totalWidth),
        max(1, viewport.height) / max(1, totalHeight + gap + 180))
      guard scale > bestScale else { continue }
      bestScale = scale
      var xOffsets = Array(repeating: CGFloat(0), count: columns)
      var yOffsets = Array(repeating: CGFloat(0), count: rows)
      for index in 1..<columns { xOffsets[index] = xOffsets[index - 1] + widths[index - 1] + gap }
      for index in 1..<rows { yOffsets[index] = yOffsets[index - 1] + heights[index - 1] + gap }
      var frames: [CGWindowID: CGRect] = [:]
      for (index, group) in groups.enumerated() {
        let column = index % columns, row = index / columns
        let x = xOffsets[column]
        let y = -yOffsets[row]
        for (offset, item) in group.enumerated() {
          frames[item.id] = CGRect(x: x + CGFloat(offset) * 100,
            y: y - item.size.height - CGFloat(offset) * 180,
            width: item.size.width, height: item.size.height)
        }
      }
      bestFrames = frames
    }
    return OverviewLayout(order: groups.flatMap { $0.map(\.id) }, frames: bestFrames)
  }
}

struct OverviewShortcut: Codable, Equatable {
  let keyCode: UInt32
  let modifiers: UInt32
  let label: String
  static let standard = OverviewShortcut(keyCode: 49, modifiers: UInt32(controlKey | optionKey), label: "⌃⌥Space")

  static func from(_ event: NSEvent) -> OverviewShortcut? {
    let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
    guard !event.isARepeat, !flags.intersection([.command, .control, .option]).isEmpty,
      event.keyCode != 53, event.keyCode != 48 else { return nil }
    // Keep common application commands available while recording.
    if flags == .command, [UInt16(12), 13, 8, 9, 0, 6, 7].contains(event.keyCode) { return nil }
    var modifiers: UInt32 = 0
    var label = ""
    for (flag, carbon, symbol) in [(NSEvent.ModifierFlags.control, controlKey, "⌃"),
      (.option, optionKey, "⌥"), (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘")] {
      if flags.contains(flag) { modifiers |= UInt32(carbon); label += symbol }
    }
    let names: [UInt16: String] = [49: "Space", 36: "Return", 51: "⌫", 123: "←", 124: "→", 125: "↓", 126: "↑"]
    label += names[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
    return OverviewShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, label: label)
  }
}

@MainActor
final class OverviewShortcutController {
  static let shared = OverviewShortcutController()
  private(set) var shortcut: OverviewShortcut
  var onActivate: (() -> Void)?
  var isRecording = false
  private var hotKey: EventHotKeyRef?
  private var handler: EventHandlerRef?
  private var held = false

  private init() {
    shortcut = UserDefaults.standard.data(forKey: "overviewShortcut")
      .flatMap { try? JSONDecoder().decode(OverviewShortcut.self, from: $0) } ?? .standard
  }

  func start() -> Bool {
    if handler == nil {
      var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
        EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
      let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
        guard let event else { return OSStatus(eventNotHandledErr) }
        return MainActor.assumeIsolated {
          let controller = OverviewShortcutController.shared
          if GetEventKind(event) == UInt32(kEventHotKeyReleased) { controller.held = false }
          else if !controller.held {
            controller.held = true
            if !controller.isRecording { controller.onActivate?() }
          }
          return noErr
        }
      }, types.count, &types, nil, &handler)
      guard status == noErr else { return false }
    }
    return register(shortcut, persist: false)
  }

  @discardableResult
  func register(_ candidate: OverviewShortcut, persist: Bool = true) -> Bool {
    if hotKey != nil, candidate == shortcut { return true }
    var replacement: EventHotKeyRef?
    let result = RegisterEventHotKey(candidate.keyCode, candidate.modifiers,
      EventHotKeyID(signature: 0x4F504C4E, id: 1), GetApplicationEventTarget(), 0, &replacement)
    guard result == noErr else { return false }
    if let hotKey { UnregisterEventHotKey(hotKey) }
    hotKey = replacement
    held = false
    shortcut = candidate
    if persist, let data = try? JSONEncoder().encode(candidate) {
      UserDefaults.standard.set(data, forKey: "overviewShortcut")
    }
    return true
  }

  func pause() {
    if let hotKey { UnregisterEventHotKey(hotKey) }; hotKey = nil
    held = false
  }

  func stop() {
    if let hotKey { UnregisterEventHotKey(hotKey) }; hotKey = nil
    if let handler { RemoveEventHandler(handler) }; handler = nil
    held = false
  }
}

struct ViewPromptPlan: Codable, Equatable, Sendable {
  let name: String
  let layout: String
  let canPan: Bool
  let followSelection: Bool

  func validated() throws -> Self {
    guard ["canvas", "chronological", "overview", "allApps"].contains(layout),
      !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 40 else {
      throw ViewPromptError.invalidResponse
    }
    return self
  }
  var summary: String {
    "\(name) · \(layout)\nCanvas movement: \(canPan ? "on" : "off") · Follow selection: \(followSelection ? "on" : "off")"
  }
}

enum ViewPromptError: LocalizedError {
  case missingKey, invalidResponse, requestFailed(Int)
  var errorDescription: String? {
    switch self {
    case .missingKey: return "Set OPENAI_API_KEY or enter a key for this session."
    case .invalidResponse: return "No valid view configuration returned. Nothing changed."
    case .requestFailed(let status): return "OpenAI request failed (HTTP \(status)). Nothing changed."
    }
  }
}

enum ViewPromptClient {
  static func requestBody(prompt: String) -> [String: Any] {
    let schema: [String: Any] = ["type": "object", "additionalProperties": false,
      "properties": ["name": ["type": "string"],
        "layout": ["type": "string", "enum": ["canvas", "chronological", "overview", "allApps"]],
        "canPan": ["type": "boolean"], "followSelection": ["type": "boolean"]],
      "required": ["name", "layout", "canPan", "followSelection"]]
    return ["model": "gpt-5-mini", "store": false, "max_output_tokens": 1200, "reasoning": ["effort": "minimal"],
      "instructions": "Propose an OpenPlane view configuration from the user's description. Name maximum 40 characters. Canvas is free spatial layout; chronological is recent windows vertically; overview fits grouped windows on one screen; allApps is an installed app grid. Default canPan and followSelection false for overview/allApps, true otherwise. Only these settings are supported. No code, tool calls, or window data.",
      "input": prompt,
      "text": ["format": ["type": "json_schema", "name": "view_configuration", "strict": true, "schema": schema]]]
  }
  static func decodeResponse(_ data: Data) throws -> ViewPromptPlan {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      json["status"] as? String == "completed",
      let output = json["output"] as? [[String: Any]] else { throw ViewPromptError.invalidResponse }
    let texts = output.flatMap { $0["content"] as? [[String: Any]] ?? [] }
      .filter { $0["type"] as? String == "output_text" }
      .compactMap { $0["text"] as? String }
    guard texts.count == 1, let encoded = texts.first?.data(using: .utf8) else { throw ViewPromptError.invalidResponse }
    return try JSONDecoder().decode(ViewPromptPlan.self, from: encoded).validated()
  }
  static func generate(prompt: String, key: String) async throws -> ViewPromptPlan {
    guard !key.isEmpty else { throw ViewPromptError.missingKey }
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(prompt: prompt))
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw ViewPromptError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
    }
    return try decodeResponse(data)
  }
}

// Only a standalone right-Command tap toggles the overview. Chords pass through.
struct RightCommandTap {
  private var pressed = false
  private var candidate = false
  mutating func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags) -> Bool {
    if type == .flagsChanged && keyCode == 54 {
      let down = flags.rawValue & 0x10 != 0 // NX_DEVICERCMDKEYMASK
      if down && !pressed {
        candidate = flags.intersection([.maskShift, .maskControl, .maskAlternate]).isEmpty
          && flags.rawValue & 0x08 == 0 // left Command
      }
      let activate = pressed && !down && candidate
      pressed = down
      if !down { candidate = false }
      return activate
    }
    if pressed && (type == .keyDown || type == .flagsChanged
      || type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown) {
      candidate = false
    }
    return false
  }
}

struct ToggleParityQueue {
  private(set) var parity = 0

  mutating func recordPress() { parity = (parity + 1) % 2 }

  mutating func consume(isTransitioning: Bool) -> Bool {
    guard !isTransitioning else { return false }
    let shouldToggle = parity == 1
    parity = 0
    return shouldToggle
  }
}
