import XCTest

@testable import OpenPlane

final class CanvasMathTests: XCTestCase {
  func testDesktopPagesRenameNavigateAndLockIndependentViews() throws {
    let firstCamera = CameraState(center: CGPoint(x: 10, y: 20), zoom: 0.5)
    let secondCamera = CameraState(center: CGPoint(x: 800, y: 20), zoom: 0.6)
    var desktops = DesktopPages()

    desktops.renameSelectedPage("Focus")
    desktops.updateSelectedCamera(firstCamera)
    let firstID = desktops.selectedID
    XCTAssertTrue(desktops.toggleSelectedPageLock(at: firstCamera))

    let second = desktops.addPage(camera: secondCamera)
    XCTAssertEqual(second.title, "Desktop 2")
    XCTAssertEqual(desktops.selectedPage.camera, secondCamera)
    XCTAssertFalse(desktops.isSelectedPageLocked)

    XCTAssertEqual(desktops.select(firstID), firstCamera)
    XCTAssertEqual(desktops.selectedPage.displayTitle, "Focus")
    XCTAssertEqual(desktops.selectedPage.lockedCamera, firstCamera)

    let data = try JSONEncoder().encode(desktops)
    let decoded = try JSONDecoder().decode(DesktopPages.self, from: data)
    XCTAssertEqual(decoded, desktops)
  }

  func testCommandTabMatcherOnlyClaimsTheSystemSwitcherShortcut() {
    XCTAssertTrue(ShortcutMatcher.isCommandTab(keyCode: 48, flags: [.maskCommand]))
    XCTAssertTrue(
      ShortcutMatcher.isCommandTab(keyCode: 48, flags: [.maskCommand, .maskShift]))
    XCTAssertFalse(
      ShortcutMatcher.isCommandTab(keyCode: 48, flags: [.maskCommand, .maskAlternate]))
    XCTAssertFalse(ShortcutMatcher.isCommandTab(keyCode: 49, flags: [.maskCommand]))
  }

  func testCanvasChromeScalesAndFadesAtBirdsEyeZoom() {
    XCTAssertEqual(CanvasMath.appIconScale(at: 0.06), 0.5, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.appIconScale(at: 0.18), 1, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.titleVisibility(at: 0.06, availableWidth: 100), 0, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.titleVisibility(at: 0.09, availableWidth: 100), 0, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.titleVisibility(at: 0.10, availableWidth: 100), 0.5, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.titleVisibility(at: 0.14, availableWidth: 72), 1, accuracy: 0.001)
    XCTAssertEqual(CanvasMath.titleVisibility(at: 1, availableWidth: 32), 0, accuracy: 0.001)
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

  func testMarqueeSelectionAndGroupTranslationUseCanvasCoordinates() {
    let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 800)
    let camera = CameraState(center: .zero, zoom: 0.5)
    let frames: [CGWindowID: CGRect] = [
      1: CGRect(x: -100, y: -100, width: 200, height: 200),
      2: CGRect(x: 600, y: 400, width: 200, height: 200),
    ]
    let marquee = CanvasMath.selectionRect(
      from: CGPoint(x: 560, y: 460),
      to: CGPoint(x: 430, y: 330)
    )

    XCTAssertEqual(
      CanvasMath.windowIDs(
        intersecting: marquee,
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
      CGRect(x: 78, y: 90, width: 234, height: 138)
    )
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
    let candidates: [(id: CGWindowID, center: CGPoint)] = [
      (1, CGPoint(x: -100, y: 10)),
      (2, CGPoint(x: 100, y: 10)),
      (3, CGPoint(x: 5, y: 100)),
      (4, CGPoint(x: 5, y: -100)),
      (5, CGPoint(x: 40, y: 100)),
    ]

    XCTAssertEqual(
      CanvasMath.directionalNeighbor(from: .zero, candidates: candidates, direction: .left), 1)
    XCTAssertEqual(
      CanvasMath.directionalNeighbor(from: .zero, candidates: candidates, direction: .right), 2)
    XCTAssertEqual(
      CanvasMath.directionalNeighbor(from: .zero, candidates: candidates, direction: .up), 3)
    XCTAssertEqual(
      CanvasMath.directionalNeighbor(from: .zero, candidates: candidates, direction: .down), 4)
  }
}
