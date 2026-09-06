@preconcurrency import AppKit
@preconcurrency import ApplicationServices
@preconcurrency import ScreenCaptureKit

@MainActor
struct DiscoveredWindow {
  let id: CGWindowID
  let processID: pid_t
  let bundleIdentifier: String
  let applicationName: String
  let title: String
  let isPrivateBrowsing: Bool
  let frame: CGRect
  let icon: NSImage?
  let captureWindow: SCWindow
  let accessibilityElement: AXUIElement?
}

enum BrowserPrivacy {
  private static let browserBundleMarkers = [
    "com.apple.safari", "com.google.chrome", "org.chromium", "org.mozilla.firefox",
    "com.microsoft.edgemac", "com.brave.browser", "company.thebrowser",
    "com.operasoftware.opera", "com.vivaldi.vivaldi", "com.duckduckgo.macos.browser",
    "com.kagi.kagimacos",
  ]
  private static let browserNameMarkers = [
    "safari", "chrome", "chromium", "firefox", "edge", "brave", "arc", "dia",
    "opera", "vivaldi", "duckduckgo", "orion", "zen browser",
  ]
  private static let privateTitleMarkers = [
    "incognito", "inprivate", "private browsing", "private window", "private mode",
    "inkognito", "privates surfen", "privates fenster", "privater modus",
    "navigation privee", "navegacion privada", "navegacao privada",
    "navigazione privata", "privenavigatie", "tryb incognito", "инкогнито",
    "シークレット", "プライベートブラウズ", "无痕", "無痕", "시크릿",
  ]

  static func isPrivateWindow(
    bundleIdentifier: String,
    applicationName: String,
    title: String
  ) -> Bool {
    let bundle = normalized(bundleIdentifier)
    let application = normalized(applicationName)
    let isBrowser = browserBundleMarkers.contains(where: bundle.contains)
      || browserNameMarkers.contains(where: application.contains)
    guard isBrowser else { return false }
    let title = normalized(title)
    return privateTitleMarkers.contains(where: title.contains)
  }

  private static func normalized(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
      .lowercased()
  }
}

struct WindowGeometry {
  let screenFrame: CGRect
  let size: CGSize
}

struct CapturedPreview: @unchecked Sendable {
  let image: CGImage
  let size: CGSize
}

enum WindowCaptureError: LocalizedError {
  case privateBrowsing

  var errorDescription: String? {
    "Preview disabled for private browsing."
  }
}

private struct AccessibilityWindowRequest: Sendable {
  let id: CGWindowID
  let processID: pid_t
  let title: String
  let frame: CGRect
}

private struct AccessibilityInventoryResult: @unchecked Sendable {
  let elements: [CGWindowID: AXUIElement]
}

private actor AccessibilityInventory {
  private struct CachedMatch {
    let processID: pid_t
    let element: AXUIElement
  }

  private var matchesByWindowID: [CGWindowID: CachedMatch] = [:]
  private var retryAfterByWindowID: [CGWindowID: Date] = [:]

  func resolve(_ requests: [AccessibilityWindowRequest]) -> AccessibilityInventoryResult {
    let requestsByID = Dictionary(uniqueKeysWithValues: requests.map { ($0.id, $0) })
    matchesByWindowID = matchesByWindowID.filter { id, match in
      requestsByID[id]?.processID == match.processID
    }
    retryAfterByWindowID = retryAfterByWindowID.filter { requestsByID[$0.key] != nil }

    var elements = matchesByWindowID.mapValues(\.element)
    let unresolved = requests.filter { matchesByWindowID[$0.id] == nil }
    let now = Date()

    for (processID, processRequests) in Dictionary(grouping: unresolved, by: \.processID) {
      let dueRequests = processRequests.filter {
        retryAfterByWindowID[$0.id].map { $0 <= now } ?? true
      }
      guard !dueRequests.isEmpty else { continue }

      let candidates = AccessibilityWindowMatching.windows(processID: processID)
      guard !candidates.isEmpty else {
        for request in dueRequests {
          retryAfterByWindowID[request.id] = now.addingTimeInterval(3)
        }
        continue
      }

      var used = matchesByWindowID.values.compactMap {
        $0.processID == processID ? $0.element : nil
      }
      for request in dueRequests {
        guard
          let element = AccessibilityWindowMatching.match(
            candidates: candidates,
            title: request.title,
            frame: request.frame,
            excluding: used
          )
        else {
          retryAfterByWindowID[request.id] = now.addingTimeInterval(3)
          continue
        }
        matchesByWindowID[request.id] = CachedMatch(processID: processID, element: element)
        retryAfterByWindowID[request.id] = nil
        elements[request.id] = element
        used.append(element)
      }
    }

    return AccessibilityInventoryResult(
      elements: elements
    )
  }

  func existingWindowIDs() -> Set<CGWindowID> {
    guard
      let windows = CGWindowListCopyWindowInfo(
        [.optionAll, .excludeDesktopElements],
        kCGNullWindowID
      ) as? [[String: Any]]
    else { return [] }

    return Set(windows.compactMap {
      ($0[kCGWindowNumber as String] as? NSNumber).map { CGWindowID($0.uint32Value) }
    })
  }
}

private enum AccessibilityWindowMatching {
  static func windows(processID: pid_t) -> [AXUIElement] {
    let application = AXUIElementCreateApplication(processID)
    guard let windows: [AXUIElement] = attribute(kAXWindowsAttribute, of: application) else {
      return []
    }

    return windows.filter { element in
      let minimized: Bool = attribute(kAXMinimizedAttribute, of: element) ?? false
      let role: String = attribute(kAXRoleAttribute, of: element) ?? ""
      let subrole: String = attribute(kAXSubroleAttribute, of: element) ?? ""
      return !minimized
        && role == (kAXWindowRole as String)
        && subrole == (kAXStandardWindowSubrole as String)
    }
  }

  static func match(
    candidates: [AXUIElement],
    title: String,
    frame: CGRect,
    excluding used: [AXUIElement]
  ) -> AXUIElement? {
    let scores = candidates.filter { candidate in
      !used.contains(where: { CFEqual($0, candidate) })
    }.map { candidate in
      (
        element: candidate,
        title: WindowIdentity.titleMatchScore(
          source: title,
          candidate: attribute(kAXTitleAttribute, of: candidate) ?? ""
        ),
        geometry: geometryScore(element: candidate, frame: frame)
      )
    }

    let titleMatches = scores.compactMap { score -> (AXUIElement, Int, CGFloat)? in
      score.title.map { (score.element, $0, score.geometry) }
    }.sorted {
      $0.1 == $1.1 ? $0.2 < $1.2 : $0.1 < $1.1
    }
    if let best = titleMatches.first {
      guard titleMatches.count == 1
        || best.1 < titleMatches[1].1
        || titleMatches[1].2 - best.2 > 2
      else { return nil }
      return best.0
    }

    let geometryMatches = scores.sorted { $0.geometry < $1.geometry }
    // An unrelated helper surface must not claim the only standard AX window.
    guard let best = geometryMatches.first, best.geometry <= 8,
      geometryMatches.count == 1 || geometryMatches[1].geometry - best.geometry > 2
    else { return nil }
    return best.element
  }

  static func point(of element: AXUIElement) -> CGPoint? {
    guard let value: AXValue = attribute(kAXPositionAttribute, of: element),
      AXValueGetType(value) == .cgPoint
    else { return nil }
    var point = CGPoint.zero
    return AXValueGetValue(value, .cgPoint, &point) ? point : nil
  }

  static func size(of element: AXUIElement) -> CGSize? {
    guard let value: AXValue = attribute(kAXSizeAttribute, of: element),
      AXValueGetType(value) == .cgSize
    else { return nil }
    var size = CGSize.zero
    return AXValueGetValue(value, .cgSize, &size) ? size : nil
  }

  private static func geometryScore(element: AXUIElement, frame: CGRect) -> CGFloat {
    let candidatePoint = point(of: element) ?? .zero
    let candidateSize = size(of: element) ?? .zero
    return abs(candidatePoint.x - frame.minX)
      + abs(candidatePoint.y - frame.minY)
      + abs(candidateSize.width - frame.width)
      + abs(candidateSize.height - frame.height)
  }

  private static func attribute<T>(_ name: String, of element: AXUIElement) -> T? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
      return nil
    }
    return value as? T
  }
}

enum WindowIdentity {
  static func titleMatchScore(source: String, candidate: String) -> Int? {
    let source = normalizedTitle(source)
    let candidate = normalizedTitle(candidate)
    guard !source.isEmpty, !candidate.isEmpty else { return nil }
    if source == candidate { return 0 }
    if source.contains(candidate) || candidate.contains(source) { return 1 }

    let fragments = source.split(separator: "…").map(String.init).filter { $0.count >= 3 }
    guard fragments.count >= 2 else { return nil }
    var searchStart = candidate.startIndex
    for fragment in fragments {
      guard let range = candidate.range(
        of: fragment,
        range: searchStart..<candidate.endIndex
      ) else { return nil }
      searchStart = range.upperBound
    }
    return 2
  }

  static func normalizedTitle(_ title: String) -> String {
    title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
      .replacingOccurrences(of: "...", with: "…")
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
  }
}

@MainActor
final class WindowService {
  private let ownProcessID = ProcessInfo.processInfo.processIdentifier
  private let accessibilityInventory = AccessibilityInventory()
  private var applicationIcons: [pid_t: NSImage] = [:]

  func discover(on screen: NSScreen) async throws -> [DiscoveredWindow] {
    let content = try await SCShareableContent.excludingDesktopWindows(
      false, onScreenWindowsOnly: true)
    let mainDisplayFrame = CGRect(origin: .zero, size: screen.frame.size)
    let windows = content.windows.compactMap { window -> SCWindow? in
      guard
        window.isOnScreen,
        window.windowLayer == 0,
        window.frame.width >= 180,
        window.frame.height >= 100,
        window.frame.intersects(mainDisplayFrame),
        let application = window.owningApplication,
        application.processID != ownProcessID,
        !application.bundleIdentifier.isEmpty
      else { return nil }
      return window
    }
    let requests = windows.compactMap { window -> AccessibilityWindowRequest? in
      guard let application = window.owningApplication else { return nil }
      return AccessibilityWindowRequest(
        id: window.windowID,
        processID: application.processID,
        title: window.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
        frame: window.frame
      )
    }
    let accessibility = await accessibilityInventory.resolve(requests)
    let activeProcessIDs = Set(windows.compactMap { $0.owningApplication?.processID })
    applicationIcons = applicationIcons.filter { activeProcessIDs.contains($0.key) }

    return windows.compactMap { window in
      guard let application = window.owningApplication,
        accessibility.elements[window.windowID] != nil
      else { return nil }
      let title = window.title?.trimmingCharacters(in: .whitespacesAndNewlines)
      let resolvedTitle = title?.isEmpty == false ? title! : application.applicationName
      return DiscoveredWindow(
        id: window.windowID,
        processID: application.processID,
        bundleIdentifier: application.bundleIdentifier,
        applicationName: application.applicationName,
        title: resolvedTitle,
        isPrivateBrowsing: BrowserPrivacy.isPrivateWindow(
          bundleIdentifier: application.bundleIdentifier,
          applicationName: application.applicationName,
          title: resolvedTitle
        ),
        frame: window.frame,
        icon: applicationIcon(for: application.processID),
        captureWindow: window,
        accessibilityElement: accessibility.elements[window.windowID]
      )
    }
    .sorted {
      if $0.applicationName == $1.applicationName { return $0.id < $1.id }
      return $0.applicationName.localizedStandardCompare($1.applicationName) == .orderedAscending
    }
  }

  func capture(
    window: SCWindow,
    targetLongEdgePixels: Int = 1_200
  ) async throws -> CapturedPreview {
    if let application = window.owningApplication,
      BrowserPrivacy.isPrivateWindow(
        bundleIdentifier: application.bundleIdentifier,
        applicationName: application.applicationName,
        title: window.title ?? ""
      ),
      !UserDefaults.standard.bool(forKey: OpenPlanePreferences.showPrivateBrowserPreviews)
    {
      throw WindowCaptureError.privateBrowsing
    }
    let size = window.frame.size
    let longEdge = max(size.width, size.height)
    let scale = min(2, CGFloat(targetLongEdgePixels) / max(1, longEdge))
    let configuration = SCScreenshotConfiguration()
    configuration.width = max(1, Int((size.width * scale).rounded()))
    configuration.height = max(1, Int((size.height * scale).rounded()))
    configuration.showsCursor = false
    configuration.ignoreShadows = true
    configuration.ignoreClipping = true

    let filter = SCContentFilter(desktopIndependentWindow: window)
    let output = try await SCScreenshotManager.captureScreenshot(
      contentFilter: filter,
      configuration: configuration
    )
    guard let image = output.sdrImage else {
      throw NSError(
        domain: "OpenPlane.WindowCapture",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "ScreenCaptureKit returned no image."]
      )
    }
    return CapturedPreview(image: image, size: size)
  }

  func prepareForFocus(_ node: WindowNode) -> Bool {
    guard
      let element = node.accessibilityElement
        ?? AccessibilityWindowMatching.match(
          candidates: AccessibilityWindowMatching.windows(processID: node.processID),
          title: node.title,
          frame: node.sourceFrame,
          excluding: []
        )
    else { return false }

    node.accessibilityElement = element
    return true
  }

  func activate(_ node: WindowNode) {
    if let element = node.accessibilityElement {
      AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }
    NSRunningApplication(processIdentifier: node.processID)?.activate(options: [])
  }

  @discardableResult
  func activate(_ application: NSRunningApplication) -> Bool {
    let activated = application.activate(options: [.activateAllWindows])
    let accessibilityApplication = AXUIElementCreateApplication(application.processIdentifier)
    let madeFrontmost = AXUIElementSetAttributeValue(
      accessibilityApplication,
      kAXFrontmostAttribute as CFString,
      kCFBooleanTrue
    ) == .success
    let raisedWindow = AccessibilityWindowMatching.windows(
      processID: application.processIdentifier
    ).first.map {
      AXUIElementPerformAction($0, kAXRaiseAction as CFString) == .success
    } ?? false
    return activated || madeFrontmost || raisedWindow
  }

  func geometry(of node: WindowNode, on screen: NSScreen) -> WindowGeometry? {
    guard let element = node.accessibilityElement,
      let topLeft = AccessibilityWindowMatching.point(of: element),
      let size = AccessibilityWindowMatching.size(of: element)
    else {
      return nil
    }
    let localX = topLeft.x - screen.frame.minX
    let localBottomY = screen.frame.height - (topLeft.y + size.height)
    return WindowGeometry(
      screenFrame: CGRect(x: localX, y: localBottomY, width: size.width, height: size.height),
      size: size
    )
  }

  func frontmostWindowID(among nodes: [WindowNode]) -> CGWindowID? {
    let candidateIDs = Set(nodes.map(\.id))
    guard
      let windows = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
      ) as? [[String: Any]]
    else { return nil }

    for window in windows {
      guard let number = window[kCGWindowNumber as String] as? NSNumber else { continue }
      let id = CGWindowID(number.uint32Value)
      if candidateIDs.contains(id) { return id }
    }
    return nil
  }

  func existingWindowIDs() async -> Set<CGWindowID> {
    await accessibilityInventory.existingWindowIDs()
  }

  private func applicationIcon(for processID: pid_t) -> NSImage? {
    if let icon = applicationIcons[processID] { return icon }
    let icon = NSRunningApplication(processIdentifier: processID)?.icon
    applicationIcons[processID] = icon
    return icon
  }

}

// Observe the active application's focus rather than polling screen captures in the background.
@MainActor
final class WindowFocusObserver {
  var onFocus: ((CGWindowID) -> Void)?
  private var observer: AXObserver?
  private var observedPID: pid_t?

  func observeFrontmost() {
    guard AXIsProcessTrusted() else { return }
    guard let app = NSWorkspace.shared.frontmostApplication,
      app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
    if observedPID != app.processIdentifier {
      stop()
      observedPID = app.processIdentifier
      var created: AXObserver?
      let result = AXObserverCreate(app.processIdentifier, { _, _, _, context in
        guard let context else { return }
        MainActor.assumeIsolated {
          Unmanaged<WindowFocusObserver>.fromOpaque(context).takeUnretainedValue().recordFrontmost()
        }
      }, &created)
      if result == .success, let created {
        observer = created
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.2)
        for notification in [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification] {
          AXObserverAddNotification(created, element, notification as CFString,
            Unmanaged.passUnretained(self).toOpaque())
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
      }
    }
    recordFrontmost()
  }

  func recordFrontmost() {
    guard AXIsProcessTrusted() else { return }
    guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
      pid != ProcessInfo.processInfo.processIdentifier,
      let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]] else { return }
    let candidates = windows.filter {
      ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
        && ($0[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
    }
    let application = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(application, 0.2)
    var focused: CFTypeRef?
    if AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &focused) == .success,
      let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() {
      let element = focused as! AXUIElement
      if let point = AccessibilityWindowMatching.point(of: element),
        let size = AccessibilityWindowMatching.size(of: element),
        let match = candidates.first(where: { info in
          guard let raw = info[kCGWindowBounds as String] as? NSDictionary,
            let frame = CGRect(dictionaryRepresentation: raw) else { return false }
          return abs(frame.minX - point.x) < 2 && abs(frame.minY - point.y) < 2
            && abs(frame.width - size.width) < 2 && abs(frame.height - size.height) < 2
        }), let id = (match[kCGWindowNumber as String] as? NSNumber)?.uint32Value {
        onFocus?(id)
        return
      }
    }
    // Some apps expose activation but no focused-window attribute; use their frontmost window.
    if let info = candidates.first, let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value {
      onFocus?(id)
    }
  }

  func stop() {
    if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
    observer = nil
    observedPID = nil
  }
}
