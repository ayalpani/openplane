import XCTest

@testable import OpenPlane

final class CanvasMathTests: XCTestCase {
  func testDesktopPagesRenameNavigateAndLockIndependentViews() throws {
    let firstCamera = CameraState(center: CGPoint(x: 10, y: 20), zoom: 0.5)
    let secondCamera = CameraState(center: CGPoint(x: 800, y: 20), zoom: 0.6)
    let firstPosition = PersistedWindowPosition(
      windowID: 10,
      bundleIdentifier: "com.apple.TextEdit",
      title: "Notes",
      center: CGPoint(x: 120, y: 240)
    )
    let secondPosition = PersistedWindowPosition(
      windowID: 10,
      bundleIdentifier: "com.apple.TextEdit",
      title: "Notes",
      center: CGPoint(x: 920, y: 240)
    )
    var desktops = DesktopPages()

    desktops.renameSelectedPage("Focus")
    desktops.updateSelectedCamera(firstCamera)
    desktops.updateSelectedWindowPositions([firstPosition])
    let firstID = desktops.selectedID
    XCTAssertTrue(desktops.toggleSelectedPageLock(at: firstCamera))

    let second = desktops.addPage(camera: secondCamera)
    desktops.updateSelectedWindowPositions([secondPosition])
    XCTAssertEqual(second.title, "Desktop 2")
    XCTAssertEqual(desktops.selectedPage.camera, secondCamera)
    XCTAssertFalse(desktops.isSelectedPageLocked)
    XCTAssertEqual(
      desktops.selectedWindowCenters(for: [firstPosition])[10],
      secondPosition.center
    )

    XCTAssertEqual(desktops.select(firstID), firstCamera)
    XCTAssertEqual(desktops.selectedPage.displayTitle, "Focus")
    XCTAssertEqual(desktops.selectedPage.lockedCamera, firstCamera)
    XCTAssertEqual(
      desktops.selectedWindowCenters(for: [secondPosition])[10],
      firstPosition.center
    )

    let data = try JSONEncoder().encode(desktops)
    let decoded = try JSONDecoder().decode(DesktopPages.self, from: data)
    XCTAssertEqual(decoded, desktops)

    let legacyData = Data(
      #"{"id":"FC1F3B4C-22A0-4F19-90EB-7D0893D21C65","title":"Desktop 1","camera":null,"lockedCamera":null}"#.utf8
    )
    XCTAssertEqual(
      try JSONDecoder().decode(DesktopPage.self, from: legacyData).windowPositions,
      []
    )
  }

  func testWindowPositionsRestoreWithoutGuessingBetweenAmbiguousWindows() {
    let stored = [
      PersistedWindowPosition(
        windowID: 10,
        bundleIdentifier: "com.google.Chrome",
        title: "Alpha",
        center: CGPoint(x: 100, y: 200)
      ),
      PersistedWindowPosition(
        windowID: 11,
        bundleIdentifier: "com.google.Chrome",
        title: "Beta",
        center: CGPoint(x: 300, y: 400)
      ),
      PersistedWindowPosition(
        windowID: 20,
        bundleIdentifier: "com.apple.Notes",
        title: "Old title",
        center: CGPoint(x: 500, y: 600)
      ),
    ]
    let current = [
      PersistedWindowPosition(
        windowID: 10,
        bundleIdentifier: "com.google.Chrome",
        title: "Changed tab",
        center: .zero
      ),
      PersistedWindowPosition(
        windowID: 99,
        bundleIdentifier: "com.google.Chrome",
        title: "Beta",
        center: .zero
      ),
      PersistedWindowPosition(
        windowID: 30,
        bundleIdentifier: "com.apple.Notes",
        title: "Changed note",
        center: .zero
      ),
    ]

    let restored = WindowPositionPersistence.restoredCenters(for: current, from: stored)
    XCTAssertEqual(restored[10], CGPoint(x: 100, y: 200))
    XCTAssertEqual(restored[99], CGPoint(x: 300, y: 400))
    XCTAssertEqual(restored[30], CGPoint(x: 500, y: 600))

    let ambiguous = WindowPositionPersistence.restoredCenters(
      for: [
        PersistedWindowPosition(
          windowID: 100,
          bundleIdentifier: "com.google.Chrome",
          title: "Unrelated tab",
          center: .zero
        )
      ],
      from: Array(stored.prefix(2))
    )
    XCTAssertTrue(ambiguous.isEmpty)
  }

  func testLegacyWindowPositionsMigrateIntoManifestedAppHomes() throws {
    struct LegacyDesktopPage: Encodable {
      let id: UUID
      let title: String
      let camera: CameraState?
      let lockedCamera: CameraState?
      let windowPositions: [PersistedWindowPosition]
    }

    let legacy = LegacyDesktopPage(
      id: UUID(),
      title: "Focus",
      camera: nil,
      lockedCamera: nil,
      windowPositions: [
        PersistedWindowPosition(
          windowID: 10,
          bundleIdentifier: "com.example.Editor",
          title: "First",
          center: CGPoint(x: 100, y: 200)
        ),
        PersistedWindowPosition(
          windowID: 11,
          bundleIdentifier: "com.example.Editor",
          title: "Second",
          center: CGPoint(x: 500, y: 200)
        ),
      ]
    )

    let page = try JSONDecoder().decode(
      DesktopPage.self,
      from: JSONEncoder().encode(legacy)
    )
    XCTAssertEqual(page.appPlacements.count, 1)
    XCTAssertEqual(page.appPlacements[0].bundleIdentifier, "com.example.Editor")
    XCTAssertEqual(page.appPlacements[0].home, CGPoint(x: 100, y: 200))
    XCTAssertEqual(page.appPlacements[0].windowSlots.count, 2)
    XCTAssertTrue(page.windowPositions.isEmpty)
  }

  func testManifestedAppHomesAndWindowSlotsStayIndependentPerDesktop() {
    let firstWindow = WindowPlacementSnapshot(
      windowID: 10,
      bundleIdentifier: "com.example.Editor",
      title: "Document",
      center: CGPoint(x: 100, y: 200),
      size: CGSize(width: 800, height: 600)
    )
    let secondWindow = WindowPlacementSnapshot(
      windowID: 20,
      bundleIdentifier: "com.example.Editor",
      title: "Document",
      center: CGPoint(x: 900, y: 200),
      size: CGSize(width: 800, height: 600)
    )
    var desktops = DesktopPages()
    desktops.updateSelectedAppPlacement(
      bundleIdentifier: "com.example.Editor",
      applicationName: "Editor",
      home: firstWindow.center,
      windows: [firstWindow]
    )
    let firstID = desktops.selectedID

    _ = desktops.addPage(camera: CameraState(center: CGPoint(x: 900, y: 200), zoom: 1))
    desktops.updateSelectedAppPlacement(
      bundleIdentifier: "com.example.Editor",
      applicationName: "Editor",
      home: secondWindow.center,
      windows: [secondWindow]
    )
    XCTAssertEqual(
      desktops.selectedWindowCenters(for: [secondWindow])[20],
      CGPoint(x: 900, y: 200)
    )

    _ = desktops.select(firstID)
    XCTAssertEqual(
      desktops.selectedWindowCenters(for: [firstWindow])[10],
      CGPoint(x: 100, y: 200)
    )
    desktops.forgetSelectedAppPlacement(bundleIdentifier: "com.example.Editor")
    XCTAssertNil(desktops.selectedAppPlacement(for: "com.example.Editor"))
  }

  func testAppWindowSlotsUseUniqueTitlesWithoutGuessingAmbiguousChildren() {
    let placement = AppPlacement(
      bundleIdentifier: "com.example.Browser",
      applicationName: "Browser",
      home: CGPoint(x: 100, y: 100),
      lastKnownSize: CGSize(width: 800, height: 600),
      windowSlots: [
        WindowSlot(
          offset: .zero,
          size: CGSize(width: 800, height: 600),
          lastWindowID: nil,
          titleHint: "Duplicate"
        ),
        WindowSlot(
          offset: CGPoint(x: 1_000, y: 0),
          size: CGSize(width: 800, height: 600),
          lastWindowID: nil,
          titleHint: "Duplicate"
        ),
      ]
    )
    let current = [
      WindowPlacementSnapshot(
        windowID: 20,
        bundleIdentifier: placement.bundleIdentifier,
        title: "Duplicate",
        center: .zero,
        size: placement.lastKnownSize
      ),
      WindowPlacementSnapshot(
        windowID: 21,
        bundleIdentifier: placement.bundleIdentifier,
        title: "Duplicate",
        center: .zero,
        size: placement.lastKnownSize
      ),
    ]

    let restored = AppPlacementPersistence.restoredCenters(
      for: current,
      from: [placement]
    )
    XCTAssertEqual(restored, [20: placement.home])
  }

  func testAmbiguousAppWindowSlotsAreReusedWhenPersisting() {
    let placement = AppPlacement(
      bundleIdentifier: "com.example.Browser",
      applicationName: "Browser",
      home: CGPoint(x: 100, y: 100),
      lastKnownSize: CGSize(width: 800, height: 600),
      windowSlots: [
        WindowSlot(
          offset: .zero,
          size: CGSize(width: 800, height: 600),
          lastWindowID: nil,
          titleHint: "Duplicate"
        ),
        WindowSlot(
          offset: CGPoint(x: 1_000, y: 0),
          size: CGSize(width: 800, height: 600),
          lastWindowID: nil,
          titleHint: "Duplicate"
        ),
      ]
    )
    let windows = [
      WindowPlacementSnapshot(
        windowID: 20,
        bundleIdentifier: placement.bundleIdentifier,
        title: "Duplicate",
        center: placement.home,
        size: placement.lastKnownSize
      ),
      WindowPlacementSnapshot(
        windowID: 21,
        bundleIdentifier: placement.bundleIdentifier,
        title: "Duplicate",
        center: CGPoint(x: 1_100, y: 100),
        size: placement.lastKnownSize
      ),
    ]

    let updated = AppPlacementPersistence.updating(
      placement,
      applicationName: placement.applicationName,
      home: placement.home,
      windows: windows
    )
    XCTAssertEqual(updated.windowSlots.count, 2)
    XCTAssertEqual(Set(updated.windowSlots.compactMap(\.lastWindowID)), [20, 21])
    XCTAssertEqual(Set(updated.windowSlots.map(\.titleHint)), ["duplicate"])
  }

  func testCommandTabMatcherOnlyClaimsTheSystemSwitcherShortcut() {
    XCTAssertTrue(ShortcutMatcher.isCommandTab(keyCode: 48, flags: [.maskCommand]))
    XCTAssertTrue(
      ShortcutMatcher.isCommandTab(keyCode: 48, flags: [.maskCommand, .maskShift]))
    XCTAssertFalse(
      ShortcutMatcher.isCommandTab(keyCode: 48, flags: [.maskCommand, .maskAlternate]))
    XCTAssertFalse(ShortcutMatcher.isCommandTab(keyCode: 49, flags: [.maskCommand]))
  }

  func testBackspaceQuitsOnlyOncePerKeyPress() {
    XCTAssertTrue(ShortcutMatcher.isPlaneBackspace(keyCode: 51, isRepeat: false))
    XCTAssertFalse(ShortcutMatcher.isPlaneBackspace(keyCode: 51, isRepeat: true))
    XCTAssertFalse(ShortcutMatcher.isPlaneBackspace(keyCode: 117, isRepeat: false))
  }

  func testPendingPlaceholderLaunchIgnoresAnotherActivatedApplication() {
    let requested = Set(["com.apple.AppStore"])

    XCTAssertTrue(
      WorkspaceActivationPolicy.shouldFollow(
        bundleIdentifier: "com.apple.AppStore",
        requestedLaunches: requested
      )
    )
    XCTAssertFalse(
      WorkspaceActivationPolicy.shouldFollow(
        bundleIdentifier: "com.apple.QuickTimePlayerX",
        requestedLaunches: requested
      )
    )
    XCTAssertTrue(
      WorkspaceActivationPolicy.shouldFollow(
        bundleIdentifier: "com.apple.QuickTimePlayerX",
        requestedLaunches: []
      )
    )
  }

  func testCanvasChromeScalesAndFadesAtBirdsEyeZoom() {
    XCTAssertEqual(CanvasMath.appIconScale(at: 0.06), 0.5, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.appIconScale(at: 0.18), 1, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.titleVisibility(at: 0.06, availableWidth: 100), 0, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.titleVisibility(at: 0.09, availableWidth: 100), 0, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.titleVisibility(at: 0.10, availableWidth: 100), 0.5, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.titleVisibility(at: 0.14, availableWidth: 72), 1, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.titleVisibility(at: 1, availableWidth: 32), 0, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.placeholderStatusFontSize(at: 0.06), 12, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.placeholderStatusFontSize(at: 0.25), 21, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.placeholderStatusFontSize(at: 1), 42, accuracy: 0.001)
  }

  func testDesktopTitleNudgeEnclosesNotchAndGrowsWithText() {
    XCTAssertEqual(
      CanvasMath.desktopTitleNudgeWidth(textWidth: 72, availableWidth: 808),
      236
    )
    XCTAssertEqual(
      CanvasMath.desktopTitleNudgeWidth(textWidth: 360, availableWidth: 808),
      416
    )
    XCTAssertEqual(
      CanvasMath.desktopTitleNudgeWidth(textWidth: 900, availableWidth: 760),
      760
    )

    let layout = CanvasMath.desktopTitleNudgeLayout(safeAreaTop: 32)
    XCTAssertEqual(layout.titleTopInset, 40)
    XCTAssertEqual(layout.titleBoxHeight, 44)
    XCTAssertEqual(layout.depth, 92)
    XCTAssertEqual(
      layout.titleTopInset - 32,
      layout.depth - layout.titleTopInset - layout.titleBoxHeight
    )
  }

  func testGridPatternStaysInSyncAndVisible() {
    XCTAssertEqual(CanvasMath.gridSpacing(at: 1), 52, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.gridSpacing(at: 0.2), 10.4, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.gridSpacing(at: 0.06), 3.12, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.gridDotSize(at: 0.06), 1, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.gridDotSize(at: 1), 2, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.gridOpacity(at: 0.149), 0, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.gridOpacity(at: 0.15), 0.5, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.gridOpacity(at: 0.25), 0.5, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.gridOpacity(at: 0.325), 0.75, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.gridOpacity(at: 0.4), 1, accuracy: 0.001)
  }

  func testPreviewResolutionFollowsVisibleRetinaSizeWithinLimits() {
    XCTAssertEqual(
      CanvasMath.previewPixelLength(
        displaySize: CGSize(width: 500, height: 300),
        backingScale: 2
      ),
      1_200
    )
    XCTAssertEqual(
      CanvasMath.previewPixelLength(
        displaySize: CGSize(width: 1_600, height: 900),
        backingScale: 2
      ),
      3_200
    )
    XCTAssertEqual(
      CanvasMath.previewPixelLength(
        displaySize: CGSize(width: 3_000, height: 2_000),
        backingScale: 2
      ),
      3_840
    )
  }

  func testFocusBackdropFadesOutAcrossCameraTransition() {
    XCTAssertEqual(CanvasMath.focusBackdropOpacity(progress: 0), 1, accuracy: 0.001)
    XCTAssertLessThan(CanvasMath.focusBackdropOpacity(progress: 0.5), 1)
    XCTAssertEqual(CanvasMath.focusBackdropOpacity(progress: 1), 0, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.focusOverlayOpacity(progress: 0.5), 1, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.focusOverlayOpacity(progress: 0.75), 0.5, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.focusOverlayOpacity(progress: 1), 0, accuracy: 0.001)
    XCTAssertEqual(
      CanvasMath.focusOverlayOpacity(progress: 0.57, handoffStart: 7 / 12),
      1,
      accuracy: 0.001
    )
    XCTAssertGreaterThan(
      CanvasMath.focusOverlayOpacity(progress: 0.75, handoffStart: 7 / 12),
      0
    )
    XCTAssertEqual(
      CanvasMath.focusOverlayOpacity(progress: 1, handoffStart: 7 / 12),
      0,
      accuracy: 0.001
    )
  }

  func testFocusKeepsCanvasBackgroundOpaqueUntilWindowHandoff() {
    for progress: CGFloat in [0, 0.25, 0.5, 0.75, 1] {
      XCTAssertEqual(
        CanvasMath.focusCanvasBackgroundOpacity(progress: progress),
        1,
        accuracy: 0.001,
        "The real window must stay covered while its preview is moving."
      )
    }
  }

  func testTrackedCameraMovesFocusedWindowOnStraightScreenPath() {
    let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 700)
    let start = CameraState(center: CGPoint(x: -400, y: 250), zoom: 0.2)
    let target = CameraState(center: CGPoint(x: 300, y: -180), zoom: 1.1)
    let anchor = CGPoint(x: 720, y: 310)
    let progress: CGFloat = 0.35
    let startPoint = CanvasMath.worldToView(anchor, camera: start, bounds: bounds)
    let targetPoint = CanvasMath.worldToView(anchor, camera: target, bounds: bounds)
    let camera = CanvasMath.interpolatedCamera(
      from: start,
      to: target,
      tracking: anchor,
      progress: progress,
      in: bounds
    )
    let actualPoint = CanvasMath.worldToView(anchor, camera: camera, bounds: bounds)

    XCTAssertEqual(
      actualPoint.x,
      startPoint.x + (targetPoint.x - startPoint.x) * progress,
      accuracy: 0.001
    )
    XCTAssertEqual(
      actualPoint.y,
      startPoint.y + (targetPoint.y - startPoint.y) * progress,
      accuracy: 0.001
    )
    XCTAssertEqual(camera.zoom, 0.515, accuracy: 0.001)
  }

  func testSelectionHighlightsImmediately() {
    let start = CanvasMath.selectionAnimationPhases(progress: 0)
    let titleReady = CanvasMath.selectionAnimationPhases(progress: 0.55)
    let end = CanvasMath.selectionAnimationPhases(progress: 1)

    XCTAssertEqual(start.title, 0, accuracy: 0.001)
    XCTAssertEqual(start.border, 0, accuracy: 0.001)
    XCTAssertEqual(titleReady.title, 1, accuracy: 0.001)
    XCTAssertEqual(titleReady.border, 0.55, accuracy: 0.001)
    XCTAssertEqual(end.title, 1, accuracy: 0.001)
    XCTAssertEqual(end.border, 1, accuracy: 0.001)
    let synchronized = CanvasMath.selectionAnimationPhases(
      progress: 0.25
    )
    XCTAssertEqual(synchronized.border, 0.25, accuracy: 0.001)
    XCTAssertEqual(
      CanvasMath.selectionTitleLift(progress: 1, isPrimary: true),
      6,
      accuracy: 0.001
    )
    XCTAssertEqual(
      CanvasMath.selectionTitleLift(progress: 1, isPrimary: false),
      4,
      accuracy: 0.001
    )
    let oldPrimary = CanvasMath.sameApplicationSelectionMetrics(primaryProgress: 1)
    let handoff = CanvasMath.sameApplicationSelectionMetrics(primaryProgress: 0.5)
    let newSecondary = CanvasMath.sameApplicationSelectionMetrics(primaryProgress: 0)
    XCTAssertEqual(oldPrimary.borderWidth, 4, accuracy: 0.001)
    XCTAssertEqual(oldPrimary.titleLift, 6, accuracy: 0.001)
    XCTAssertEqual(handoff.borderWidth, 3, accuracy: 0.001)
    XCTAssertEqual(handoff.titleLift, 5, accuracy: 0.001)
    XCTAssertEqual(newSecondary.borderWidth, 2, accuracy: 0.001)
    XCTAssertEqual(newSecondary.titleLift, 4, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.easedTransition(0), 0, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.easedTransition(0.5), 0.5, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.easedTransition(1), 1, accuracy: 0.001)

  }

  func testAppNavigationHistoryMovesBothDirectionsAndDropsForwardBranch() {
    var history = AppNavigationHistory()
    history.opened("app.a")
    history.opened("app.b")
    history.opened("app.b")
    history.opened("app.c")

    XCTAssertTrue(history.canGoBack(available: ["app.a", "app.c"]))
    XCTAssertEqual(history.backDestination(available: ["app.a", "app.b"]), "app.b")
    XCTAssertEqual(history.goBack(available: ["app.a", "app.b", "app.c"]), "app.b")
    XCTAssertEqual(history.forwardDestination(available: ["app.a", "app.c"]), "app.c")
    XCTAssertTrue(history.canGoForward(available: ["app.a", "app.c"]))
    XCTAssertEqual(history.goBack(available: ["app.a", "app.b", "app.c"]), "app.a")
    XCTAssertEqual(history.current, "app.a")
    XCTAssertEqual(history.goForward(available: ["app.a", "app.b", "app.c"]), "app.b")
    history.opened("app.d")
    XCTAssertFalse(history.canGoForward(available: ["app.a", "app.b", "app.c", "app.d"]))
  }

  func testCanvasSearchMatchesAppNamesAndWindowTitles() {
    XCTAssertTrue(
      CanvasSearch.matches(query: "chrome", applicationName: "Google Chrome", title: "OpenPlane")
    )
    XCTAssertTrue(
      CanvasSearch.matches(query: "plane", applicationName: "ChatGPT", title: "OpenPlane")
    )
    XCTAssertFalse(
      CanvasSearch.matches(query: "Safari", applicationName: "ChatGPT", title: "OpenPlane")
    )
    XCTAssertEqual(
      CanvasSearch.status(query: "", resultCount: 12, selectedIndex: nil),
      "ESC to cancel search"
    )
    XCTAssertEqual(
      CanvasSearch.status(query: "chrome", resultCount: 0, selectedIndex: nil),
      "0 results"
    )
    XCTAssertEqual(
      CanvasSearch.status(query: "chrome", resultCount: 1, selectedIndex: 0),
      "1 of 1 result"
    )
    XCTAssertEqual(
      CanvasSearch.status(query: "chrome", resultCount: 15, selectedIndex: 4),
      "5 of 15 results"
    )
  }

  @MainActor
  func testPreviewCacheRoundTrip() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("OpenPlanePreviewCache-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let image = NSImage(size: CGSize(width: 12, height: 8), flipped: false) { rect in
      NSColor.systemBlue.setFill()
      rect.fill()
      return true
    }
    let cache = PreviewCache(directoryURL: directory)
    let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
    await cache.store(image: cgImage, windowID: 42, bundleIdentifier: "com.example.app")

    let cachedData = await cache.loadData(
      windowID: 42,
      bundleIdentifier: "com.example.app"
    )
    XCTAssertNotNil(cachedData.flatMap(NSImage.init(data:)))
    await cache.store(image: cgImage, windowID: 43, bundleIdentifier: "com.google.Chrome")
    let browserData = await cache.loadData(windowID: 43, bundleIdentifier: "com.google.Chrome")
    XCTAssertNil(browserData)
    let legacy = directory.appendingPathComponent("com.google.Chrome-44.jpg")
    try Data("synthetic legacy cache".utf8).write(to: legacy)
    _ = PreviewCache(directoryURL: directory)
    XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
  }

  func testCoordinateRoundTrip() {
    let bounds = CGRect(x: 0, y: 0, width: 1_200, height: 800)
    let camera = CameraState(center: CGPoint(x: 310, y: -90), zoom: 0.42)
    let world = CGPoint(x: -220, y: 470)
    let result = CanvasMath.viewToWorld(
      CanvasMath.worldToView(world, camera: camera, bounds: bounds),
      camera: camera,
      bounds: bounds
    )
    XCTAssertEqual(result.x, world.x, accuracy: 0.001)
    XCTAssertEqual(result.y, world.y, accuracy: 0.001)
  }

  func testMarqueeRequiresFullContainmentAndGroupTranslationUsesCanvasCoordinates() {
    let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 800)
    let camera = CameraState(center: .zero, zoom: 0.5)
    let frames: [CGWindowID: CGRect] = [
      1: CGRect(x: -100, y: -100, width: 200, height: 200),
      2: CGRect(x: 600, y: 400, width: 200, height: 200),
      3: CGRect(x: 80, y: -100, width: 200, height: 200),
    ]
    let marquee = CanvasMath.selectionRect(
      from: CGPoint(x: 600, y: 460),
      to: CGPoint(x: 450, y: 350)
    )

    XCTAssertEqual(
      CanvasMath.itemIDs(
        containedIn: marquee,
        frames: frames,
        camera: camera,
        bounds: bounds
      ),
      [1]
    )
    XCTAssertEqual(
      CanvasMath.worldTranslation(
        forViewTranslation: CGPoint(x: 30, y: -20),
        zoom: camera.zoom
      ),
      CGPoint(x: 60, y: -40)
    )
    XCTAssertEqual(
      CanvasMath.groupSelectionBounds(
        for: [CGRect(x: 100, y: 100, width: 200, height: 100)]
      ),
      CGRect(x: 88, y: 88, width: 224, height: 124)
    )
  }

  func testSelectionBoundsIncludeZoomedIconAndOnlyVisibleTitle() throws {
    let preview = CGRect(x: 100, y: 100, width: 200, height: 100)
    let smallHeader = CanvasMath.previewHeaderLayout(for: preview, zoom: 0.06, titleLift: 6)
    XCTAssertEqual(smallHeader.icon, CGRect(x: 91, y: 191, width: 18, height: 18))
    XCTAssertEqual(smallHeader.titleVisibility, 0)
    let small = CanvasMath.previewVisualBounds(
      for: preview, zoom: 0.06, titleLift: 6, borderOutset: 6)
    XCTAssertEqual(small, CGRect(x: 91, y: 94, width: 215, height: 115))
    XCTAssertEqual(
      CanvasMath.groupSelectionBounds(for: [small]), CGRect(x: 79, y: 82, width: 239, height: 139))

    let largeHeader = CanvasMath.previewHeaderLayout(for: preview, zoom: 0.18, titleLift: 6)
    XCTAssertEqual(largeHeader.icon, CGRect(x: 82, y: 182, width: 36, height: 36))
    XCTAssertEqual(largeHeader.title, CGRect(x: 126, y: 208, width: 174, height: 16))
    XCTAssertEqual(largeHeader.titleVisibility, 1)
    let large = CanvasMath.previewVisualBounds(
      for: preview, zoom: 0.18, titleLift: 6, borderOutset: 6)
    XCTAssertEqual(large, CGRect(x: 82, y: 94, width: 224, height: 130))
    XCTAssertEqual(
      CanvasMath.groupSelectionBounds(for: [large]), CGRect(x: 70, y: 82, width: 248, height: 154))
    XCTAssertEqual(
      CanvasMath.previewVisualBounds(
        for: preview, zoom: 0.18, titleLift: 6, borderOutset: 4, hasIcon: false, hasTitle: false),
      CGRect(x: 96, y: 96, width: 208, height: 108)
    )
  }

  func testSelectionPaddingIsEqualWhenDifferentItemsDefineEachOutsideEdge() throws {
    let visibleItems = [
      CGRect(x: 100, y: 100, width: 300, height: 180),
      CGRect(x: -250, y: 300, width: 100, height: 60),
      CGRect(x: 50, y: -200, width: 600, height: 120),
    ]
    for count in 1...visibleItems.count {
      let items = Array(visibleItems.prefix(count))
      let content = items.dropFirst().reduce(items[0]) { $0.union($1) }
      let frame = try XCTUnwrap(CanvasMath.groupSelectionBounds(for: items))
      XCTAssertEqual(content.minX - frame.minX, 12)
      XCTAssertEqual(content.minY - frame.minY, 12)
      XCTAssertEqual(frame.maxX - content.maxX, 12)
      XCTAssertEqual(frame.maxY - content.maxY, 12)
      XCTAssertEqual(CanvasMath.groupSelectionBounds(for: items.reversed()), frame)
    }
    XCTAssertNil(CanvasMath.groupSelectionBounds(for: []))
  }

  func testSelectionResizeUsesOppositeEdgesAsAnchors() {
    let original = CGRect(x: 0, y: 0, width: 300, height: 200)
    let bounds = CGRect(x: 0, y: 0, width: 600, height: 400)
    let camera = CameraState(center: CGPoint(x: 300, y: 200), zoom: 1)
    let windows: [CGWindowID: CGRect] = [
      1: CGRect(x: 30, y: 20, width: 50, height: 50),
      2: CGRect(x: 400, y: 20, width: 50, height: 50),
      3: CGRect(x: 590, y: 20, width: 50, height: 50),
    ]

    let cornerResize = CanvasMath.resizedSelectionRect(
      original,
      dragging: .topRight,
      by: CGPoint(x: 300, y: 200),
      minimumSize: CGSize(width: 80, height: 80)
    )
    XCTAssertEqual(cornerResize, CGRect(x: 0, y: 0, width: 600, height: 400))
    XCTAssertEqual(
      CanvasMath.itemIDs(
        containedIn: cornerResize,
        frames: windows,
        camera: camera,
        bounds: bounds
      ),
      [1, 2]
    )
    XCTAssertEqual(windows[1], CGRect(x: 30, y: 20, width: 50, height: 50))
    XCTAssertEqual(windows[2], CGRect(x: 400, y: 20, width: 50, height: 50))
    XCTAssertEqual(windows[3], CGRect(x: 590, y: 20, width: 50, height: 50))

    let sideResize = CanvasMath.resizedSelectionRect(
      original,
      dragging: .left,
      by: CGPoint(x: 150, y: 200),
      minimumSize: CGSize(width: 80, height: 80)
    )
    XCTAssertEqual(sideResize, CGRect(x: 150, y: 0, width: 150, height: 200))
  }

  func testZoomKeepsPointerOverSameWorldPoint() {
    let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 700)
    let pointer = CGPoint(x: 820, y: 190)
    let camera = CameraState(center: CGPoint(x: 100, y: 40), zoom: 0.5)
    let before = CanvasMath.viewToWorld(pointer, camera: camera, bounds: bounds)
    let zoomed = CanvasMath.zoomedCamera(camera, to: 1.1, around: pointer, in: bounds)
    let after = CanvasMath.viewToWorld(pointer, camera: zoomed, bounds: bounds)
    XCTAssertEqual(before.x, after.x, accuracy: 0.001)
    XCTAssertEqual(before.y, after.y, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.clampedZoom(0), 0.06, accuracy: 0.001)
  }

  func testZoomAroundViewportCenterKeepsCameraCenter() {
    let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 700)
    let camera = CameraState(center: CGPoint(x: 100, y: 40), zoom: 0.5)
    let center = CGPoint(x: bounds.midX, y: bounds.midY)

    XCTAssertEqual(
      CanvasMath.zoomedCamera(camera, to: 1.1, around: center, in: bounds).center,
      camera.center
    )
    XCTAssertEqual(
      CanvasMath.zoomedCamera(camera, to: 0.1, around: center, in: bounds).center,
      camera.center
    )
  }

  func testKeyboardZoomStepsInExpectedDirectionAndStaysWithinLimits() {
    var inwardZoom = CanvasMath.minimumZoom
    var outwardZoom = CanvasMath.maximumZoom
    for _ in 0..<5 {
      inwardZoom = CanvasMath.steppedZoom(inwardZoom, inward: true)
      outwardZoom = CanvasMath.steppedZoom(outwardZoom, inward: false)
    }
    XCTAssertEqual(inwardZoom, CanvasMath.maximumZoom, accuracy: 0.001)
    XCTAssertEqual(outwardZoom, CanvasMath.minimumZoom, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.steppedZoom(1.25, inward: true), CanvasMath.maximumZoom)
    XCTAssertEqual(CanvasMath.steppedZoom(0.06, inward: false), CanvasMath.minimumZoom)
  }

  func testHeldKeyboardZoomAcceleratesAndMovesContinuouslyInBothDirections() {
    XCTAssertLessThan(
      CanvasMath.heldZoomSpeed(after: 0),
      CanvasMath.heldZoomSpeed(after: 0.8)
    )
    XCTAssertGreaterThan(
      CanvasMath.heldZoom(0.5, inward: true, elapsed: 0.8, deltaTime: 1.0 / 60.0),
      0.5
    )
    XCTAssertLessThan(
      CanvasMath.heldZoom(0.5, inward: false, elapsed: 0.8, deltaTime: 1.0 / 60.0),
      0.5
    )
  }

  func testHeldZoomUsesDoubleRateInBothDirectionsWithoutMovingCenter() {
    // Twice the previous logarithmic speed, including the unchanged 0.8s ramp.
    let rates: [(TimeInterval, CGFloat)] = [
      (0, 0.36), (0.2, 0.813125), (0.4, 1.81), (0.8, 3.26), (1.6, 3.26),
    ]
    let camera = CameraState(center: CGPoint(x: 730, y: -240), zoom: 0.4)
    let bounds = CGRect(x: 0, y: 0, width: 1_728, height: 1_117)
    for (elapsed, rate) in rates {
      for inward in [true, false] {
        for deltaTime in [1.0 / 60.0, 1.0 / 120.0] {
          let zoom = CanvasMath.heldZoom(
            camera.zoom, inward: inward, elapsed: elapsed, deltaTime: deltaTime
          )
          XCTAssertEqual(
            log(zoom / camera.zoom) / deltaTime,
            (inward ? 1 : -1) * rate,
            accuracy: 0.000001
          )
          XCTAssertEqual(
            CanvasMath.zoomedCamera(
              camera, to: zoom, around: CGPoint(x: bounds.midX, y: bounds.midY), in: bounds
            ).center,
            camera.center
          )
        }
      }
    }
    XCTAssertEqual(CanvasMath.heldZoom(1.2, inward: true, elapsed: 1, deltaTime: 1), CanvasMath.maximumZoom)
    XCTAssertEqual(CanvasMath.heldZoom(0.07, inward: false, elapsed: 1, deltaTime: 1), CanvasMath.minimumZoom)
    XCTAssertEqual(CanvasMath.heldZoomSpeed(after: 0), 0.18) // Tap seed remains unchanged.
  }

  func testAnimatedKeyboardZoomContinuesTowardAnExtendedTargetWithoutRestarting() {
    var zoom = CanvasMath.minimumZoom
    var velocity: CGFloat = 0
    let firstTarget = CanvasMath.steppedZoom(zoom, inward: true)

    for _ in 0..<6 {
      let frame = CanvasMath.animatedKeyboardZoom(
        from: zoom,
        to: firstTarget,
        velocity: velocity,
        deltaTime: 1.0 / 60.0
      )
      zoom = frame.zoom
      velocity = frame.velocity
    }

    let zoomBeforeExtension = zoom
    let velocityBeforeExtension = velocity
    var extendedTarget = firstTarget
    for _ in 0..<2 {
      extendedTarget = CanvasMath.steppedZoom(extendedTarget, inward: true)
    }
    let extendedFrame = CanvasMath.animatedKeyboardZoom(
      from: zoom,
      to: extendedTarget,
      velocity: velocity,
      deltaTime: 1.0 / 60.0
    )

    XCTAssertGreaterThan(extendedFrame.zoom, zoomBeforeExtension)
    XCTAssertGreaterThanOrEqual(extendedFrame.velocity, velocityBeforeExtension)

    zoom = extendedFrame.zoom
    velocity = extendedFrame.velocity
    for _ in 0..<300 where zoom != extendedTarget || velocity != 0 {
      let frame = CanvasMath.animatedKeyboardZoom(
        from: zoom,
        to: extendedTarget,
        velocity: velocity,
        deltaTime: 1.0 / 60.0
      )
      zoom = frame.zoom
      velocity = frame.velocity
    }
    XCTAssertEqual(zoom, extendedTarget)
    XCTAssertEqual(velocity, 0)
  }

  func testClampedPanelOriginStaysInsideAvailableFrame() {
    let availableFrame = CGRect(x: 24, y: 96, width: 952, height: 656)
    let panelSize = CGSize(width: 268, height: 244)

    XCTAssertEqual(
      CanvasMath.clampedOrigin(CGPoint(x: -100, y: 900), size: panelSize, in: availableFrame),
      CGPoint(x: 24, y: 508)
    )
    XCTAssertEqual(
      CanvasMath.clampedOrigin(CGPoint(x: 400, y: 300), size: panelSize, in: availableFrame),
      CGPoint(x: 400, y: 300)
    )
  }

  func testGridHasRequestedGap() {
    let sizes = [CGSize(width: 300, height: 200), CGSize(width: 500, height: 400)]
    let frames = CanvasMath.gridFrames(for: sizes)
    XCTAssertEqual(frames.count, 2)
    XCTAssertGreaterThanOrEqual(frames[1].minX - frames[0].maxX, 240)
    XCTAssertEqual(frames[0].midY, frames[1].midY, accuracy: 0.001)
  }

  func testPreviewsExpandWithinLargestAvailableCell() {
    let sizes = [
      CGSize(width: 400, height: 200),
      CGSize(width: 1_000, height: 700),
      CGSize(width: 250, height: 500),
    ]
    let expanded = CanvasMath.previewSizes(for: sizes, expand: true)

    XCTAssertEqual(expanded[0], CGSize(width: 1_000, height: 500))
    XCTAssertEqual(expanded[1], sizes[1])
    XCTAssertEqual(expanded[2], CGSize(width: 350, height: 700))
    XCTAssertEqual(CanvasMath.previewSizes(for: sizes, expand: false), sizes)
  }

  func testCascadeAvoidsExistingFrame() {
    let existing = CGRect(x: -200, y: -150, width: 400, height: 300)
    let result = CanvasMath.cascadedFrame(
      size: existing.size,
      centeredAt: .zero,
      avoiding: [existing]
    )
    XCTAssertFalse(existing.intersects(result))
  }

  func testNearestAvailablePlacementIsDeterministicAndKeepsItsGap() {
    let size = CGSize(width: 200, height: 120)
    let occupied = CGRect(x: -100, y: -60, width: 200, height: 120)
    let first = CanvasMath.nearestAvailableFrame(
      size: size,
      centeredAt: .zero,
      avoiding: [occupied],
      gap: 40
    )
    let second = CanvasMath.nearestAvailableFrame(
      size: size,
      centeredAt: .zero,
      avoiding: [occupied],
      gap: 40
    )

    XCTAssertEqual(first, second)
    XCTAssertNotEqual(first, occupied)
    XCTAssertFalse(
      first.insetBy(dx: -20, dy: -20).intersects(
        occupied.insetBy(dx: -20, dy: -20)
      )
    )
  }

  func testNearestAvailablePlacementStillFindsSpaceBeyondThePreferredRings() {
    let size = CGSize(width: 100, height: 100)
    let occupied = (-1...1).flatMap { x in
      (-1...1).map { y in
        CGRect(
          x: CGFloat(x) * 140 - 50,
          y: CGFloat(y) * 140 - 50,
          width: 100,
          height: 100
        )
      }
    } + [CGRect(x: 230, y: -50, width: 100, height: 100)]
    let result = CanvasMath.nearestAvailableFrame(
      size: size,
      centeredAt: .zero,
      avoiding: occupied,
      gap: 40,
      maximumRing: 1
    )
    XCTAssertEqual(result.midX, 420, accuracy: 0.001)
    XCTAssertFalse(occupied.contains(where: { $0.intersects(result) }))
  }

  func testStateMachineRejectsSecondFocus() {
    var state = CanvasStateMachine()
    XCTAssertTrue(state.beginFocus(on: 1))
    XCTAssertFalse(state.beginFocus(on: 2))
    state.completeFocus(on: 1)
    XCTAssertEqual(state.mode, .working(1))
    state.returnToOverview()
    XCTAssertEqual(state.mode, .overview)
  }

  func testRequestedCloseRemovesOnlyAfterWindowIsActuallyGone() {
    var tracker = WindowInventoryTracker()
    XCTAssertTrue(tracker.change(previous: [1, 2], current: [1, 2], existing: [1, 2], requestedCloseIDs: [1]).removed.isEmpty)
    XCTAssertTrue(tracker.change(previous: [1, 2], current: [2], existing: [1], requestedCloseIDs: [1]).removed.isEmpty)
    XCTAssertEqual(tracker.change(previous: [1, 2], current: [2], existing: [], requestedCloseIDs: [1]).removed, [1])
  }

  func testInventoryTrackerWaitsForThreeMissesAndRestoresTransientWindows() {
    var tracker = WindowInventoryTracker()
    let previous: Set<CGWindowID> = [1, 2, 3]

    XCTAssertEqual(tracker.change(previous: previous, current: [2, 3]).removed, [])
    XCTAssertEqual(tracker.change(previous: previous, current: previous).removed, [])
    XCTAssertEqual(tracker.change(previous: previous, current: [2, 3], existing: [1]).removed, [])
    XCTAssertEqual(tracker.change(previous: previous, current: [2, 3], existing: [1]).removed, [])
    XCTAssertEqual(tracker.change(previous: previous, current: [2, 3]).removed, [])
    XCTAssertEqual(tracker.change(previous: previous, current: [2, 3]).removed, [])
    XCTAssertEqual(tracker.change(previous: previous, current: [2, 3]).removed, [1])
  }

  func testPendingQuitSuppressesConfirmationWindowUntilItDisappears() {
    let start = Date()
    var suppression = PendingQuitWindowSuppression(
      knownWindowIDs: [1],
      deadline: start.addingTimeInterval(5)
    )

    XCTAssertTrue(suppression.observe(currentWindowIDs: [1, 2], now: start))
    XCTAssertTrue(suppression.allows(1))
    XCTAssertFalse(suppression.allows(2))
    XCTAssertTrue(
      suppression.observe(
        currentWindowIDs: [1, 2],
        now: start.addingTimeInterval(30)
      )
    )
    XCTAssertFalse(
      suppression.observe(
        currentWindowIDs: [1],
        now: start.addingTimeInterval(31)
      )
    )
  }

  func testCanvasPaletteHasOneVariantOfEveryBaseColorAndFallsBackToSlate() {
    XCTAssertEqual(CanvasPalette.backgrounds.count, 12)
    XCTAssertEqual(CanvasPalette.background(for: "violet").name, "Violet")
    XCTAssertEqual(CanvasPalette.background(for: "missing").id, CanvasPalette.defaultID)
  }

  func testPreviewRefreshSchedulerKeepsSelectionLiveAndRotatesBackgrounds() {
    var scheduler = PreviewRefreshScheduler()
    let visible: [CGWindowID] = [1, 2, 3, 4]

    XCTAssertEqual(scheduler.nextIDs(from: visible, selectedID: 2, limit: 2), [2, 1])
    XCTAssertEqual(scheduler.nextIDs(from: visible, selectedID: 2, limit: 2), [2, 3])
    XCTAssertEqual(scheduler.nextIDs(from: visible, selectedID: 2, limit: 2), [2, 4])
    XCTAssertEqual(scheduler.nextIDs(from: visible, selectedID: 2, limit: 2), [2, 1])
  }

  func testPreviewStatusExplainsFreshnessAndFallback() {
    XCTAssertEqual(PreviewState.loading.toolTip(hasPreview: true), "Checking for the latest preview…")
    XCTAssertEqual(
      PreviewState.current.toolTip(hasPreview: true),
      "Latest preview captured successfully."
    )
    XCTAssertEqual(
      PreviewState.failed.toolTip(hasPreview: true),
      "Preview update failed — showing the last saved image."
    )
    XCTAssertEqual(PreviewState.failed.toolTip(hasPreview: false), "Preview unavailable.")
    XCTAssertEqual(
      PreviewState.redacted.toolTip(hasPreview: false),
      "Browser preview hidden because non-private mode cannot be verified."
    )
  }

  func testBrowserPreviewsIgnoreRemovedPrivacyPreference() {
    for browser in ["com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox", "com.microsoft.edgemac", "company.thebrowser.Browser"] {
      XCTAssertFalse(BrowserPrivacy.shouldSuppressPreview(bundleIdentifier: browser,
        applicationName: "", isPrivateBrowsing: true, allowsPrivatePreviews: false))
      XCTAssertFalse(BrowserPrivacy.shouldSuppressPreview(bundleIdentifier: browser,
        applicationName: "", allowsPrivatePreviews: true))
    }
    XCTAssertFalse(BrowserPrivacy.shouldSuppressPreview(bundleIdentifier: "com.apple.TextEdit",
      applicationName: "TextEdit", allowsPrivatePreviews: false))
  }

  func testPrivateBrowserWindowsAreDetectedWithoutRedactingUnrelatedApps() {
    XCTAssertTrue(
      BrowserPrivacy.isPrivateWindow(
        bundleIdentifier: "com.google.Chrome",
        applicationName: "Google Chrome",
        title: "New Tab — Incognito"
      )
    )
    XCTAssertTrue(
      BrowserPrivacy.isPrivateWindow(
        bundleIdentifier: "com.microsoft.edgemac",
        applicationName: "Microsoft Edge",
        title: "Neuer Tab — InPrivate"
      )
    )
    XCTAssertTrue(
      BrowserPrivacy.isPrivateWindow(
        bundleIdentifier: "org.mozilla.firefox",
        applicationName: "Firefox",
        title: "Privates Fenster"
      )
    )
    XCTAssertFalse(
      BrowserPrivacy.isPrivateWindow(
        bundleIdentifier: "com.google.Chrome",
        applicationName: "Google Chrome",
        title: "OpenPlane — GitHub"
      )
    )
    XCTAssertFalse(
      BrowserPrivacy.isPrivateWindow(
        bundleIdentifier: "com.apple.TextEdit",
        applicationName: "TextEdit",
        title: "Incognito draft"
      )
    )
  }

  func testWindowIdentityMatchesBrowserDecoratedAndTruncatedTitles() {
    XCTAssertEqual(
      WindowIdentity.titleMatchScore(
        source: "OpenPlane — Excalidraw Plus",
        candidate: "OpenPlane — Excalidraw Plus - Google Chrome – Arash (private)"
      ),
      1
    )
    XCTAssertEqual(
      WindowIdentity.titleMatchScore(
        source: "EINGANG / ENTRANCE - YOUR NU… Breakdance Hip Hop Ballett",
        candidate:
          "EINGANG / ENTRANCE - YOUR NUMBER ONE HOTSPOT FOR DANCE Breakdance Hip Hop Ballett - Google Chrome – Arash (private)"
      ),
      2
    )
    XCTAssertNil(
      WindowIdentity.titleMatchScore(
        source: "EINGANG / ENTRANCE",
        candidate: "OpenPlane — Excalidraw Plus - Google Chrome"
      )
    )
  }

  func testDirectionalNavigationUsesSpatialNeighbors() {
    let origin = CGRect(x: -5, y: -5, width: 10, height: 10)
    let candidates: [(id: CGWindowID, frame: CGRect)] = [
      (1, CGRect(x: -105, y: 5, width: 10, height: 10)),
      (2, CGRect(x: 95, y: 5, width: 10, height: 10)),
      (3, CGRect(x: 0, y: 95, width: 10, height: 10)),
      (4, CGRect(x: 0, y: -105, width: 10, height: 10)),
      (5, CGRect(x: 35, y: 95, width: 10, height: 10)),
    ]

    XCTAssertEqual(
      CanvasMath.directionalNeighbor(from: origin, candidates: candidates, direction: .left), 1)
    XCTAssertEqual(
      CanvasMath.directionalNeighbor(from: origin, candidates: candidates, direction: .right), 2)
    XCTAssertEqual(
      CanvasMath.directionalNeighbor(from: origin, candidates: candidates, direction: .up), 3)
    XCTAssertEqual(
      CanvasMath.directionalNeighbor(from: origin, candidates: candidates, direction: .down), 4)
  }

  func testDirectionalNavigationSupportsWindowAndPlaceholderKeys() {
    let candidates = [
      (id: "window:1", frame: CGRect(x: 95, y: -5, width: 10, height: 10)),
      (id: "app:com.example.Editor", frame: CGRect(x: 195, y: 5, width: 10, height: 10)),
    ]
    XCTAssertEqual(
      CanvasMath.directionalNeighbor(
        from: CGRect(x: -5, y: -5, width: 10, height: 10),
        candidates: candidates,
        direction: .right
      ),
      "window:1"
    )
  }

  func testDirectionalNavigationPrefersARealLeftNeighborOverACloserDiagonal() {
    let origin = CGRect(x: -50, y: -50, width: 100, height: 100)
    let candidates = [
      (id: "zshell", frame: CGRect(x: -500, y: -50, width: 200, height: 100)),
      (id: "chrome", frame: CGRect(x: -100, y: -170, width: 100, height: 100)),
    ]

    XCTAssertEqual(
      CanvasMath.directionalNeighbor(
        from: origin,
        candidates: candidates,
        direction: .left
      ),
      "zshell"
    )
    XCTAssertEqual(
      CanvasMath.directionalNeighbor(
        from: origin,
        candidates: [candidates[1]],
        direction: .left
      ),
      "chrome"
    )
  }

  func testNavigationCameraCentersEveryTargetAndPreservesZoom() {
    let camera = CameraState(center: CGPoint(x: 40, y: 80), zoom: 0.4)
    let target = CGRect(x: 600, y: -50, width: 200, height: 100)
    XCTAssertEqual(
      CanvasMath.cameraCentered(on: target, preserving: camera),
      CameraState(center: CGPoint(x: 700, y: 0), zoom: 0.4)
    )
  }

  func testDirectionalNavigationFinderDownChoosesLibreOfficeNotWisprFlow() {
    // Captured app homes from the reported desktop; closed cards use fullview size.
    let size = CGSize(width: 1728, height: 1117)
    func card(x: CGFloat, y: CGFloat) -> CGRect {
      CGRect(x: x - size.width / 2, y: y - size.height / 2,
        width: size.width, height: size.height)
    }
    let finder = card(x: 787.9607828882445, y: -1278.615848581301)
    let candidates = [
      (id: "app:com.electron.wispr-flow",
        frame: card(x: 2858.207548972093, y: -1280.494954236737)),
      (id: "app:org.libreoffice.script",
        frame: card(x: -2583.93458456098, y: -4307.115898177777)),
      (id: "app:com.lwouis.alt-tab-macos",
        frame: card(x: 4956.310456705214, y: -1256.394616012064)),
    ]
    XCTAssertEqual(
      CanvasMath.directionalNeighbor(from: finder, candidates: candidates, direction: .down),
      "app:org.libreoffice.script"
    )
    XCTAssertEqual(
      CanvasMath.directionalNeighbor(from: finder, candidates: candidates, direction: .right),
      "app:com.electron.wispr-flow"
    )
  }

  func testDirectionalNavigationScenariosInEveryDirection() {
    func rect(_ x: CGFloat, _ y: CGFloat, width: CGFloat = 100, height: CGFloat = 80) -> CGRect {
      CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
    }
    let origin = rect(0, 0)
    let scenarios: [(name: String, frames: [CGRect], expectedIndex: Int?)] = [
      ("diagonal beats a slightly lower sideways neighbor", [rect(160, -2), rect(-250, -240)], 1),
      ("same row is not a downward destination", [rect(160, -2), rect(-160, -3)], nil),
      ("empty canvas", [], nil),
      ("no wrapping to opposite or identical centers", [rect(0, 160), origin, rect(160, 0)], nil),
      ("aligned neighbor beats closer diagonal", [rect(0, -600), rect(-160, -120)], 0),
      ("diagonal fallback remains reachable", [rect(-160, -120)], 0),
      ("nearest aligned neighbor", [rect(0, -280), rect(0, -140)], 1),
      ("overlapping neighbor in the same column", [rect(0, -10), rect(0, -140)], 0),
      ("small sideways window", [rect(160, -2, width: 20, height: 20), rect(-250, -240)], 1),
      ("tall sideways window", [rect(160, -2, height: 800), rect(-250, -240)], 1),
      ("touching column edges are not alignment", [rect(100, -2), rect(-250, -240)], 1),
      ("wide window spanning the column", [rect(200, -100, width: 600), rect(-160, -120)], 0),
      ("partially overlapping diagonal", [rect(160, -50)], 0),
      ("stable tie break", [rect(-160, -120), rect(160, -120)], 0),
    ]

    // Rotate the down-facing fixtures with exact transforms, then mirror, scale,
    // and reorder them. Direction and geometry must determine the same result.
    let rotations: [(CanvasDirection, CGAffineTransform)] = [
      (.down, .identity),
      (.up, CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 0, ty: 0)),
      (.left, CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 0)),
      (.right, CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0)),
    ]
    for scenario in scenarios {
      for (direction, rotation) in rotations {
        for mirror: CGFloat in [-1, 1] {
          for scale: CGFloat in [0.1, 1, 10] {
            func transform(_ frame: CGRect) -> CGRect {
              frame.applying(CGAffineTransform(scaleX: mirror, y: 1))
                .applying(rotation)
                .applying(CGAffineTransform(scaleX: scale, y: scale))
                .offsetBy(dx: 720, dy: -930)
            }
            let candidates = scenario.frames.enumerated().map {
              (id: "target:\($0.offset)", frame: transform($0.element))
            }
            for ordered in [candidates, Array(candidates.reversed())] {
              XCTAssertEqual(
                CanvasMath.directionalNeighbor(
                  from: transform(origin), candidates: ordered, direction: direction
                ),
                scenario.expectedIndex.map { "target:\($0)" },
                "\(scenario.name); \(direction), mirror \(mirror), scale \(scale)"
              )
            }
          }
        }
      }
    }
  }

  func testDirectionalNavigationTreatsWindowsAndClosedCardsEqually() {
    let origin = CGRect(x: -50, y: -40, width: 100, height: 80)
    for sideKey in ["window:1", "app:com.example.Side"] {
      for destinationKey in ["window:2", "app:com.example.Destination"] {
        XCTAssertEqual(
          CanvasMath.directionalNeighbor(
            from: origin,
            candidates: [
              (id: sideKey, frame: origin.offsetBy(dx: 160, dy: -2)),
              (id: destinationKey, frame: origin.offsetBy(dx: -250, dy: -240)),
            ],
            direction: .down
          ),
          destinationKey
        )
      }
    }
  }
}

final class RecentWindowOrderTests: XCTestCase {
  func testActualUsageAndFrozenTraversalAreSeparate() {
    var order = RecentWindowOrder()
    order.reconcile([10, 20, 30, 40], reorder: true)
    order.used(30)
    order.used(10)
    order.used(30)
    XCTAssertEqual(order.visible, [10, 20, 30, 40])
    order.reconcile([10, 20, 30, 40], reorder: true)
    XCTAssertEqual(order.visible, [30, 10, 20, 40])
    order.used(20)
    order.reconcile([10, 20, 40, 50], reorder: false)
    XCTAssertEqual(order.visible, [10, 20, 40, 50])
    order.reconcile([10, 20, 40, 50], reorder: true)
    XCTAssertEqual(order.visible, [20, 10, 40, 50])
  }

  func testFocusBeforeDiscoveryIsNotLostOrShownPrematurely() {
    var order = RecentWindowOrder()
    order.reconcile([1, 2], reorder: true)
    order.used(3)
    order.reconcile([1, 2], reorder: true)
    XCTAssertEqual(order.visible, [1, 2])
    order.reconcile([1, 2, 3], reorder: true)
    XCTAssertEqual(order.visible, [3, 1, 2])
    order.reconcile([1, 2], reorder: true)
    order.reconcile([1, 2, 3], reorder: true)
    XCTAssertEqual(order.visible, [1, 2, 3])
  }

  func testEmptySingleDuplicateAndReusedWindowIdentity() {
    var order = RecentWindowOrder()
    order.reconcile([1, 1], reorder: true)
    order.used(1)
    XCTAssertEqual(order.visible, [1])
    order.reconcile([], reorder: false)
    XCTAssertTrue(order.visible.isEmpty)
    XCTAssertTrue(order.history.isEmpty)
    order.reconcile([2, 1], reorder: true)
    XCTAssertEqual(order.visible, [2, 1])
  }

  func testApplicationGridUsesWidthAndRowMajorOrder() {
    let frames = CanvasMath.applicationGridFrames(count: 20, viewport: CGSize(width: 1200, height: 800))
    XCTAssertEqual(frames.count, 20)
    XCTAssertEqual(frames[0].minY, frames[7].minY)
    XCTAssertGreaterThan(frames[7].minX, frames[0].minX)
    XCTAssertLessThan(frames[8].minY, frames[0].minY)
    XCTAssertEqual(frames[8].minX, frames[0].minX)
    XCTAssertTrue(frames.allSatisfy { $0.minX >= -600 && $0.maxX <= 600 })
  }

  func testCatalogZoomKeepsIconsAndMinimumGap() {
    for zoom: CGFloat in [0.06, 0.3, 0.55, 0.7, 1, 1.25] {
      let metrics = CanvasMath.applicationTileMetrics(zoom: zoom)
      XCTAssertGreaterThanOrEqual(metrics.icon, 40)
      if zoom <= 0.55 { XCTAssertEqual(metrics.caption, 0) }
      let frames = CanvasMath.applicationGridFrames(count: 100,
        viewport: CGSize(width: 1200, height: 800), zoom: zoom)
      XCTAssertGreaterThanOrEqual((frames[1].minX - frames[0].maxX) * zoom, 16 - 0.001)
      XCTAssertEqual(frames[0].height * zoom, metrics.size.height, accuracy: 0.001)
    }
  }

  func testAllAppsCardKeepsRoomForFixedScreenSizeLabel() {
    for zoom: CGFloat in [0.06, 0.2, 0.45, 1, 2] {
      let size = CanvasMath.allAppsCardSize(at: zoom)
      XCTAssertGreaterThanOrEqual(size.width * zoom, 160 - 0.001)
      XCTAssertGreaterThanOrEqual(size.height * zoom, 48 - 0.001)
    }
  }

  func testVerticalFramesHaveSharedAxisAndFixedGapWithMixedSizes() {
    let sizes = [CGSize(width: 1000, height: 700), CGSize(width: 450, height: 900), CGSize(width: 800, height: 180)]
    let frames = RecentWindowOrder.frames(sizes: sizes)
    XCTAssertEqual(frames.map(\.size), sizes)
    XCTAssertEqual(frames.map(\.midX), [0, 0, 0])
    XCTAssertEqual(frames[0].minY - frames[1].maxY, CanvasMath.itemGap)
    XCTAssertEqual(frames[1].minY - frames[2].maxY, CanvasMath.itemGap)
    XCTAssertTrue(RecentWindowOrder.frames(sizes: []).isEmpty)
  }
}

@MainActor
final class ChronologicalModeTests: XCTestCase {
  func testModeAndAnimatedCameraNeverOverwriteFreeDesktop() throws {
    let defaults = UserDefaults.standard
    let keys = ["desktopPages", "chronologicalMode", "chronologicalCamera", "viewMode"]
    let backup = keys.map { defaults.object(forKey: $0) }
    defer { for (key, value) in zip(keys, backup) { defaults.set(value, forKey: key) } }
    defaults.removeObject(forKey: "viewMode")
    defaults.set(false, forKey: "chronologicalMode")
    let original = DesktopPages(pages: [DesktopPage(title: "Keep me",
      camera: CameraState(center: CGPoint(x: 1600, y: -700), zoom: 0.3),
      appPlacements: [AppPlacement(bundleIdentifier: "com.apple.finder", applicationName: "Finder",
        home: CGPoint(x: 2222, y: 3333), lastKnownSize: CGSize(width: 800, height: 600), windowSlots: [])])])
    defaults.set(try JSONEncoder().encode(original), forKey: "desktopPages")
    let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 1600, height: 1000))
    defer { canvas.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: canvas) }
    canvas.setChronological(true)
    canvas.camera = CameraState(center: CGPoint(x: 0, y: -9000), zoom: 0.7)
    canvas.animateCamera(to: CameraState(center: CGPoint(x: 0, y: -12000), zoom: 0.7)) {}
    canvas.persistState()
    let stored = try JSONDecoder().decode(DesktopPages.self, from: XCTUnwrap(defaults.data(forKey: "desktopPages")))
    XCTAssertEqual(stored, original)
    canvas.setChronological(false)
    XCTAssertEqual(canvas.camera, original.selectedPage.camera)
    canvas.setChronological(true)
    XCTAssertEqual(canvas.camera.zoom, 0.7)
    XCTAssertTrue(defaults.bool(forKey: "chronologicalMode"))
    canvas.persistState()
    let reopened = CanvasView(frame: canvas.frame)
    defer { reopened.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: reopened) }
    XCTAssertTrue(reopened.isChronological)
    reopened.setChronological(false)
    XCTAssertEqual(reopened.camera, original.selectedPage.camera)
  }
  func testApplicationGridRendersSyntheticAppsAcrossViewport() throws {
    let defaults = UserDefaults.standard
    let keys = ["desktopPages", "chronologicalMode", "chronologicalCamera", "viewMode"]
    let backup = keys.map { defaults.object(forKey: $0) }
    defer { for (key, value) in zip(keys, backup) { defaults.set(value, forKey: key) } }
    defaults.removeObject(forKey: "viewMode")
    defaults.set(true, forKey: "chronologicalMode")
    let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    defer { _ = canvas.closeCatalog(); canvas.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: canvas) }
    canvas.prepareChronologicalOverview()
    canvas.selectPresentation(at: 3)
    canvas.updateCatalog((0..<15).map { InstalledApp(id: "synthetic.\($0)", name: "Example application with a very long name \($0 + 1)",
      url: URL(fileURLWithPath: "/System/Applications/Calculator.app")) })
    canvas.synchronizeScene()
    XCTAssertEqual(canvas.camera.zoom, 1)
    let cards = try XCTUnwrap(canvas.cameraLayer.sublayers)
    XCTAssertEqual(cards.count, 15)
    let expected = CanvasMath.applicationGridFrames(count: 15, viewport: canvas.bounds.size, topInset: canvas.catalogTopInset)
    for (card, frame) in zip(cards, expected) { XCTAssertEqual(card.position, frame.origin) }
    let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 800,
      pixelsHigh: 600, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
    context.cgContext.setFillColor(NSColor.darkGray.cgColor)
    context.cgContext.fill(canvas.bounds)
    context.cgContext.translateBy(x: 400, y: 300)
    canvas.cameraLayer.render(in: context.cgContext)
    try bitmap.representation(using: .png, properties: [:])?.write(
      to: URL(fileURLWithPath: "/tmp/openplane-appgrid-synthetic.png"))
    canvas.camera = CameraState(center: .zero, zoom: 0.3)
    canvas.synchronizeScene()
    for card in canvas.cameraLayer.sublayers ?? [] {
      let surface = try XCTUnwrap(card.sublayers?.first)
      let text = try XCTUnwrap(surface.sublayers?.compactMap { $0 as? CATextLayer }.first)
      XCTAssertFalse(text.isWrapped)
      XCTAssertEqual(text.truncationMode, .end)
      XCTAssertEqual(text.opacity, 0)
      XCTAssertEqual(surface.bounds.height, 64, accuracy: 0.01)
    }
    let compact = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 800,
      pixelsHigh: 600, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    let compactContext = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: compact))
    compactContext.cgContext.setFillColor(NSColor.darkGray.cgColor)
    compactContext.cgContext.fill(canvas.bounds)
    compactContext.cgContext.translateBy(x: 400, y: 300)
    compactContext.cgContext.scaleBy(x: 0.3, y: 0.3)
    canvas.cameraLayer.render(in: compactContext.cgContext)
    try compact.representation(using: .png, properties: [:])?.write(
      to: URL(fileURLWithPath: "/tmp/openplane-appgrid-compact-synthetic.png"))
  }

  func testCatalogBackAndViewportChangeKeepSelectionCamera() {
    let defaults = UserDefaults.standard
    let keys = ["desktopPages", "chronologicalMode", "chronologicalCamera", "viewMode"]
    let backup = keys.map { defaults.object(forKey: $0) }
    defer { for (key, value) in zip(keys, backup) { defaults.set(value, forKey: key) } }
    defaults.removeObject(forKey: "viewMode")
    defaults.set(true, forKey: "chronologicalMode")
    let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 1600, height: 1000))
    defer { canvas.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: canvas) }
    canvas.prepareChronologicalOverview()
    XCTAssertFalse(canvas.hasCanvasSelection) // Empty window list has no redundant catalog card.
    let before = canvas.camera
    canvas.stepRecent(by: 1, wrapping: true, windowsOnly: true)
    XCTAssertEqual(canvas.camera, before)
    canvas.selectPresentation(at: 3)
    XCTAssertTrue(canvas.showingAllApps)
    XCTAssertTrue(canvas.closeCatalog())
    XCTAssertFalse(canvas.closeCatalog())
    XCTAssertEqual(canvas.camera, before)
    XCTAssertFalse(canvas.hasCanvasSelection)
    let target = CameraState(center: CGPoint(x: 0, y: -6000), zoom: canvas.camera.zoom)
    canvas.animateCamera(to: target) {}
    canvas.setFrameSize(CGSize(width: 1200, height: 1000))
    canvas.layout()
    XCTAssertEqual(canvas.camera, target)
  }

}

final class WindowBackspaceActionTests: XCTestCase {
  func testUnavailableApplicationDoesNotCountAsDismissedDialog() async {
    let state = await CloseDialogObserver().state(processID: -1)
    XCTAssertEqual(state, .unavailable)
  }

  func testOnlyConfirmedLastWindowQuitsApplication() {
    XCTAssertEqual(WindowBackspaceAction.resolve(windowCount: 1), .quitApp)
    for count in [nil, 0, 2, 3, 20] as [Int?] {
      XCTAssertEqual(WindowBackspaceAction.resolve(windowCount: count), .closeWindow)
    }
  }

  func testBackspaceDoesNotRepeatAndDoesNotAcceptForwardDelete() {
    XCTAssertTrue(ShortcutMatcher.isPlaneBackspace(keyCode: 51, isRepeat: false))
    XCTAssertFalse(ShortcutMatcher.isPlaneBackspace(keyCode: 51, isRepeat: true))
    XCTAssertFalse(ShortcutMatcher.isPlaneBackspace(keyCode: 117, isRepeat: false))
  }
}


@MainActor
final class OverviewModeTests: XCTestCase {
  func testFocusControlsDisappearEarlyAndRestoreAtStart() {
    XCTAssertEqual(CanvasMath.focusControlsOpacity(progress: 0), 1)
    XCTAssertEqual(CanvasMath.focusControlsOpacity(progress: 1 / 6), 0.5, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.focusControlsOpacity(progress: 1 / 3), 0)
    XCTAssertEqual(CanvasMath.focusControlsOpacity(progress: 1), 0)
    XCTAssertGreaterThan(CanvasMath.focusBackdropOpacity(progress: 1 / 3), 0)
    XCTAssertEqual(CanvasMath.focusControlsOpacity(progress: 0), 1)
  }

  func testTransitionSpeedDefaultsAndBounds() {
    let defaults = UserDefaults.standard
    let key = OpenPlanePreferences.transitionSpeedKey
    let saved = defaults.object(forKey: key)
    defer { if let saved { defaults.set(saved, forKey: key) } else { defaults.removeObject(forKey: key) } }
    defaults.removeObject(forKey: key)
    XCTAssertEqual(OpenPlanePreferences.transitionDuration(0.6), 0.3)
    OpenPlanePreferences.transitionSpeed = 1
    XCTAssertEqual(OpenPlanePreferences.transitionDuration(0.45), 0.45)
    OpenPlanePreferences.transitionSpeed = 0
    XCTAssertEqual(OpenPlanePreferences.transitionSpeed, 0.5)
    OpenPlanePreferences.transitionSpeed = .infinity
    XCTAssertEqual(OpenPlanePreferences.transitionSpeed, 2)
  }

  func testToggleParityKeepsPressesDuringTransitions() {
    var queue = ToggleParityQueue()
    queue.recordPress()
    XCTAssertTrue(queue.consume(isTransitioning: false)) // start opening
    queue.recordPress()
    XCTAssertFalse(queue.consume(isTransitioning: true))
    XCTAssertTrue(queue.consume(isTransitioning: false)) // return after opening
    queue.recordPress()
    queue.recordPress()
    XCTAssertFalse(queue.consume(isTransitioning: true))
    XCTAssertFalse(queue.consume(isTransitioning: false)) // two cancel
    for _ in 0..<101 { queue.recordPress() }
    XCTAssertFalse(queue.consume(isTransitioning: true))
    XCTAssertTrue(queue.consume(isTransitioning: false))
    XCTAssertFalse(queue.consume(isTransitioning: false)) // consume once
  }

  func testRightCommandOnlyTogglesOnStandaloneRelease() {
    var tap = RightCommandTap()
    let right = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x10)
    XCTAssertFalse(tap.handle(type: .flagsChanged, keyCode: 54, flags: right))
    XCTAssertTrue(tap.handle(type: .flagsChanged, keyCode: 54, flags: []))
    XCTAssertFalse(tap.handle(type: .flagsChanged, keyCode: 54, flags: []))
    for event in [CGEventType.keyDown, .leftMouseDown, .flagsChanged] {
      XCTAssertFalse(tap.handle(type: .flagsChanged, keyCode: 54, flags: right))
      XCTAssertFalse(tap.handle(type: event, keyCode: 8, flags: right))
      XCTAssertFalse(tap.handle(type: .flagsChanged, keyCode: 54, flags: []))
    }
    XCTAssertFalse(tap.handle(type: .flagsChanged, keyCode: 55, flags: .maskCommand))
    XCTAssertFalse(tap.handle(type: .flagsChanged, keyCode: 55, flags: []))
    XCTAssertFalse(tap.handle(type: .flagsChanged, keyCode: 54, flags: right.union(.maskShift)))
    XCTAssertFalse(tap.handle(type: .flagsChanged, keyCode: 54, flags: []))
  }

  func testChromeTabCountsRequireUnambiguousWindowMatch() {
    let frame = CGRect(x: 20, y: 40, width: 800, height: 600)
    let window = ChromeTabWindow(title: "Example", frame: frame, count: 12)
    XCTAssertEqual(ChromeTabWindow.count(for: "Example", frame: frame, in: [window]), 12)
    XCTAssertNil(ChromeTabWindow.count(for: "Other", frame: frame, in: [window]))
    XCTAssertNil(ChromeTabWindow.count(for: "Example", frame: frame.offsetBy(dx: 20, dy: 0), in: [window]))
    XCTAssertNil(ChromeTabWindow.count(for: "Example", frame: frame, in: [window, window]))
    XCTAssertNil(ChromeTabWindow.count(for: "Example", frame: frame, in: []))
  }

  func testCatalogZoomStopsAtVisibleMinimumAndReversesImmediately() throws {
    let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
    let host = NSWindow(contentRect: canvas.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
    host.contentView = canvas
    host.orderFront(nil)
    defer { host.orderOut(nil) }
    defer { _ = canvas.closeCatalog(); canvas.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: canvas) }
    canvas.selectPresentation(at: 3)
    canvas.camera = CameraState(center: .zero, zoom: 0.06)
    XCTAssertEqual(canvas.camera.zoom, CanvasMath.applicationMinimumZoom)
    func tap(_ code: UInt16) throws {
      for type: NSEvent.EventType in [.keyDown, .keyUp] {
        let event = try XCTUnwrap(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [.shift],
          timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
          isARepeat: false, keyCode: code))
        if type == .keyDown { XCTAssertTrue(canvas.handleNavigationKey(event)) }
        else { XCTAssertTrue(canvas.handleNavigationKeyUp(event)) }
      }
    }
    for _ in 0..<20 { try tap(126) }
    XCTAssertEqual(canvas.camera.zoom, CanvasMath.applicationMinimumZoom)
    try tap(125)
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    XCTAssertGreaterThan(canvas.camera.zoom, CanvasMath.applicationMinimumZoom)
  }

  func testTabCyclesViewsAndReverseWithoutChangingSavedDesktops() throws {
    let defaults = UserDefaults.standard
    let keys = ["viewMode", "chronologicalMode", "desktopPages", "chronologicalCamera"]
    let backup = keys.map { defaults.object(forKey: $0) }
    defer { for (key, value) in zip(keys, backup) { defaults.set(value, forKey: key) } }
    defaults.removeObject(forKey: "viewMode")
    defaults.removeObject(forKey: "chronologicalMode")
    let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
    defer { _ = canvas.closeCatalog(); canvas.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: canvas) }
    XCTAssertEqual(canvas.viewMode, .overview)
    canvas.selectPresentation(at: 1)
    canvas.selectPresentation(at: 2) // Materialize the initially unset Canvas camera.
    canvas.selectPresentation(at: 1)
    let saved = try JSONDecoder().decode(DesktopPages.self, from: XCTUnwrap(defaults.data(forKey: "desktopPages")))
    func tab(_ flags: NSEvent.ModifierFlags = [], repeatKey: Bool = false) throws {
      let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
        timestamp: 0, windowNumber: 0, context: nil, characters: "\t", charactersIgnoringModifiers: "\t",
        isARepeat: repeatKey, keyCode: 48))
      XCTAssertTrue(canvas.handleNavigationKey(event))
    }
    for key in ["chronological", "allApps", "overview", "canvas"] {
      try tab()
      XCTAssertEqual(canvas.presentationKey, key)
    }
    try tab([.shift])
    XCTAssertEqual(canvas.presentationKey, "overview")
    try tab([], repeatKey: true)
    XCTAssertEqual(canvas.presentationKey, "overview")
    XCTAssertEqual(try JSONDecoder().decode(DesktopPages.self, from: XCTUnwrap(defaults.data(forKey: "desktopPages"))), saved)
  }

  func testViewPillClickAndRapidReverseSettleOnSelectedButton() throws {
    let control = ViewModeControl(labels: ["Canvas", "Recent", "Overview", "All apps"])
    let host = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 500, height: 80),
      styleMask: [.borderless], backing: .buffered, defer: false)
    defer { host.orderOut(nil) }
    control.frame = CGRect(x: 8, y: 8, width: control.preferredWidth, height: 44)
    host.contentView!.addSubview(control)
    host.orderFront(nil)
    control.layoutSubtreeIfNeeded()
    let buttons = control.subviews.compactMap { $0 as? NSButton }
    let highlight = try XCTUnwrap(control.subviews.first)
    buttons[3].performClick(nil)
    XCTAssertEqual(control.selectedSegment, 3)
    RunLoop.main.run(until: Date().addingTimeInterval(0.08))
    buttons[0].performClick(nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.35))
    XCTAssertEqual(control.selectedSegment, 0)
    XCTAssertEqual(highlight.frame, buttons[0].frame)
    XCTAssertEqual(highlight.layer?.cornerRadius, 10)
    XCTAssertLessThan(control.preferredWidth, 500)
  }

  func testCompactNavigatorDragClampsAndPersists() throws {
    let defaults = UserDefaults.standard
    let keys = ["viewMode", "chronologicalMode", "desktopPages", "navigatorPanelX", "navigatorPanelY"]
    let backup = keys.map { defaults.object(forKey: $0) }
    defer { for (key, value) in zip(keys, backup) { defaults.set(value, forKey: key) } }
    for key in keys { defaults.removeObject(forKey: key) }
    defaults.set("canvas", forKey: "viewMode")
    let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
    defer { canvas.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: canvas) }
    canvas.setViewMode(.overview)
    canvas.layout()
    let original = canvas.navigatorPanelFrame
    XCTAssertGreaterThanOrEqual(original.minY, 96)
    XCTAssertLessThan(canvas.searchOverlayFrame.maxX, canvas.positionOverlayFrame.minX)
    XCTAssertFalse(canvas.positionOverlayFrame.intersects(original))
    let search = try XCTUnwrap(canvas.subviews.compactMap { $0 as? NSTextField }.first {
      $0.action == NSSelectorFromString("openSearchResult:")
    })
    XCTAssertFalse(search.isHidden)
    search.stringValue = "Example"
    canvas.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search))
    XCTAssertTrue(canvas.dismissSearch())
    XCTAssertFalse(search.isHidden)
    XCTAssertEqual(search.stringValue, "")
    func drag(by delta: CGPoint) throws {
      let frame = canvas.navigatorPanelFrame
      let start = CGPoint(x: frame.midX, y: frame.maxY - 24)
      let end = CGPoint(x: start.x + delta.x, y: start.y + delta.y)
      func event(_ type: NSEvent.EventType, _ point: CGPoint) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
          timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0))
      }
      XCTAssertTrue(canvas.hitTest(start) === canvas)
      canvas.mouseDown(with: try event(.leftMouseDown, start))
      canvas.mouseDragged(with: try event(.leftMouseDragged, end))
      canvas.mouseUp(with: try event(.leftMouseUp, end))
    }
    try drag(by: CGPoint(x: -140, y: 150))
    XCTAssertEqual(canvas.navigatorPanelFrame.minX, original.minX - 140, accuracy: 0.1)
    XCTAssertEqual(canvas.navigatorPanelFrame.minY, original.minY + 150, accuracy: 0.1)
    XCTAssertFalse(canvas.overviewAvailableFrame.intersects(canvas.navigatorPanelFrame))
    let reopened = CanvasView(frame: canvas.frame)
    defer { reopened.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: reopened) }
    XCTAssertEqual(reopened.navigatorPanelFrame, canvas.navigatorPanelFrame)
    try drag(by: CGPoint(x: 0, y: 1000))
    XCTAssertLessThanOrEqual(canvas.navigatorPanelFrame.maxY, canvas.bounds.maxY - 48)
    XCTAssertFalse(canvas.overviewAvailableFrame.intersects(canvas.navigatorPanelFrame))
    try drag(by: CGPoint(x: 0, y: -1000))
    XCTAssertEqual(canvas.navigatorPanelFrame.minY, 96, accuracy: 0.1)
  }

  func testSeparateOverlaysAndSavedPositionStayIndependentAcrossViews() throws {
    let defaults = UserDefaults.standard
    let keys = ["viewMode", "desktopPages", "navigatorPanelX", "navigatorPanelY"]
      + CanvasView.presentationKeys.map { "savedOverlayCamera.\($0)" }
    let backup = keys.map { defaults.object(forKey: $0) }
    defer { for (key, value) in zip(keys, backup) { defaults.set(value, forKey: key) } }
    for key in keys { defaults.removeObject(forKey: key) }
    let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    defer { canvas.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: canvas) }
    canvas.setViewMode(.overview)
    canvas.layout()
    let before = defaults.data(forKey: "desktopPages")
    XCTAssertTrue(NSApp.sendAction(NSSelectorFromString("toggleLockedView:"), to: canvas, from: NSButton()))
    let saved = try XCTUnwrap(defaults.data(forKey: "savedOverlayCamera.overview"))
    XCTAssertEqual(try JSONDecoder().decode(CameraState.self, from: saved), canvas.camera)
    XCTAssertEqual(defaults.data(forKey: "desktopPages"), before)
    canvas.setViewMode(.chronological)
    XCTAssertNil(defaults.data(forKey: "savedOverlayCamera.chronological"))
    XCTAssertEqual(defaults.data(forKey: "savedOverlayCamera.overview"), saved)
    for width: CGFloat in [480, 800, 1200] {
      canvas.setFrameSize(CGSize(width: width, height: 600))
      canvas.layout()
      XCTAssertFalse(canvas.searchOverlayFrame.intersects(canvas.positionOverlayFrame))
      XCTAssertFalse(canvas.searchOverlayFrame.intersects(canvas.navigatorPanelFrame))
      XCTAssertFalse(canvas.positionOverlayFrame.intersects(canvas.navigatorPanelFrame))
      XCTAssertLessThanOrEqual(canvas.navigatorPanelFrame.maxX, width)
      XCTAssertLessThanOrEqual(canvas.positionOverlayFrame.maxX, width)
    }
  }

  func testSettingsKeyboardNavigationAndSearchShortcut() throws {
    let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
    canvas.setViewMode(.overview)
    let host = CanvasWorkspaceView(canvas: canvas)
    let window = NSWindow(contentRect: host.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host
    window.orderFront(nil)
    defer { _ = canvas.dismissSettings(); canvas.cancelLayoutAnimation(); window.orderOut(nil); NSObject.cancelPreviousPerformRequests(withTarget: canvas) }
    func press(_ code: UInt16, _ modifiers: NSEvent.ModifierFlags = []) throws {
      let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
        timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code))
      XCTAssertTrue(canvas.handleNavigationKey(event))
    }
    try press(43, .command)
    XCTAssertTrue(host.isSettingsVisible)
    RunLoop.main.run(until: Date().addingTimeInterval(0.25))
    let mode = canvas.viewMode, camera = canvas.camera
    try press(36) // Views
    try press(36) // first view detail
    XCTAssertTrue(window.firstResponder is NSTextView, "Name must be keyboard-editable on entering a view")
    try press(48)
    XCTAssertEqual(canvas.viewMode, mode)
    XCTAssertEqual(canvas.camera, camera)
    try press(48, .shift)
    XCTAssertTrue(window.firstResponder is NSTextView)
    try press(53) // Views
    try press(53) // General
    XCTAssertTrue(host.isSettingsVisible)
    try press(48) // shortcut recorder, not a Canvas view change
    XCTAssertTrue(window.firstResponder is OverviewShortcutRecorder)
    try press(48, .shift) // back to Views
    XCTAssertEqual(canvas.viewMode, mode)
    try press(3, .command)
    XCTAssertFalse(host.isSettingsVisible)
    let search = try XCTUnwrap(canvas.subviews.compactMap { $0 as? NSTextField }.first { $0.action == NSSelectorFromString("openSearchResult:") })
    XCTAssertTrue(search.currentEditor() === window.firstResponder)
    XCTAssertTrue(canvas.dismissSearch())
    try press(43, .command)
    RunLoop.main.run(until: Date().addingTimeInterval(0.25))
    if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
      host.cacheDisplay(in: host.bounds, to: bitmap)
      try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "/tmp/openplane-keyboard-settings-synthetic.png"))
    }
    try press(43, .command)
    XCTAssertFalse(host.isSettingsVisible)
  }

  func testSettingsTextEditorDoesNotTriggerCanvasSearch() throws {
    let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    let window = NSWindow(contentRect: canvas.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = canvas
    let editor = NSTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
    canvas.addSubview(editor)
    XCTAssertTrue(window.makeFirstResponder(editor))
    defer { canvas.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: canvas); window.contentView = nil }
    for code: UInt16 in [14, 36, 51, 125] {
      let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
        timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "e", charactersIgnoringModifiers: "e", isARepeat: false, keyCode: code))
      XCTAssertFalse(canvas.handleNavigationKey(event))
    }
  }

  func testViewNamesPanDefaultsAndPromptValidation() throws {
    let defaults = UserDefaults.standard
    let keys = ["viewMode", "chronologicalMode", "desktopPages", "chronologicalCamera"]
      + CanvasView.presentationKeys.flatMap { ["viewName.\($0)", "canPanCanvas.\($0)", "viewPrompt.\($0)", "cameraFollowsSelection.\($0)"] }
    let backup = keys.map { defaults.object(forKey: $0) }
    defer { for (key, value) in zip(keys, backup) { defaults.set(value, forKey: key) } }
    for key in keys { defaults.removeObject(forKey: key) }
    defaults.set("canvas", forKey: "viewMode")
    let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
    defer { _ = canvas.closeCatalog(); canvas.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: canvas) }
    canvas.selectPresentation(at: 0)
    XCTAssertFalse(canvas.canPanCanvas)
    let fixed = canvas.camera
    canvas.panCanvas(deltaX: 100, deltaY: 100)
    XCTAssertEqual(canvas.camera, fixed)
    canvas.renameCurrentPresentation("Fokus")
    XCTAssertEqual(canvas.presentationControl.label(forSegment: 0), "Fokus")
    canvas.setCanvasPanning(true)
    canvas.panCanvas(deltaX: 100, deltaY: 100)
    XCTAssertNotEqual(canvas.camera, fixed)
    canvas.selectPresentation(at: 3)
    XCTAssertFalse(canvas.canPanCanvas)
    canvas.updateCatalog((0..<100).map { InstalledApp(id: "synthetic.\($0)", name: "App \($0)", url: URL(fileURLWithPath: "/tmp/nonexistent.app")) })
    canvas.panCanvas(deltaX: 200, deltaY: -200)
    XCTAssertEqual(canvas.camera.center.x, 0)
    XCTAssertLessThan(canvas.camera.center.y, 0)
    canvas.selectPresentation(at: 1)
    XCTAssertTrue(canvas.canPanCanvas)
    canvas.selectPresentation(at: 3)
    XCTAssertFalse(canvas.canPanCanvas)
    let plan = ViewPromptPlan(name: "Arbeit", layout: "overview", canPan: false, followSelection: false)
    canvas.applyViewPrompt(plan, prompt: "Alles gleichzeitig sichtbar")
    XCTAssertEqual(canvas.viewMode, .overview)
    XCTAssertFalse(canvas.canPanCanvas)
    XCTAssertEqual(canvas.presentationName("overview"), "Arbeit")
    XCTAssertEqual(defaults.string(forKey: "viewPrompt.overview"), "Alles gleichzeitig sichtbar")
    XCTAssertThrowsError(try ViewPromptPlan(name: "X", layout: "run code", canPan: true, followSelection: true).validated())
    XCTAssertThrowsError(try ViewPromptClient.decodeResponse(Data("{\"status\":\"incomplete\",\"output\":[]}".utf8)))
    let body = ViewPromptClient.requestBody(prompt: "Test")
    XCTAssertEqual(body["store"] as? Bool, false)
    XCTAssertEqual(body["input"] as? String, "Test")
  }

  func testShortcutValidationAndSerialization() throws {
    XCTAssertTrue(ShortcutMatcher.isOverviewSwipe(deltaX: 0, deltaY: 1))
    XCTAssertFalse(ShortcutMatcher.isOverviewSwipe(deltaX: 0, deltaY: -1))
    XCTAssertFalse(ShortcutMatcher.isOverviewSwipe(deltaX: 1, deltaY: 0))
    XCTAssertFalse(ShortcutMatcher.isOverviewSwipe(deltaX: 1, deltaY: 1))
    func key(_ code: UInt16, _ flags: NSEvent.ModifierFlags, repeated: Bool = false) throws -> NSEvent {
      try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
        timestamp: 0, windowNumber: 0, context: nil, characters: "p", charactersIgnoringModifiers: "p",
        isARepeat: repeated, keyCode: code))
    }
    XCTAssertNil(OverviewShortcut.from(try key(35, [])))
    XCTAssertNil(OverviewShortcut.from(try key(35, [.shift])))
    XCTAssertNil(OverviewShortcut.from(try key(48, [.command])))
    XCTAssertNil(OverviewShortcut.from(try key(12, [.command])))
    XCTAssertNil(OverviewShortcut.from(try key(35, [.control], repeated: true)))
    let candidate = try XCTUnwrap(OverviewShortcut.from(try key(35, [.control, .option, .shift])))
    XCTAssertEqual(candidate.label, "⌃⌥⇧P")
    XCTAssertEqual(candidate, try JSONDecoder().decode(OverviewShortcut.self, from: JSONEncoder().encode(candidate)))
  }

  func testVisibleCameraSwitchTracksModeChanges() throws {
    let defaults = UserDefaults.standard
    let keys = ["viewMode", "chronologicalMode", "desktopPages", "chronologicalCamera",
      "cameraFollowsSelection.overview", "cameraFollowsSelection.canvas"]
    let backup = keys.map { defaults.object(forKey: $0) }
    defer { for (key, value) in zip(keys, backup) { defaults.set(value, forKey: key) } }
    for key in keys { defaults.removeObject(forKey: key) }
    defaults.set("canvas", forKey: "viewMode")
    let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
    let host = CanvasWorkspaceView(canvas: canvas)
    defer { _ = canvas.dismissSettings(); canvas.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: canvas) }
    XCTAssertTrue(NSApp.sendAction(NSSelectorFromString("showSettings:"), to: canvas, from: NSButton()))
    func find(_ view: NSView) -> NSButton? {
      if view.identifier?.rawValue == "Camera follows selection" { return view as? NSButton }
      for child in view.subviews { if let result = find(child) { return result } }
      return nil
    }
    XCTAssertNil(find(host), "View-specific controls belong on the subpage")
    func recorder(_ view: NSView) -> OverviewShortcutRecorder? {
      if let result = view as? OverviewShortcutRecorder { return result }
      return view.subviews.compactMap { recorder($0) }.first
    }
    XCTAssertNotNil(recorder(host))
    func viewsButton(_ view: NSView) -> NSButton? {
      if let button = view as? NSButton, button.action == NSSelectorFromString("openViews:") { return button }
      return view.subviews.compactMap { viewsButton($0) }.first
    }
    let entry = try XCTUnwrap(viewsButton(host))
    entry.performClick(nil)
    XCTAssertNil(find(host), "Views list must not expose editing controls")
    func detailButton(_ view: NSView) -> NSButton? {
      if let button = view as? NSButton, button.action == NSSelectorFromString("openView:"), button.tag == 1 { return button }
      return view.subviews.compactMap { detailButton($0) }.first
    }
    host.frame = CGRect(x: 0, y: 0, width: 1200, height: 800)
    host.layoutSubtreeIfNeeded()
    if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
      host.cacheDisplay(in: host.bounds, to: bitmap)
      try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "/tmp/openplane-settings-list-synthetic.png"))
    }
    try XCTUnwrap(detailButton(host)).performClick(nil)
    let control = try XCTUnwrap(find(host))
    XCTAssertEqual(control.state, .on)
    XCTAssertNil(recorder(host), "Global shortcuts stay on the main Settings page")
    host.frame = CGRect(x: 0, y: 0, width: 1200, height: 800)
    host.layoutSubtreeIfNeeded()
    if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
      host.cacheDisplay(in: host.bounds, to: bitmap)
      try bitmap.representation(using: .png, properties: [:])?.write(
        to: URL(fileURLWithPath: "/tmp/openplane-shortcut-settings-synthetic.png"))
    }
    canvas.setViewMode(.overview)
    XCTAssertEqual(control.state, .off)
    canvas.setViewMode(.canvas)
    XCTAssertEqual(control.state, .on)
    canvas.selectPresentation(at: 3)
    XCTAssertTrue(canvas.navigateBackInSettings())
    XCTAssertNotNil(detailButton(host))
    XCTAssertNil(find(host))
    XCTAssertTrue(canvas.navigateBackInSettings())
    XCTAssertNotNil(recorder(host))
    XCTAssertNil(find(host))
    XCTAssertFalse(canvas.navigateBackInSettings())
    host.layoutSubtreeIfNeeded()
    if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
      host.cacheDisplay(in: host.bounds, to: bitmap)
      try bitmap.representation(using: .png, properties: [:])?.write(
        to: URL(fileURLWithPath: "/tmp/openplane-settings-root-synthetic.png"))
    }
    canvas.selectPresentation(at: 1)
  }

  func testGroupedWindowsNavigationCameraAndCanvasRestoration() throws {
    let defaults = UserDefaults.standard
    let keys = ["desktopPages", "chronologicalMode", "chronologicalCamera", "viewMode",
      "cameraFollowsSelection.overview", "cameraFollowsSelection.canvas", "cameraFollowsSelection.chronological"]
    let backup = keys.map { defaults.object(forKey: $0) }
    defer { for (key, value) in zip(keys, backup) { defaults.set(value, forKey: key) } }
    for key in keys { defaults.removeObject(forKey: key) }
    defaults.set("canvas", forKey: "viewMode")
    let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
    defer { canvas.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: canvas) }
    let nodes = (0..<7).map { index -> WindowNode in
      let size = CGSize(width: index == 5 ? 600 : 1000, height: 700)
      let item = DiscoveredWindow(id: CGWindowID(index + 1), processID: pid_t(index / 3 + 90000),
        bundleIdentifier: "synthetic.\(index / 3)", applicationName: "Example App \(index / 3 + 1)",
        title: "Example window \(index + 1)", isPrivateBrowsing: false,
        frame: CGRect(origin: .zero, size: size), icon: NSImage(systemSymbolName: "app.fill", accessibilityDescription: "Synthetic icon"), captureWindow: nil, accessibilityElement: nil)
      let preview = NSImage(size: size, flipped: false) { rect in
        NSColor(calibratedHue: CGFloat(index) / 9, saturation: 0.35, brightness: 0.65, alpha: 1).setFill()
        rect.fill()
        ("Synthetic window \(index + 1)" as NSString).draw(at: CGPoint(x: 60, y: 100),
          withAttributes: [.font: NSFont.systemFont(ofSize: 36), .foregroundColor: NSColor.white])
        return true
      }
      return WindowNode(discovered: item,
        worldFrame: CGRect(x: CGFloat(index) * 1300, y: 250, width: size.width, height: size.height),
        cachedPreview: preview)
    }
    canvas.nodes = nodes
    let original = nodes.map(\.worldFrame)
    canvas.setViewMode(.overview)
    XCTAssertFalse(canvas.followsSelection)
    let overviewCamera = canvas.camera
    let frames = nodes.map(\.worldFrame)
    let entryFrames = Dictionary(uniqueKeysWithValues: nodes.map { node in
      (node.id, CGRect(x: CGFloat(node.id) * 20, y: 60, width: 800, height: 500))
    })
    canvas.animateOverviewEntry(from: entryFrames, frontToBack: nodes.map(\.id).reversed())
    if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
      let card = try XCTUnwrap(canvas.cameraLayer.sublayers?.first { $0.name == "window:1" })
      let animation = try XCTUnwrap(card.animation(forKey: "overviewEntry") as? CAAnimationGroup)
      let position = try XCTUnwrap(animation.animations?.first as? CABasicAnimation)
      let start = CanvasMath.worldRect(for: entryFrames[1]!, camera: canvas.camera, bounds: canvas.bounds)
      XCTAssertEqual((position.fromValue as? NSValue)?.pointValue, start.origin)
      XCTAssertEqual((position.toValue as? NSValue)?.pointValue, nodes[0].worldFrame.origin)
      let depth = try XCTUnwrap(animation.animations?.last as? CABasicAnimation)
      XCTAssertEqual(depth.keyPath, "zPosition")
      XCTAssertEqual(depth.fromValue as? CGFloat, 1)
      XCTAssertEqual(depth.toValue as? CGFloat, 1)
      let frontCard = try XCTUnwrap(canvas.cameraLayer.sublayers?.first { $0.name == "window:7" })
      let frontAnimation = try XCTUnwrap(frontCard.animation(forKey: "overviewEntry") as? CAAnimationGroup)
      let frontDepth = try XCTUnwrap(frontAnimation.animations?.last as? CABasicAnimation)
      XCTAssertEqual(frontDepth.fromValue as? CGFloat, 7)
      let finalDepth = card.zPosition
      XCTAssertEqual(nodes.map(\.worldFrame), frames, "Entry animation must not overwrite stored layout")
      canvas.cancelLayoutAnimation()
      XCTAssertNil(card.animation(forKey: "overviewEntry"))
      XCTAssertEqual(card.zPosition, finalDepth)
    }
    for frame in frames {
      let displayed = CanvasMath.viewRect(for: frame, camera: canvas.camera, bounds: canvas.bounds)
      XCTAssertTrue(canvas.overviewAvailableFrame.contains(displayed))
      let decorated = CanvasMath.previewVisualBounds(for: displayed, zoom: canvas.camera.zoom,
        titleLift: 0, borderOutset: 6)
      XCTAssertTrue(canvas.overviewAvailableFrame.contains(decorated), "Headers and selection border must clear the nudge too")
    }
    XCTAssertLessThanOrEqual(canvas.overviewAvailableFrame.maxY,
      canvas.bounds.maxY - CanvasMath.desktopTitleNudgeLayout(safeAreaTop: 32).depth)
    XCTAssertGreaterThan(frames[1].minX, frames[0].minX)
    XCTAssertLessThan(frames[1].maxY, frames[0].maxY)
    func press(_ code: UInt16) throws {
      let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
        timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
        isARepeat: false, keyCode: code))
      XCTAssertTrue(canvas.handleNavigationKey(event))
    }
    try press(125)
    XCTAssertEqual(canvas.selectedWindowID, 2)
    XCTAssertEqual(canvas.camera, overviewCamera)
    try press(125)
    XCTAssertEqual(canvas.selectedWindowID, 3)
    try press(126)
    XCTAssertEqual(canvas.selectedWindowID, 2)
    XCTAssertEqual(canvas.camera, overviewCamera)
    func frontmost(_ id: CGWindowID, over others: [CGWindowID]) {
      canvas.synchronizeScene()
      let layers = canvas.cameraLayer.sublayers ?? []
      let front = layers.first { $0.name == "window:\(id)" }!
      for other in others {
        XCTAssertGreaterThan(front.zPosition, layers.first { $0.name == "window:\(other)" }!.zPosition)
      }
    }
    func visibleTitles(_ layer: CALayer, inheritedOpacity: Float = 1) -> [String] {
      let opacity = inheritedOpacity * layer.opacity
      guard !layer.isHidden, opacity > 0.9 else { return [] }
      let own = ((layer as? CATextLayer)?.string as? NSAttributedString)?.string
      return (own.map { [$0] } ?? []) + (layer.sublayers ?? []).flatMap {
        visibleTitles($0, inheritedOpacity: opacity)
      }
    }
    for id: CGWindowID in [1, 3, 2] {
      canvas.selectedWindowID = id
      canvas.synchronizeScene()
      let header = try XCTUnwrap(canvas.cameraLayer.sublayers?.first { $0.name == "stack-header:synthetic.0" })
      XCTAssertTrue(visibleTitles(header).contains { $0.contains("Example window \(id)") },
        "First, last and middle window must show their title")
    }
    frontmost(2, over: [1, 3])
    let selectedCard = try XCTUnwrap(canvas.cameraLayer.sublayers?.first { $0.name == "window:2" })
    let matte = try XCTUnwrap(selectedCard.sublayers?.first { $0.name == "selection-matte" })
    XCTAssertFalse(matte.isHidden)
    XCTAssertEqual(matte.backgroundColor?.alpha, 1)
    XCTAssertEqual(matte.frame.minX, -4, "Fill must preserve the original outline spacing")
    let otherCard = try XCTUnwrap(canvas.cameraLayer.sublayers?.first { $0.name == "window:1" })
    XCTAssertTrue(try XCTUnwrap(otherCard.sublayers?.first { $0.name == "selection-matte" }).isHidden)
    try press(125)
    XCTAssertEqual(canvas.selectedWindowID, 3)
    let arranged = nodes.map(\.worldFrame)
    for (i, node) in nodes.enumerated() {
      node.worldFrame = CGRect(x: 0, y: i < 3 ? 2000 : i < 6 ? 1000 : 0, width: 500, height: 400)
    }
    try press(125)
    XCTAssertEqual(canvas.selectedWindowID, 4, "Down exits the last sibling into the next row")
    canvas.selectedWindowID = 7
    try press(126)
    XCTAssertEqual(canvas.selectedWindowID, 4, "A single-window stack must not trap vertical navigation")
    try press(126)
    XCTAssertEqual(canvas.selectedWindowID, 3, "Returning to a stack restores its remembered front")
    for (node, frame) in zip(nodes, arranged) { node.worldFrame = frame }
    canvas.selectedWindowID = 4
    frontmost(3, over: [1, 2])
    canvas.selectedWindowID = 2
    let history = HistoryNavigationProbe()
    canvas.delegate = history
    canvas.backNavigationTarget = nodes[0]
    canvas.layoutSubtreeIfNeeded()
    let back = try XCTUnwrap(canvas.subviews.compactMap { $0 as? NSButton }.first {
      $0.action == NSSelectorFromString("openPreviousApp:")
    })
    func click(_ point: CGPoint) throws {
      for type: NSEvent.EventType in [.leftMouseDown, .leftMouseUp] {
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
          timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        if type == .leftMouseDown { canvas.mouseDown(with: event) } else { canvas.mouseUp(with: event) }
      }
    }
    back.performClick(nil)
    XCTAssertEqual(history.backRequests, 1)
    XCTAssertEqual(canvas.selectedWindowID, 1)
    XCTAssertEqual(canvas.camera, overviewCamera, "History must honor fixed Overview camera")
    XCTAssertFalse(canvas.nativeCameraTravel)
    try press(125)
    XCTAssertEqual(canvas.selectedWindowID, 2, "Arrows remain usable after history selection")
    let selectedRect = CanvasMath.viewRect(for: nodes[1].worldFrame, camera: canvas.camera, bounds: canvas.bounds)
    try click(CGPoint(x: selectedRect.midX, y: selectedRect.maxY - 10))
    XCTAssertEqual(history.focused, [2], "Selected preview remains clickable after Back")
    canvas.selectHistoryWindow(999999)
    XCTAssertEqual(canvas.selectedWindowID, 2, "Missing history window must not break selection")
    canvas.layoutSubtreeIfNeeded()
    if let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) {
      canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
      try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "/tmp/openplane-overlays-synthetic.png"))
    }
    let previousTabPreference = UserDefaults.standard.object(forKey: ChromeTabCounter.preferenceKey)
    UserDefaults.standard.set(true, forKey: ChromeTabCounter.preferenceKey)
    defer { UserDefaults.standard.set(previousTabPreference, forKey: ChromeTabCounter.preferenceKey) }
    canvas.chromeTabCounts = [1: 12]
    nodes[0].title = "Example window 1 · " + String(repeating: "Long browser page title ", count: 12)
    canvas.selectedWindowID = 1
    canvas.layoutSubtreeIfNeeded()
    canvas.synchronizeScene()
    let countedHeader = try XCTUnwrap(canvas.cameraLayer.sublayers?.first { $0.name == "stack-header:synthetic.0" })
    XCTAssertTrue(visibleTitles(countedHeader).contains { $0.hasPrefix("1 von 3 · 12 Tabs · ") })

    let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1200,
      pixelsHigh: 800, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
    context.cgContext.setFillColor(NSColor.darkGray.cgColor); context.cgContext.fill(canvas.bounds)
    context.cgContext.concatenate(CGAffineTransform(a: canvas.camera.zoom, b: 0, c: 0,
      d: canvas.camera.zoom, tx: 600 - canvas.camera.center.x * canvas.camera.zoom,
      ty: 400 - canvas.camera.center.y * canvas.camera.zoom))
    canvas.cameraLayer.render(in: context.cgContext)
    context.cgContext.concatenate(CGAffineTransform(a: canvas.camera.zoom, b: 0, c: 0,
      d: canvas.camera.zoom, tx: 600 - canvas.camera.center.x * canvas.camera.zoom,
      ty: 400 - canvas.camera.center.y * canvas.camera.zoom).inverted())
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSGraphicsContext.restoreGraphicsState()
    var captionPixels = 0
    // This fixture's header strip is above the card border; metadata alone missed blank long titles.
    for y in 185..<202 { for x in 100..<395 {
      if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
        color.redComponent > 0.8, color.greenComponent > 0.8, color.blueComponent < 0.4 {
        captionPixels += 1
      }
    } }
    XCTAssertGreaterThan(captionPixels, 20, "Long caption must actually draw pixels, not just have a string")
    try bitmap.representation(using: .png, properties: [:])?.write(
      to: URL(fileURLWithPath: "/tmp/openplane-overview-synthetic.png"))
    canvas.selectedWindowID = 2
    try press(124)
    XCTAssertNotEqual(canvas.selectedWindowID, 2)
    XCTAssertEqual(canvas.camera, overviewCamera)
    canvas.setCameraFollowsSelection(true)
    XCTAssertTrue(canvas.followsSelection)
    canvas.setViewMode(.chronological)
    XCTAssertTrue(canvas.followsSelection)
    canvas.setViewMode(.canvas)
    XCTAssertEqual(nodes.map(\.worldFrame), original)
    canvas.setViewMode(.overview)
    XCTAssertTrue(canvas.followsSelection)
    canvas.setCameraFollowsSelection(false)
    canvas.setFrameSize(CGSize(width: 800, height: 600)); canvas.layout()
    for node in nodes {
      XCTAssertTrue(canvas.overviewAvailableFrame.contains(CanvasMath.viewRect(for: node.worldFrame, camera: canvas.camera, bounds: canvas.bounds)))
    }
    canvas.applyPreviewSizePreference(fitAll: true)
    for node in nodes {
      XCTAssertTrue(canvas.overviewAvailableFrame.contains(
        CanvasMath.viewRect(for: node.worldFrame, camera: canvas.camera, bounds: canvas.bounds)))
    }
    let stableCamera = canvas.camera
    canvas.nodes = nodes
    XCTAssertEqual(canvas.camera, stableCamera, "Unchanged inventory must not refit the view")
    canvas.persistState()
    let reopened = CanvasView(frame: canvas.frame)
    defer { reopened.cancelLayoutAnimation(); NSObject.cancelPreviousPerformRequests(withTarget: reopened) }
    XCTAssertEqual(reopened.viewMode, .overview)
    XCTAssertFalse(reopened.followsSelection)
    canvas.selectedWindowID = 2
    canvas.recentWindows.used(3)
    canvas.nodes = nodes.filter { $0.id != 2 }
    XCTAssertEqual(canvas.selectedWindowID, 3, "Closed front falls back to most recently used sibling")
    canvas.synchronizeScene()
    XCTAssertFalse(canvas.cameraLayer.sublayers?.contains { $0.name == "window:2" } ?? false)
    let stack = try XCTUnwrap(canvas.cameraLayer.sublayers?.first { $0.name == "stack-header:synthetic.0" })
    func text(_ layer: CALayer) -> [String] {
      let own = (layer as? CATextLayer)?.string as? NSAttributedString
      return (own.map { [$0.string] } ?? []) + (layer.sublayers ?? []).flatMap { text($0) }
    }
    XCTAssertTrue(text(stack).contains { $0.contains("von 2 ·") })
    canvas.nodes = []
    canvas.synchronizeScene()
    XCTAssertFalse(canvas.hasCanvasSelection)
    XCTAssertFalse(canvas.cameraLayer.sublayers?.contains { $0.name?.hasPrefix("stack-header:") == true } ?? false)
  }
}


@MainActor
private final class HistoryNavigationProbe: CanvasViewDelegate {
  var backRequests = 0
  var focused: [CGWindowID] = []
  func canvasView(_ canvasView: CanvasView, didRequestFocus node: WindowNode) { focused.append(node.id) }
  func canvasViewDidRequestBack(_ canvasView: CanvasView) {
    backRequests += 1
    canvasView.selectHistoryWindow(1)
  }
  func canvasViewDidRequestForward(_ canvasView: CanvasView) { canvasView.selectHistoryWindow(2) }
  func canvasView(_ canvasView: CanvasView, didRequestQuit node: WindowNode) { XCTFail("Unexpected quit") }
  func canvasView(_ canvasView: CanvasView, didRequestLaunch bundleIdentifier: String, applicationName: String, at anchor: CGPoint) { XCTFail("Unexpected launch") }
  func canvasView(_ canvasView: CanvasView, setCommandTabShortcut enabled: Bool) -> Bool { false }
  func canvasView(_ canvasView: CanvasView, setPrivateBrowserPreviews enabled: Bool) {}
}
