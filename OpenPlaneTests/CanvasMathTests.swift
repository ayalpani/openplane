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
    XCTAssertTrue(ShortcutMatcher.isPlaneQuit(keyCode: 51, isRepeat: false))
    XCTAssertFalse(ShortcutMatcher.isPlaneQuit(keyCode: 51, isRepeat: true))
    XCTAssertFalse(ShortcutMatcher.isPlaneQuit(keyCode: 117, isRepeat: false))
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

  func testSelectionMovesTitleBeforeShowingBorder() {
    let start = CanvasMath.selectionAnimationPhases(progress: 0)
    let titleReady = CanvasMath.selectionAnimationPhases(progress: 0.55)
    let end = CanvasMath.selectionAnimationPhases(progress: 1)

    XCTAssertEqual(start.title, 0, accuracy: 0.001)
    XCTAssertEqual(start.border, 0, accuracy: 0.001)
    XCTAssertEqual(titleReady.title, 1, accuracy: 0.001)
    XCTAssertEqual(titleReady.border, 0, accuracy: 0.001)
    XCTAssertEqual(end.title, 1, accuracy: 0.001)
    XCTAssertEqual(end.border, 1, accuracy: 0.001)
    let synchronized = CanvasMath.selectionAnimationPhases(
      progress: 0.25,
      synchronized: true
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
    XCTAssertEqual(
      CanvasMath.selectionHandoffPhase(progress: 0.5, incoming: false),
      1,
      accuracy: 0.001
    )
    XCTAssertEqual(
      CanvasMath.selectionHandoffPhase(progress: 0.5, incoming: true),
      0,
      accuracy: 0.001
    )
    XCTAssertEqual(
      CanvasMath.selectionHandoffPhase(
        progress: 0.5,
        incoming: true,
        synchronized: true
      ),
      CanvasMath.easedTransition(0.5),
      accuracy: 0.001
    )
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
      "Preview hidden for a private browsing window."
    )
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
