import AppKit
import XCTest

@testable import OpenPlane

@MainActor
final class CanvasSelectionTests: XCTestCase {
  private let bundles = ["com.apple.finder", "com.apple.TextEdit", "com.apple.Preview"]
  private let viewport = CGRect(x: 0, y: 0, width: 2_000, height: 1_600)

  // Exercise the actual event handlers, not a second implementation of selection.
  private func withCanvas(_ check: (CanvasView, SelectionDelegate) throws -> Void) throws {
    let defaults = UserDefaults.standard
    let previous = defaults.object(forKey: "desktopPages")
    let previousMode = defaults.object(forKey: "viewMode")
    let previousChronological = defaults.object(forKey: "chronologicalMode")
    defaults.set("canvas", forKey: "viewMode")
    defaults.set(false, forKey: "chronologicalMode")
    let placements = bundles.enumerated().map { index, bundle in
      AppPlacement(
        bundleIdentifier: bundle, applicationName: bundle,
        home: CGPoint(x: CGFloat(index - 1) * 2_800, y: 0),
        lastKnownSize: viewport.size, windowSlots: []
      )
    }
    let page = DesktopPage(
      title: "Selection fixture", camera: CameraState(center: .zero, zoom: 0.125),
      appPlacements: placements
    )
    defaults.set(try JSONEncoder().encode(DesktopPages(pages: [page])), forKey: "desktopPages")
    let canvas = CanvasView(frame: viewport)
    let delegate = SelectionDelegate()
    canvas.delegate = delegate
    defer {
      NSObject.cancelPreviousPerformRequests(withTarget: canvas)
      defaults.set(previous, forKey: "desktopPages")
      defaults.set(previousMode, forKey: "viewMode")
      defaults.set(previousChronological, forKey: "chronologicalMode")
    }
    try check(canvas, delegate)
  }

  func testQReturnsToOriginWithoutActivatingSelectionOrRepeating() throws {
    try withCanvas { canvas, delegate in
      func key(_ code: UInt16, repeatKey: Bool = false) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 1,
          windowNumber: 0, context: nil, characters: "q", charactersIgnoringModifiers: "q",
          isARepeat: repeatKey, keyCode: code)!
      }
      XCTAssertTrue(canvas.handleNavigationKey(key(124)))
      XCTAssertTrue(canvas.handleNavigationKey(key(12)))
      XCTAssertEqual(delegate.originReturns, 1)
      XCTAssertTrue(delegate.launched.isEmpty)
      XCTAssertTrue(canvas.handleNavigationKey(key(12, repeatKey: true)))
      XCTAssertEqual(delegate.originReturns, 1)
      let search = try XCTUnwrap(canvas.subviews.compactMap { $0 as? NSTextField }.first {
        $0.action == NSSelectorFromString("openSearchResult:")
      })
      search.stringValue = "q"
      canvas.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search))
      XCTAssertFalse(canvas.handleNavigationKey(key(12)))
      XCTAssertEqual(delegate.originReturns, 1)
    }
  }

  func testInterruptedFocusTransitionNotifiesOnceAndNormalCompletionDoesNot() throws {
    try withCanvas { canvas, delegate in
      var staleCompletion = false
      canvas.animateCamera(to: canvas.camera, isolating: 123, duration: 10) { staleCompletion = true }
      canvas.cancelLayoutAnimation()
      XCTAssertEqual(delegate.cancelledFocusTransitions, 1)
      XCTAssertFalse(staleCompletion, "Cancellation must not activate the abandoned target")
      canvas.cancelLayoutAnimation()
      XCTAssertEqual(delegate.cancelledFocusTransitions, 1)
      canvas.animateCamera(to: canvas.camera, isolating: 123, duration: 10) {}
      canvas.animateCamera(to: canvas.camera, duration: 10) {}
      XCTAssertEqual(delegate.cancelledFocusTransitions, 2, "Replacing focus with layout must release the focus state")
      canvas.cancelLayoutAnimation()
      canvas.animateCamera(to: canvas.camera, isolating: 123, duration: 10) {}
      canvas.endFocusTransition(completed: true)
      canvas.cancelLayoutAnimation()
      XCTAssertEqual(delegate.cancelledFocusTransitions, 2)
    }
  }

  func testMiniMapViewportTracksPresentedCameraDuringTravel() throws {
    let defaults = UserDefaults.standard
    let mode = defaults.object(forKey: "viewMode")
    defaults.set("canvas", forKey: "viewMode")
    defer { defaults.set(mode, forKey: "viewMode") }
    try withCanvas { canvas, _ in
      let host = NSWindow(contentRect: canvas.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
      host.contentView = canvas
      host.orderFront(nil)
      defer { canvas.cancelLayoutAnimation(); host.orderOut(nil) }
      canvas.layoutSubtreeIfNeeded()
      canvas.synchronizeScene()
      RunLoop.main.run(until: Date().addingTimeInterval(0.05))
      canvas.camera = CameraState(center: .zero, zoom: 0.45)
      let cases = [CameraState(center: CGPoint(x: 8000, y: 3000), zoom: 0.45),
        CameraState(center: CGPoint(x: -2000, y: -1000), zoom: 0.2),
        CameraState(center: CGPoint(x: 3000, y: 800), zoom: 0.6)]
      for target in cases {
      canvas.animateCamera(to: target, duration: 0.8) {}
      for _ in 0..<6 {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        let main = try XCTUnwrap(canvas.cameraLayer.presentation()).affineTransform()
        let map = try XCTUnwrap(canvas.miniMapContent.presentation()).affineTransform()
        let actual = try XCTUnwrap(canvas.miniMapViewport.presentation()?.path).boundingBoxOfPath
        let expected = canvas.bounds.applying(main.inverted()).applying(map)
        let error = max(abs(actual.minX - expected.minX), abs(actual.minY - expected.minY),
          abs(actual.maxX - expected.maxX), abs(actual.maxY - expected.maxY))
        print("MINIMAP_SYNC zoom=\(target.zoom) error_pt=\(error)")
        XCTAssertLessThan(error, 0.5)
      }
      }
    }
  }

  func testCameraTranslationReusesCardContents() throws {
    try withCanvas { canvas, _ in
      canvas.synchronizeScene()
      let count = canvas.sceneContentUpdates
      let cards = canvas.cameraLayer.sublayers ?? []
      XCTAssertEqual(cards.count, 3)
      for step in 1...100 {
        canvas.camera.center = CGPoint(x: CGFloat(step) * 31, y: CGFloat(step) * -17)
      }
      XCTAssertEqual(canvas.sceneContentUpdates, count)
      XCTAssertEqual(canvas.cameraLayer.sublayers, cards)
      let transform = canvas.cameraLayer.affineTransform()
      for point in [CGPoint.zero, CGPoint(x: 2800, y: -1600)] {
        let actual = point.applying(transform)
        let expected = CanvasMath.worldToView(point, camera: canvas.camera, bounds: canvas.bounds)
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.0001)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.0001)
      }
      canvas.synchronizeScene()
      XCTAssertEqual(canvas.sceneContentUpdates, count)
    }
  }

  func testCameraMaintenanceCoalescesMovementAndPersistsFinalCamera() throws {
    try withCanvas { canvas, _ in
      let initial = UserDefaults.standard.data(forKey: "desktopPages")
      for step in 1...100 {
        canvas.camera.center.x = CGFloat(step) * 31
      }
      XCTAssertEqual(canvas.cameraMaintenanceStarts, 1)
      XCTAssertEqual(canvas.cameraMaintenanceRuns, 0)
      XCTAssertEqual(UserDefaults.standard.data(forKey: "desktopPages"), initial)
      RunLoop.main.run(until: Date().addingTimeInterval(0.75))
      XCTAssertEqual(canvas.cameraMaintenanceRuns, 1)
      let data = try XCTUnwrap(UserDefaults.standard.data(forKey: "desktopPages"))
      let saved = try JSONDecoder().decode(DesktopPages.self, from: data)
      XCTAssertEqual(saved.selectedPage.camera, canvas.camera)
      canvas.camera.center.x += 1
      XCTAssertEqual(canvas.cameraMaintenanceStarts, 2)
    }
  }

  func testArrowReleaseDoesNotAdvanceSelectionAgain() throws {
    try withCanvas { canvas, delegate in
      func key(_ type: NSEvent.EventType, _ code: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [], timestamp: 1,
          windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
          isARepeat: false, keyCode: code)!
      }
      XCTAssertTrue(canvas.handleNavigationKey(key(.keyDown, 124))) // nearest: TextEdit
      XCTAssertFalse(canvas.handleNavigationKey(key(.keyUp, 124)))
      XCTAssertFalse(canvas.handleNavigationKeyUp(key(.keyUp, 124)))
      canvas.focusSelectedWindow()
      XCTAssertEqual(delegate.launched, [bundles[1]])
      XCTAssertTrue(canvas.handleNavigationKey(key(.keyDown, 124))) // next: Preview
      XCTAssertFalse(canvas.handleNavigationKey(key(.keyUp, 124)))
      canvas.focusSelectedWindow()
      XCTAssertEqual(delegate.launched, [bundles[1], bundles[2]])
    }
  }

  func testArrowSelectionDoesNotRefreshUnrelatedCardsOrInvalidateWholeCanvas() throws {
    try withCanvas { canvas, _ in
      canvas.synchronizeScene()
      canvas.needsDisplay = false
      let fullSizeViews = canvas.subviews.filter { $0.frame == canvas.bounds }
      for view in fullSizeViews { view.needsDisplay = false }
      let contentCount = canvas.sceneContentUpdates
      let arrow = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
        timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
        isARepeat: false, keyCode: 124)!
      XCTAssertTrue(canvas.handleNavigationKey(arrow))  // Select the nearest card first.
      let count = canvas.sceneCardUpdates
      XCTAssertTrue(canvas.handleNavigationKey(arrow))  // Then its right-hand neighbour.
      XCTAssertEqual(canvas.sceneCardUpdates - count, 2)
      XCTAssertEqual(canvas.sceneContentUpdates, contentCount)
      XCTAssertFalse(canvas.needsDisplay)
      XCTAssertTrue(fullSizeViews.allSatisfy { !$0.needsDisplay })
    }
  }

  func testNativeCameraTravelCompletesAndInterruptsWithoutFrameCallbacks() throws {
    try withCanvas { canvas, _ in
      canvas.synchronizeScene()
      let target = CameraState(center: CGPoint(x: 2800, y: 700), zoom: canvas.camera.zoom)
      var completions = 0
      canvas.animateCamera(to: target, duration: 0.05) { completions += 1 }
      XCTAssertTrue(canvas.nativeCameraTravel)
      XCTAssertNotNil(canvas.cameraLayer.animation(forKey: "cameraTravel"))
      XCTAssertNotEqual(canvas.camera, target)
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
      XCTAssertEqual(canvas.camera, target)
      XCTAssertFalse(canvas.nativeCameraTravel)
      XCTAssertEqual(completions, 1)
      XCTAssertEqual(canvas.cameraFrameCallbacks, 0)

      canvas.animateCamera(to: CameraState(center: .zero, zoom: target.zoom), duration: 0.2) {
        XCTFail("Interrupted animation must not complete")
      }
      RunLoop.main.run(until: Date().addingTimeInterval(0.025))
      let interrupted = canvas.camera
      canvas.animateCamera(to: target, duration: 0.05) { completions += 1 }
      XCTAssertEqual(canvas.camera.center.x, interrupted.center.x, accuracy: 40)
      RunLoop.main.run(until: Date().addingTimeInterval(0.25))
      XCTAssertEqual(canvas.camera, target)
      XCTAssertEqual(completions, 2)
      XCTAssertEqual(canvas.cameraFrameCallbacks, 0)

      canvas.animateCamera(to: CameraState(center: .zero, zoom: target.zoom), duration: 0.05) {
        XCTFail("Direct camera assignment must cancel the animation")
      }
      canvas.camera = target
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
      XCTAssertEqual(canvas.camera, target)
      XCTAssertFalse(canvas.nativeCameraTravel)
    }
  }

  func testSavingOrResizingDuringNativeTravelKeepsTheCurrentCamera() throws {
    try withCanvas { canvas, _ in
      canvas.synchronizeScene()
      let target = CameraState(center: CGPoint(x: 2800, y: 700), zoom: canvas.camera.zoom)
      canvas.animateCamera(to: target, duration: 0.2) { XCTFail("Save cancelled this flight") }
      RunLoop.main.run(until: Date().addingTimeInterval(0.025))
      canvas.persistState()
      XCTAssertFalse(canvas.nativeCameraTravel)
      let saved = try JSONDecoder().decode(DesktopPages.self,
        from: XCTUnwrap(UserDefaults.standard.data(forKey: "desktopPages")))
      XCTAssertEqual(saved.selectedPage.camera, canvas.camera)
      XCTAssertNotEqual(canvas.camera, target)

      canvas.animateCamera(to: target, duration: 0.05) { XCTFail("Resize cancelled this flight") }
      canvas.setFrameSize(CGSize(width: 1200, height: 900))
      canvas.layoutSubtreeIfNeeded()
      XCTAssertFalse(canvas.nativeCameraTravel)
      let position = canvas.camera.center.applying(canvas.cameraLayer.affineTransform())
      XCTAssertEqual(position.x, canvas.bounds.midX, accuracy: 0.001)
      XCTAssertEqual(position.y, canvas.bounds.midY, accuracy: 0.001)
      RunLoop.main.run(until: Date().addingTimeInterval(0.25))
    }
  }

  func testRapidCameraReversalsPreserveNonBinaryZoom() throws {
    try withCanvas { canvas, _ in
      let window = NSWindow(contentRect: viewport, styleMask: [.borderless],
        backing: .buffered, defer: false)
      window.isReleasedWhenClosed = false
      window.contentView = canvas
      window.orderFront(nil)
      defer { window.close() }
      let zoom: CGFloat = 0.1655411772
      canvas.camera = CameraState(center: .zero, zoom: zoom)
      canvas.synchronizeScene()
      let contentUpdates = canvas.sceneContentUpdates
      for index in 0..<6 {
        let target = CameraState(center: CGPoint(x: index.isMultiple(of: 2) ? 2800 : 0, y: 700),
          zoom: zoom)
        canvas.animateCamera(to: target, duration: 0.18) {}
        RunLoop.main.run(until: Date().addingTimeInterval(0.04))
        XCTAssertNotNil(canvas.cameraLayer.presentation())
        XCTAssertTrue(canvas.nativeCameraTravel)
        XCTAssertEqual(canvas.camera.zoom, zoom)
      }
      RunLoop.main.run(until: Date().addingTimeInterval(0.2))
      XCTAssertEqual(canvas.cameraFrameCallbacks, 0)
      XCTAssertEqual(canvas.sceneContentUpdates, contentUpdates)
    }
  }

  func testZoomPreservesWorldCoordinatesAndLayerIdentity() throws {
    try withCanvas { canvas, _ in
      canvas.synchronizeScene()
      let cards = canvas.cameraLayer.sublayers ?? []
      for zoom in [0.06, 0.17, 0.5, 1.25] {
        canvas.camera.zoom = zoom
        XCTAssertEqual(canvas.cameraLayer.sublayers, cards)
        for card in cards {
          XCTAssertEqual(card.affineTransform().a * canvas.cameraLayer.affineTransform().a, 1, accuracy: 0.0001)
        }
      }
    }
  }

  func testGridToggleRestoresDotsAtCurrentZoom() throws {
    let defaults = UserDefaults.standard
    let previous = defaults.object(forKey: "showGrid")
    defaults.removeObject(forKey: "showGrid")
    defer { defaults.set(previous, forKey: "showGrid") }
    try withCanvas { canvas, _ in
      canvas.camera.zoom = 0.3
      let grid = try XCTUnwrap(canvas.subviews.flatMap { $0.layer?.sublayers ?? [] }
        .first { $0 is CAReplicatorLayer })
      let tile = try XCTUnwrap(grid.sublayers?.first?.sublayers?.first)
      XCTAssertFalse(grid.isHidden, "Dots remain enabled by default")
      let original = try XCTUnwrap(tile.contents as AnyObject?)
      let item = NSMenuItem()
      canvas.perform(NSSelectorFromString("toggleGrid:"), with: item)
      XCTAssertTrue(grid.isHidden)
      canvas.camera.zoom = 0.7
      XCTAssertTrue(grid.isHidden)
      XCTAssertTrue(tile.contents as AnyObject? === original, "Disabled dots must skip raster work")
      canvas.perform(NSSelectorFromString("toggleGrid:"), with: item)
      XCTAssertFalse(grid.isHidden)
      XCTAssertFalse(tile.contents as AnyObject? === original, "Re-enabling must refresh the tile")
      XCTAssertEqual(canvas.camera.zoom, 0.7)
      canvas.camera.zoom = 0.06
      XCTAssertTrue(grid.isHidden, "Existing low-zoom fade threshold is preserved")
    }
  }

  func testDebugOverlaySurvivesRepeatedZoomRedraws() throws {
    let defaults = UserDefaults.standard
    let previous = defaults.object(forKey: "showDebugInformation")
    defaults.set(true, forKey: "showDebugInformation")
    defer { defaults.set(previous, forKey: "showDebugInformation") }
    try withCanvas { canvas, _ in
      let hud = try XCTUnwrap(canvas.subviews.filter { $0.frame == canvas.bounds }.last)
      let rect = CGRect(x: 0, y: canvas.bounds.maxY - 60, width: 180, height: 60)
      let bitmap = try XCTUnwrap(hud.bitmapImageRepForCachingDisplay(in: rect))
      var firstImage: Data?
      for step in 0..<1_200 {
        autoreleasepool {
          canvas.camera.zoom = 0.06 + CGFloat(step % 120) / 100
          hud.cacheDisplay(in: rect, to: bitmap)
          if step == 0 { firstImage = bitmap.representation(using: .png, properties: [:]) }
        }
      }
      XCTAssertNotNil(firstImage)
      XCTAssertNotEqual(firstImage, bitmap.representation(using: .png, properties: [:]),
        "The debug label must still update across zoom values, not freeze to avoid the crash")
    }
  }

  private func key(_ code: UInt16 = 36, repeated: Bool = false) -> NSEvent {
    NSEvent.keyEvent(
      with: .keyDown, location: .zero, modifierFlags: [.shift], timestamp: 0,
      windowNumber: 0, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
      isARepeat: repeated, keyCode: code
    )!
  }

  private func mouse(_ type: NSEvent.EventType, at point: CGPoint, shift: Bool = false) -> NSEvent {
    NSEvent.mouseEvent(
      with: type, location: point, modifierFlags: shift ? [.shift] : [], timestamp: 0,
      windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0
    )!
  }

  private func center(_ index: Int, in canvas: CanvasView) -> CGPoint {
    CanvasMath.worldToView(
      CGPoint(x: CGFloat(index - 1) * 2_800, y: 0), camera: canvas.camera, bounds: viewport
    )
  }

  private func click(_ point: CGPoint, in canvas: CanvasView, shift: Bool = true) {
    canvas.mouseDown(with: mouse(.leftMouseDown, at: point, shift: shift))
    canvas.mouseUp(with: mouse(.leftMouseUp, at: point, shift: shift))
  }

  private func drag(_ start: CGPoint, to end: CGPoint, in canvas: CanvasView) {
    canvas.mouseDown(with: mouse(.leftMouseDown, at: start))
    canvas.mouseDragged(with: mouse(.leftMouseDragged, at: end))
    canvas.mouseUp(with: mouse(.leftMouseUp, at: end))
  }

  private func assertBounds(
    _ canvas: CanvasView, indices: [Int], primary: Int? = nil,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    let rects = indices.map { index in
      let rect = CanvasMath.viewRect(
        for: CGRect(
          x: CGFloat(index - 1) * 2_800 - viewport.width / 2, y: -viewport.height / 2,
          width: viewport.width, height: viewport.height
        ), camera: canvas.camera, bounds: viewport
      )
      return CanvasMath.previewVisualBounds(
        for: rect, zoom: canvas.camera.zoom, titleLift: primary == index ? 6 : 4,
        borderOutset: primary == index ? 6 : 4
      )
    }
    let expected = CanvasMath.groupSelectionBounds(for: rects).map {
      CanvasMath.worldRect(for: $0, camera: canvas.camera, bounds: viewport)
    }
    XCTAssertEqual(canvas.groupSelectionWorldRect, expected, file: file, line: line)
  }

  private func assertRectEqual(
    _ actual: CGRect?, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line
  ) {
    guard let actual else { return XCTFail("Missing selection frame", file: file, line: line) }
    // Recomputed view/world coordinates can differ by floating-point rounding.
    XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.000001, file: file, line: line)
    XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.000001, file: file, line: line)
    XCTAssertEqual(actual.width, expected.width, accuracy: 0.000001, file: file, line: line)
    XCTAssertEqual(actual.height, expected.height, accuracy: 0.000001, file: file, line: line)
  }

  func testShiftClickAndShiftReturnToggleWithoutLaunchingIncludingSingleSelection() throws {
    try withCanvas { canvas, delegate in
      click(center(0, in: canvas), in: canvas)
      XCTAssertEqual(canvas.groupSelectionIDs, ["app:\(bundles[0])"])
      assertBounds(canvas, indices: [0], primary: 0)
      XCTAssertTrue(canvas.handleNavigationKey(key()))
      XCTAssertTrue(canvas.groupSelectionIDs.isEmpty)
      XCTAssertNil(canvas.groupSelectionWorldRect)
      // Keyboard alone can initiate a group on the still-highlighted item.
      XCTAssertTrue(canvas.handleNavigationKey(key()))
      click(center(1, in: canvas), in: canvas)
      XCTAssertEqual(canvas.groupSelectionIDs, Set(bundles.prefix(2).map { "app:\($0)" }))
      assertBounds(canvas, indices: [0, 1], primary: 1)
      XCTAssertTrue(canvas.handleNavigationKey(key(repeated: true)))
      XCTAssertEqual(canvas.groupSelectionIDs.count, 2)
      XCTAssertTrue(canvas.handleNavigationKey(key(76)))  // Keypad Return also toggles.
      assertBounds(canvas, indices: [0], primary: 1)
      click(center(0, in: canvas), in: canvas)
      assertBounds(canvas, indices: [])
      XCTAssertTrue(delegate.launched.isEmpty)
    }
  }

  func testResizedBoxSnapsToAllIncludedClosedCardsOnMouseUp() throws {
    try withCanvas { canvas, delegate in
      click(center(0, in: canvas), in: canvas)
      let original = CanvasMath.viewRect(
        for: try XCTUnwrap(canvas.groupSelectionWorldRect), camera: canvas.camera, bounds: viewport)
      let start = CGPoint(x: original.maxX, y: original.midY)
      let end = CGPoint(x: center(1, in: canvas).x + 160, y: start.y)
      canvas.mouseDown(with: mouse(.leftMouseDown, at: start))
      canvas.mouseDragged(with: mouse(.leftMouseDragged, at: end))
      let stretched = canvas.groupSelectionWorldRect
      XCTAssertEqual(canvas.groupSelectionIDs.count, 2)
      canvas.mouseUp(with: mouse(.leftMouseUp, at: end))
      XCTAssertNotEqual(canvas.groupSelectionWorldRect, stretched)
      assertBounds(canvas, indices: [0, 1], primary: 0)
      XCTAssertTrue(delegate.launched.isEmpty)
    }
  }

  func testMarqueeIncludesClosedCardsAndSnapsWithoutChangingPositions() throws {
    try withCanvas { canvas, delegate in
      drag(CGPoint(x: 480, y: 650), to: CGPoint(x: 1_200, y: 960), in: canvas)
      XCTAssertEqual(canvas.groupSelectionIDs, Set(bundles.prefix(2).map { "app:\($0)" }))
      assertBounds(canvas, indices: [0, 1])
      XCTAssertTrue(delegate.launched.isEmpty)
    }
  }

  func testFittedFrameTracksZoomWithoutScalingItsScreenPadding() throws {
    try withCanvas { canvas, _ in
      click(center(0, in: canvas), in: canvas)
      click(center(1, in: canvas), in: canvas)
      for zoom in [0.06, 0.09, 0.125, 0.18, 0.5, 1.25] {
        canvas.camera = CameraState(center: CGPoint(x: 145, y: -345), zoom: zoom)
        assertBounds(canvas, indices: [0, 1], primary: 1)
      }
    }
  }

  func testDraggingClosedMemberMovesWholeGroupAndPersistsOnlySelectedHomes() throws {
    try withCanvas { canvas, delegate in
      click(center(0, in: canvas), in: canvas)
      click(center(1, in: canvas), in: canvas)
      let originalBounds = try XCTUnwrap(canvas.groupSelectionWorldRect)
      let start = center(1, in: canvas)
      drag(start, to: CGPoint(x: start.x + 40, y: start.y - 20), in: canvas)
      assertRectEqual(canvas.groupSelectionWorldRect, originalBounds.offsetBy(dx: 320, dy: -160))
      let pages = try JSONDecoder().decode(
        DesktopPages.self, from: XCTUnwrap(UserDefaults.standard.data(forKey: "desktopPages")))
      for index in bundles.indices {
        let home = try XCTUnwrap(pages.selectedAppPlacement(for: bundles[index])).home
        XCTAssertEqual(
          home,
          CGPoint(x: CGFloat(index - 1) * 2_800 + (index < 2 ? 320 : 0), y: index < 2 ? -160 : 0))
      }
      // A normal refresh must not discard closed members or restore their old positions.
      canvas.nodes = []
      XCTAssertEqual(canvas.groupSelectionIDs.count, 2)
      assertRectEqual(canvas.groupSelectionWorldRect, originalBounds.offsetBy(dx: 320, dy: -160))
      XCTAssertTrue(delegate.launched.isEmpty)
    }
  }

  func testDraggingGroupBackgroundMovesClosedMembersWithoutLaunching() throws {
    try withCanvas { canvas, delegate in
      click(center(0, in: canvas), in: canvas)
      click(center(1, in: canvas), in: canvas)
      let original = try XCTUnwrap(canvas.groupSelectionWorldRect)
      // The gap between cards is part of the draggable group surface.
      drag(CGPoint(x: 825, y: 800), to: CGPoint(x: 850, y: 825), in: canvas)
      assertRectEqual(canvas.groupSelectionWorldRect, original.offsetBy(dx: 200, dy: 200))
      XCTAssertTrue(delegate.launched.isEmpty)
    }
  }

  func testUnselectedCardInsideGroupBoundsReceivesShiftClick() throws {
    try withCanvas { canvas, delegate in
      click(center(0, in: canvas), in: canvas)
      click(center(2, in: canvas), in: canvas)
      click(center(1, in: canvas), in: canvas)
      XCTAssertEqual(canvas.groupSelectionIDs, Set(bundles.map { "app:\($0)" }))
      click(center(1, in: canvas), in: canvas)
      XCTAssertEqual(canvas.groupSelectionIDs, ["app:\(bundles[0])", "app:\(bundles[2])"])
      XCTAssertTrue(delegate.launched.isEmpty)
    }
  }

  func testPlainClickStillLaunchesButDraggingSingleClosedCardDoesNot() throws {
    try withCanvas { canvas, delegate in
      let start = center(0, in: canvas)
      drag(start, to: CGPoint(x: start.x + 20, y: start.y), in: canvas)
      XCTAssertTrue(delegate.launched.isEmpty)
      click(CGPoint(x: start.x + 20, y: start.y), in: canvas, shift: false)
      XCTAssertEqual(delegate.launched, [bundles[0]])
    }
  }

  func testMarqueeUsesSameGeometryForOpenAndClosedIDsAtDifferentZooms() {
    let frames = [
      "window:1": CGRect(x: -300, y: 0, width: 200, height: 100),
      "app:closed": CGRect(x: 100, y: 0, width: 200, height: 100),
      "window:2": CGRect(x: 500, y: 0, width: 200, height: 100),
    ]
    for zoom in [0.06, 0.25, 1.25] {
      let camera = CameraState(center: CGPoint(x: 123, y: -456), zoom: zoom)
      let rect = CanvasMath.viewRect(
        for: CGRect(x: -400, y: -50, width: 800, height: 200), camera: camera, bounds: viewport)
      XCTAssertEqual(
        CanvasMath.itemIDs(containedIn: rect, frames: frames, camera: camera, bounds: viewport),
        ["window:1", "app:closed"])
    }
  }

  private func searchField(in canvas: CanvasView) throws -> NSTextField {
    try XCTUnwrap(canvas.subviews.compactMap { $0 as? NSTextField }.first {
      $0.accessibilityLabel() == "Search apps"
    })
  }

  private func startSearch(in canvas: CanvasView) throws -> NSTextField {
    let button = try XCTUnwrap(canvas.subviews.compactMap { $0 as? NSButton }.first {
      $0.action == NSSelectorFromString("showSearch:")
    })
    button.performClick(nil)
    return try searchField(in: canvas)
  }

  private func search(_ query: String, in canvas: CanvasView, field: NSTextField) {
    field.stringValue = query
    canvas.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
  }

  func testSearchFindsClosedAppAndReturnLaunchesOnlyMatchingSelectionOnce() throws {
    try withCanvas { canvas, delegate in
      let field = try startSearch(in: canvas)
      search("textedit", in: canvas, field: field)
      XCTAssertTrue(canvas.hasCanvasSelection)
      XCTAssertNil(canvas.selectedWindowID)
      XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(field.action), to: canvas, from: field))
      XCTAssertEqual(delegate.launched, [bundles[1]])
      _ = NSApp.sendAction(field.action!, to: canvas, from: field)
      XCTAssertEqual(delegate.launched.count, 1, "Return must not launch an opening app twice")

      search("no-app-matches-this", in: canvas, field: field)
      XCTAssertFalse(canvas.hasCanvasSelection)
      _ = NSApp.sendAction(field.action!, to: canvas, from: field)
      XCTAssertEqual(delegate.launched.count, 1)

      search("TextEdit", in: canvas, field: field)
      canvas.showLaunchError(for: bundles[1], message: "Test launch error")
      search("  ", in: canvas, field: field)
      _ = NSApp.sendAction(field.action!, to: canvas, from: field)
      XCTAssertEqual(delegate.launched.count, 1, "An empty search must not activate an old selection")
    }
  }

  func testSearchNavigatesClosedResultsWithoutWrappingOrLaunchingAndSurvivesRefresh() throws {
    try withCanvas { canvas, delegate in
      canvas.camera.center.x = -2_800 // Keep this synchronous event test free of camera animation.
      let field = try startSearch(in: canvas)
      search("e", in: canvas, field: field) // Finder, Preview, TextEdit, in the existing card order.
      let next = try XCTUnwrap(canvas.subviews.compactMap { $0 as? NSButton }.first {
        $0.accessibilityLabel() == "Next search result"
      })
      let previous = try XCTUnwrap(canvas.subviews.compactMap { $0 as? NSButton }.first {
        $0.accessibilityLabel() == "Previous search result"
      })
      XCTAssertTrue(next.isEnabled)
      XCTAssertFalse(previous.isEnabled)
      XCTAssertFalse(next.isHidden)
      XCTAssertTrue(previous.isHidden)
      canvas.layoutSubtreeIfNeeded()
      XCTAssertEqual(next.frame.minX, previous.frame.minX, "A single arrow must not leave an empty slot")
      canvas.camera.center.x = 2_800
      XCTAssertTrue(canvas.control(field, textView: NSTextView(), doCommandBy: #selector(NSResponder.moveDown(_:))))
      XCTAssertFalse(next.isHidden)
      XCTAssertFalse(previous.isHidden)
      canvas.layoutSubtreeIfNeeded()
      XCTAssertEqual(next.frame.minX, previous.frame.maxX)
      canvas.camera.center.x = 0
      next.performClick(nil)
      XCTAssertFalse(next.isEnabled)
      XCTAssertTrue(previous.isEnabled)
      XCTAssertTrue(next.isHidden)
      XCTAssertFalse(previous.isHidden)
      XCTAssertTrue(canvas.control(field, textView: NSTextView(), doCommandBy: #selector(NSResponder.moveDown(_:))))
      canvas.nodes = []
      XCTAssertFalse(next.isEnabled)
      XCTAssertTrue(next.isHidden)
      XCTAssertFalse(previous.isHidden)
      XCTAssertTrue(delegate.launched.isEmpty)
      _ = NSApp.sendAction(field.action!, to: canvas, from: field)
      XCTAssertEqual(delegate.launched, [bundles[1]], "The last closed result stays selected after refresh")
    }
  }

  func testSearchShowsOnlyClickableArrowsAsResultCountChanges() throws {
    try withCanvas { canvas, _ in
      let field = try startSearch(in: canvas)
      let next = try XCTUnwrap(canvas.subviews.compactMap { $0 as? NSButton }.first {
        $0.accessibilityLabel() == "Next search result"
      })
      let previous = try XCTUnwrap(canvas.subviews.compactMap { $0 as? NSButton }.first {
        $0.accessibilityLabel() == "Previous search result"
      })
      for query in ["", "TextEdit", "no-app-matches-this", " "] {
        search(query, in: canvas, field: field)
        XCTAssertTrue(next.isHidden, query)
        XCTAssertTrue(previous.isHidden, query)
        XCTAssertFalse(next.isEnabled, query)
        XCTAssertFalse(previous.isEnabled, query)
      }
      search("r", in: canvas, field: field) // Finder and Preview.
      XCTAssertFalse(next.isHidden)
      next.performClick(nil)
      XCTAssertFalse(previous.isHidden)
      XCTAssertTrue(next.isHidden)
      previous.performClick(nil)
      XCTAssertTrue(previous.isHidden)
      XCTAssertFalse(next.isHidden)
      search("Finder", in: canvas, field: field)
      XCTAssertTrue(next.isHidden)
      XCTAssertTrue(previous.isHidden)
      search("r", in: canvas, field: field)
      XCTAssertFalse(next.isHidden)
      XCTAssertTrue(canvas.dismissSearch())
      XCTAssertTrue(next.isHidden)
      XCTAssertTrue(previous.isHidden)
    }
  }

  func testSearchKeepsClosedCardsUnchangedForMatchesNonmatchesAndEmptyQuery() throws {
    try withCanvas { canvas, _ in
      @MainActor func cardColors() throws -> [NSColor] {
        canvas.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(canvas.bitmapImageRepForCachingDisplay(in: viewport))
        canvas.cacheDisplay(in: viewport, to: bitmap)
        return try [0, 1].map { index in
          // Sample the card surface away from its icon, text, selection border, and glow.
          let point = center(index, in: canvas)
          let x = Int((point.x + 40) * CGFloat(bitmap.pixelsWide) / viewport.width)
          let y = Int((viewport.height - point.y - 40) * CGFloat(bitmap.pixelsHigh) / viewport.height)
          return try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
        }
      }
      let original = try cardColors()
      let field = try startSearch(in: canvas)
      let empty = try cardColors()
      for index in original.indices {
        XCTAssertEqual(empty[index].redComponent, original[index].redComponent, accuracy: 0.005)
      }
      for query in ["TextEdit", "no-app-matches-this", "  "] {
        search(query, in: canvas, field: field)
        let filtered = try cardColors()
        for index in original.indices {
          XCTAssertEqual(filtered[index].redComponent, original[index].redComponent, accuracy: 0.015)
          XCTAssertEqual(filtered[index].greenComponent, original[index].greenComponent, accuracy: 0.015)
          XCTAssertEqual(filtered[index].blueComponent, original[index].blueComponent, accuracy: 0.015)
        }
      }
      XCTAssertTrue(canvas.dismissSearch())
      let restored = try cardColors()
      XCTAssertEqual(restored[0].redComponent, original[0].redComponent, accuracy: 0.005)
    }
  }
}

@MainActor
final class DesktopTabTests: XCTestCase {
  private func withCanvas(count: Int = 3, _ check: (CanvasView, [DesktopPage]) throws -> Void) throws {
    let defaults = UserDefaults.standard
    let previous = defaults.object(forKey: "desktopPages")
    let pages: [DesktopPage] = (0..<count).map { index in
      let position = CGFloat(index)
      let camera = CameraState(center: CGPoint(x: position * 8_000, y: position * -4_000), zoom: 0.1 + position * 0.1)
      return DesktopPage(
        title: "Workspace \(index + 1)",
        camera: camera,
        appPlacements: [AppPlacement(
          bundleIdentifier: "com.example.closed", applicationName: "Closed fixture",
          home: CGPoint(x: position * 9_000, y: position * 5_000),
          lastKnownSize: CGSize(width: 1_000, height: 800), windowSlots: []
        )]
      )
    }
    defaults.set(try JSONEncoder().encode(DesktopPages(pages: pages)), forKey: "desktopPages")
    let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 900, height: 700))
    canvas.layoutSubtreeIfNeeded()
    defer {
      // Cancel any real display link before restoring the isolated preferences.
      canvas.advanceDesktopTransition(to: 1)
      canvas.advanceDesktopTransition(to: 1)
      NSObject.cancelPreviousPerformRequests(withTarget: canvas)
      defaults.set(previous, forKey: "desktopPages")
    }
    try check(canvas, pages)
  }

  private func descendants(of view: NSView) -> [NSView] {
    view.subviews.flatMap { [$0] + descendants(of: $0) }
  }

  private func tab(_ index: Int, in canvas: CanvasView) throws -> NSButton {
    try XCTUnwrap(descendants(of: canvas).compactMap { $0 as? NSButton }.first {
      $0.tag == index && $0.action == NSSelectorFromString("selectDesktopTab:")
    })
  }

  private func savedPages() throws -> DesktopPages {
    try JSONDecoder().decode(
      DesktopPages.self, from: XCTUnwrap(UserDefaults.standard.data(forKey: "desktopPages")))
  }

  private func tabKey(modifiers: NSEvent.ModifierFlags = [], repeated: Bool = false) -> NSEvent {
    NSEvent.keyEvent(
      with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
      windowNumber: 0, context: nil, characters: "\t", charactersIgnoringModifiers: "\t",
      isARepeat: repeated, keyCode: 48
    )!
  }

  func testTabKeyCyclesDesktopsBothWaysWithFadeAndRestoresEachCamera() throws {
    try withCanvas { canvas, pages in
      for (modifiers, destinations): (NSEvent.ModifierFlags, [Int]) in [
        ([], [1, 2, 0]), ([.shift], [2, 1, 0]),
      ] {
        for index in destinations {
          XCTAssertTrue(canvas.handleNavigationKey(tabKey(modifiers: modifiers)))
          canvas.advanceDesktopTransition(to: 0.25)
          XCTAssertEqual(canvas.camera, pages[index].camera)
          canvas.advanceDesktopTransition(to: 0.5)
          XCTAssertEqual(canvas.camera, pages[index].camera)
          canvas.advanceDesktopTransition(to: 1)
          XCTAssertEqual(try savedPages().selectedID, pages[index].id)
          XCTAssertFalse(canvas.defersBackgroundWork)
        }
      }
      XCTAssertEqual(try savedPages().pages, pages)
    }
  }

  func testRapidTabPressesVisitEveryRequestedDesktopInOrder() throws {
    try withCanvas(count: 4) { canvas, pages in
      for _ in 0..<3 { XCTAssertTrue(canvas.handleNavigationKey(tabKey())) }
      XCTAssertEqual(canvas.camera, pages[1].camera)
      canvas.advanceDesktopTransition(to: 1)
      XCTAssertEqual(canvas.camera, pages[2].camera)
      canvas.advanceDesktopTransition(to: 1)
      XCTAssertEqual(canvas.camera, pages[3].camera)
      canvas.advanceDesktopTransition(to: 1)
      XCTAssertFalse(canvas.defersBackgroundWork)
      for _ in 0..<3 { XCTAssertTrue(canvas.handleNavigationKey(tabKey(modifiers: .shift))) }
      for index in [2, 1, 0] {
        XCTAssertEqual(canvas.camera, pages[index].camera)
        canvas.advanceDesktopTransition(to: 1)
      }
      XCTAssertEqual(try savedPages().pages, pages)
    }
  }

  func testPlusAddsDesktopAndTabOnlyVisitsExistingPages() throws {
    try withCanvas { canvas, _ in
      let plus = try XCTUnwrap(descendants(of: canvas).compactMap { $0 as? NSButton }.first {
        $0.toolTip == "New desktop (+)"
      })
      XCTAssertGreaterThan(plus.frame.minX, try tab(2, in: canvas).frame.maxX)
      let originalCamera = canvas.camera
      plus.performClick(nil)
      canvas.advanceDesktopTransition(to: 1)
      XCTAssertEqual(try savedPages().pages.count, 4)
      XCTAssertEqual(canvas.camera, originalCamera)
      let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.shift],
        timestamp: 0, windowNumber: 0, context: nil, characters: "+",
        charactersIgnoringModifiers: "=", isARepeat: false, keyCode: 24)!
      XCTAssertTrue(canvas.handleNavigationKey(key))
      canvas.advanceDesktopTransition(to: 1)
      let pages = try savedPages()
      XCTAssertEqual(pages.pages.count, 5)
      for _ in 0..<5 {
        XCTAssertTrue(canvas.handleNavigationKey(tabKey()))
        canvas.advanceDesktopTransition(to: 1)
      }
      XCTAssertEqual(try savedPages().pages.count, 5)
      XCTAssertEqual(try savedPages().selectedID, pages.selectedID)
      let settings = descendants(of: canvas).compactMap { $0 as? NSButton }.filter {
        $0.toolTip == "Settings"
      }
      XCTAssertEqual(settings.count, 1)
      let search = try XCTUnwrap(descendants(of: canvas).compactMap { $0 as? NSButton }.first { $0.toolTip == "Search apps" })
      XCTAssertGreaterThan(settings[0].frame.minY, search.frame.maxY)
    }
  }

  func testSettingsPointerDoesNotReachCanvas() throws {
    try withCanvas { canvas, _ in
      let host = CanvasWorkspaceView(canvas: canvas)
      host.frame = CGRect(x: 0, y: 0, width: 1200, height: 900)
      host.layoutSubtreeIfNeeded()
      let settings = try XCTUnwrap(descendants(of: canvas).compactMap { $0 as? NSButton }.first { $0.toolTip == "Settings" })
      settings.performClick(nil)
      defer { canvas.dismissSettings(); NSCursor.arrow.set() }
      host.layoutSubtreeIfNeeded()
      let point = CGPoint(x: canvas.frame.maxX + 80, y: 400)
      XCTAssertNil(canvas.hitTest(point))
      let move = try XCTUnwrap(NSEvent.mouseEvent(with: .mouseMoved, location: point,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        eventNumber: 0, clickCount: 0, pressure: 0))
      NSCursor.openHand.set()
      canvas.mouseMoved(with: move)
      XCTAssertEqual(NSCursor.current, NSCursor.arrow)
      XCTAssertNil(canvas.menu(for: move))
      let originalCamera = canvas.camera
      canvas.mouseDown(with: move)
      XCTAssertEqual(canvas.camera, originalCamera)
      XCTAssertFalse(canvas.defersBackgroundWork)
      XCTAssertTrue(host.isSettingsVisible)
    }
  }

  func testKeyboardNavigationKeepsSettingsOpen() throws {
    try withCanvas { canvas, pages in
      let host = CanvasWorkspaceView(canvas: canvas)
      host.frame = CGRect(x: 0, y: 0, width: 1200, height: 900)
      host.layoutSubtreeIfNeeded()
      let settings = try XCTUnwrap(descendants(of: canvas).compactMap { $0 as? NSButton }.first { $0.toolTip == "Settings" })
      settings.performClick(nil)
      defer { canvas.dismissSearch(); canvas.dismissSettings() }
      func key(_ code: UInt16, _ text: String = "", _ modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
          timestamp: 0, windowNumber: 0, context: nil, characters: text,
          charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
      }
      for code: UInt16 in [123, 124, 125, 126, 36, 76, 51] {
        XCTAssertTrue(canvas.handleNavigationKey(key(code)))
        XCTAssertTrue(host.isSettingsVisible)
      }
      XCTAssertTrue(canvas.handleNavigationKey(key(36, "", [.shift])))
      for code: UInt16 in [125, 126] {
        XCTAssertTrue(canvas.handleNavigationKey(key(code, "", [.shift])))
        XCTAssertTrue(canvas.handleNavigationKeyUp(key(code, "", [.shift])))
      }
      XCTAssertTrue(canvas.handleNavigationKey(tabKey()))
      canvas.advanceDesktopTransition(to: 1)
      XCTAssertEqual(try savedPages().selectedID, pages[1].id)
      XCTAssertTrue(host.isSettingsVisible)
      XCTAssertTrue(canvas.handleNavigationKey(tabKey(modifiers: [.shift])))
      canvas.advanceDesktopTransition(to: 1)
      XCTAssertEqual(try savedPages().selectedID, pages[0].id)
      XCTAssertTrue(canvas.handleNavigationKey(key(24, "+", [.shift])))
      canvas.advanceDesktopTransition(to: 1)
      XCTAssertEqual(try savedPages().pages.count, 4)
      XCTAssertTrue(host.isSettingsVisible)
      XCTAssertTrue(canvas.handleNavigationKey(key(0, "a")))
      XCTAssertTrue(host.isSettingsVisible)
      XCTAssertFalse(canvas.handleNavigationKey(key(24, "+")), "Search editor owns text input")
      XCTAssertEqual(try savedPages().pages.count, 4)
    }
  }

  func testSettingsReserveViewportAndRestoreCameraAndPlacements() throws {
    try withCanvas { canvas, pages in
      let host = CanvasWorkspaceView(canvas: canvas)
      host.frame = CGRect(x: 0, y: 0, width: 1200, height: 900)
      host.layoutSubtreeIfNeeded()
      let original = canvas.camera
      let button = try XCTUnwrap(descendants(of: canvas).compactMap { $0 as? NSButton }.first {
        $0.toolTip == "Settings"
      })
      let defaults = UserDefaults.standard
      let previousGrid = defaults.object(forKey: "showGrid")
      defer { defaults.set(previousGrid, forKey: "showGrid") }
      button.performClick(nil)
      XCTAssertTrue(host.isSettingsVisible)
      XCTAssertEqual(canvas.frame.width, 760)
      XCTAssertEqual(canvas.camera, original)
      let grid = try XCTUnwrap(descendants(of: host).compactMap { $0 as? SettingsSwitch }.first {
        $0.identifier?.rawValue == "Grid dots"
      })
      let oldState = grid.state
      let row = try XCTUnwrap(grid.superview)
      for x: CGFloat in [10, 100] {
        let point = row.convert(CGPoint(x: x, y: 26), to: row.superview)
        let hit = try XCTUnwrap(row.hitTest(point) as? NSButton)
        XCTAssertFalse(hit === grid)
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(hit.action), to: hit.target, from: hit))
      }
      XCTAssertEqual(grid.state, oldState, "Icon and text clicks each toggle once")
      XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(grid.action), to: grid.target, from: grid))
      XCTAssertNotEqual(grid.state, oldState)
      XCTAssertEqual(defaults.bool(forKey: "showGrid"), grid.state == .on)
      XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(grid.action), to: grid.target, from: grid))
      XCTAssertEqual(grid.state, oldState)
      XCTAssertTrue(canvas.dismissSettings())
      XCTAssertFalse(canvas.dismissSettings())
      XCTAssertEqual(canvas.frame.width, 1200)
      XCTAssertEqual(canvas.camera, original)
      XCTAssertEqual(try savedPages().pages, pages)
    }
  }

  func testDesktopSlideDirectionFollowsTabOrderAndKeepsCameraExact() throws {
    try withCanvas(count: 4) { canvas, pages in
      for index in [2, 0, 3, 1] {
        let previous = try savedPages().selectedID
        let previousIndex = try XCTUnwrap(pages.firstIndex { $0.id == previous })
        try tab(index, in: canvas).performClick(nil)
        let slide = try XCTUnwrap(canvas.cameraLayer.animation(forKey: "desktopSlide") as? CABasicAnimation)
        let from = try XCTUnwrap(slide.fromValue as? NSValue).pointValue
        let to = try XCTUnwrap(slide.toValue as? NSValue).pointValue
        XCTAssertEqual(from.x - to.x, index > previousIndex ? -40 : 40)
        XCTAssertEqual(from.y, to.y)
        XCTAssertEqual(slide.duration, CanvasView.desktopTransitionDuration)
        XCTAssertEqual(canvas.camera, pages[index].camera)
        canvas.advanceDesktopTransition(to: 1)
        XCTAssertNil(canvas.cameraLayer.animation(forKey: "desktopSlide"))
        XCTAssertEqual(canvas.camera, pages[index].camera)
      }
      XCTAssertEqual(try savedPages().pages, pages)
    }
  }

  func testQueuedTabWrapSlidesForwardAndPreservesEveryDesktop() throws {
    try withCanvas(count: 3) { canvas, pages in
      for _ in 0..<7 {
        XCTAssertTrue(canvas.handleNavigationKey(tabKey()))
      }
      for index in [1, 2, 0, 1, 2, 0, 1] {
        let slide = try XCTUnwrap(canvas.cameraLayer.animation(forKey: "desktopSlide") as? CABasicAnimation)
        let from = try XCTUnwrap(slide.fromValue as? NSValue).pointValue
        let to = try XCTUnwrap(slide.toValue as? NSValue).pointValue
        XCTAssertEqual(from.x - to.x, -40)
        XCTAssertEqual(from.y, to.y)
        XCTAssertEqual(slide.duration, 0.18)
        XCTAssertEqual(canvas.camera, pages[index].camera)
        XCTAssertEqual(try savedPages().selectedID, pages[index].id)
        canvas.advanceDesktopTransition(to: 1)
      }
      XCTAssertFalse(canvas.defersBackgroundWork)
      XCTAssertEqual(try savedPages().pages, pages)
    }
  }

  func testQueuedTabsPreserveDirectionAndIgnoreAutoRepeat() throws {
    try withCanvas(count: 4) { canvas, pages in
      XCTAssertTrue(canvas.handleNavigationKey(tabKey()))
      XCTAssertTrue(canvas.handleNavigationKey(tabKey(modifiers: .shift)))
      XCTAssertTrue(canvas.handleNavigationKey(tabKey(repeated: true)))
      XCTAssertTrue(canvas.handleNavigationKey(tabKey()))
      for index in [1, 0, 1] {
        XCTAssertEqual(canvas.camera, pages[index].camera)
        canvas.advanceDesktopTransition(to: 1)
      }
      XCTAssertFalse(canvas.defersBackgroundWork)
      XCTAssertEqual(try savedPages().selectedID, pages[1].id)
    }
  }

  func testTabKeyLeavesTextEditingAndModifiedShortcutsAloneAndIgnoresRepeat() throws {
    try withCanvas { canvas, pages in
      for modifiers: NSEvent.ModifierFlags in [.command, .control, .option, [.command, .shift]] {
        XCTAssertFalse(canvas.handleNavigationKey(tabKey(modifiers: modifiers)))
      }
      XCTAssertTrue(canvas.handleNavigationKey(tabKey(repeated: true)))
      XCTAssertEqual(canvas.camera, pages[0].camera)
      let searchButton = try XCTUnwrap(descendants(of: canvas).compactMap { $0 as? NSButton }.first {
        $0.action == NSSelectorFromString("showSearch:")
      })
      searchButton.performClick(nil)
      XCTAssertFalse(canvas.handleNavigationKey(tabKey()))
      XCTAssertFalse(canvas.handleNavigationKey(tabKey(modifiers: .shift)))
      XCTAssertTrue(canvas.dismissSearch())

      let window = NSWindow(contentRect: canvas.bounds, styleMask: .borderless, backing: .buffered, defer: false)
      window.contentView = canvas
      defer { window.contentView = nil }
      let title = try XCTUnwrap(descendants(of: canvas).compactMap { $0 as? NSTextField }.first {
        $0.accessibilityLabel() == "Desktop title"
      })
      XCTAssertTrue(window.makeFirstResponder(title))
      XCTAssertNotNil(title.currentEditor())
      XCTAssertFalse(canvas.handleNavigationKey(tabKey()))
      XCTAssertFalse(canvas.handleNavigationKey(tabKey(modifiers: .shift)))
      window.makeFirstResponder(canvas)
      canvas.advanceDesktopTransition(to: 1)
      XCTAssertEqual(try savedPages().selectedID, pages[0].id)
    }
    try withCanvas(count: 1) { canvas, pages in
      XCTAssertTrue(canvas.handleNavigationKey(tabKey()))
      XCTAssertTrue(canvas.handleNavigationKey(tabKey(modifiers: .shift)))
      XCTAssertFalse(canvas.defersBackgroundWork, "One desktop must not start an empty fade")
      XCTAssertEqual(canvas.camera, pages[0].camera)
    }
  }

  func testTabClickCrossfadesScenesAndRestoresEachDesktopExactly() throws {
    try withCanvas { canvas, pages in
      let original = canvas.camera
      let originalSubviews = canvas.subviews
      try tab(1, in: canvas).performClick(nil)
      XCTAssertEqual(canvas.camera, pages[1].camera, "Incoming scene is ready when fading begins")
      XCTAssertEqual(canvas.subviews, originalSubviews, "Crossfade must not insert a solid-color cover")
      for progress in [0.25, 0.5, 0.75] {
        canvas.advanceDesktopTransition(to: progress)
        XCTAssertEqual(canvas.camera, pages[1].camera, "Crossfade must not move the incoming camera")
      }
      canvas.advanceDesktopTransition(to: 1)
      XCTAssertEqual(canvas.subviews, originalSubviews)
      XCTAssertTrue(try tab(1, in: canvas).isHidden)

      try tab(0, in: canvas).performClick(nil)
      canvas.advanceDesktopTransition(to: 1)
      XCTAssertEqual(canvas.camera, original)
      let saved = try savedPages()
      XCTAssertEqual(saved.selectedID, pages[0].id)
      XCTAssertEqual(saved.pages.map(\.camera), pages.map(\.camera))
      XCTAssertEqual(saved.pages.map(\.appPlacements), pages.map(\.appPlacements))
    }
  }

  func testRapidTabClicksUseLatestDestinationAndStopCameraAnimation() throws {
    try withCanvas { canvas, pages in
      canvas.animateCamera(to: CameraState(center: CGPoint(x: 99_000, y: 99_000), zoom: 1)) {}
      try tab(1, in: canvas).performClick(nil)
      try tab(2, in: canvas).performClick(nil)
      canvas.advanceDesktopTransition(to: 1)
      canvas.advanceDesktopTransition(to: 1)
      XCTAssertEqual(canvas.camera, pages[2].camera)
      XCTAssertEqual(try savedPages().selectedID, pages[2].id)
      XCTAssertFalse(canvas.defersBackgroundWork)
      XCTAssertFalse(canvas.defersBackgroundWork)
    }
  }

  func testLongTabRowScrollsSelectedTitleIntoViewAndRenamePersists() throws {
    try withCanvas(count: 12) { canvas, _ in
      try tab(11, in: canvas).performClick(nil)
      canvas.advanceDesktopTransition(to: 1)
      canvas.layoutSubtreeIfNeeded()
      let field = try XCTUnwrap(descendants(of: canvas).compactMap { $0 as? NSTextField }.first {
        $0.accessibilityLabel() == "Desktop title"
      })
      let scroll = try XCTUnwrap(field.enclosingScrollView)
      XCTAssertGreaterThan(scroll.documentView!.frame.width, scroll.frame.width)
      XCTAssertTrue(scroll.documentVisibleRect.contains(field.frame), "Visible \(scroll.documentVisibleRect), title \(field.frame)")
      XCTAssertEqual(field.stringValue, "Workspace 12")
      field.stringValue = "Renamed workspace"
      canvas.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
      canvas.persistState()
      XCTAssertEqual(try savedPages().selectedPage.title, "Renamed workspace")
    }
  }

  func testSingleDesktopKeepsTitleAndNewDesktopUsesSameFadePath() throws {
    try withCanvas(count: 1) { canvas, _ in
      let original = canvas.camera
      XCTAssertTrue(try tab(0, in: canvas).isHidden)
      canvas.perform(NSSelectorFromString("addDesktopPage:"), with: NSMenuItem())
      canvas.advanceDesktopTransition(to: 0.25)
      XCTAssertEqual(try savedPages().pages.count, 2)
      canvas.advanceDesktopTransition(to: 1)
      XCTAssertEqual(try savedPages().pages.count, 2)
      XCTAssertEqual(canvas.camera, original, "New desktops must not introduce a directional camera offset")
      XCTAssertFalse(try tab(0, in: canvas).isHidden)
      XCTAssertTrue(try tab(1, in: canvas).isHidden)
    }
  }

  func testTabsAndDebugOverlayRenderThroughoutDesktopFade() throws {
    let defaults = UserDefaults.standard
    let previous = defaults.object(forKey: "showDebugInformation")
    defaults.set(true, forKey: "showDebugInformation")
    defer { defaults.set(previous, forKey: "showDebugInformation") }
    try withCanvas { canvas, _ in
      try tab(1, in: canvas).performClick(nil)
      for progress in [0.0, 0.25, 0.5, 0.75, 1.0] {
        canvas.advanceDesktopTransition(to: progress)
        canvas.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds))
        canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
        XCTAssertNotNil(bitmap.bitmapData)
      }
    }
  }
}

@MainActor
private final class SelectionDelegate: CanvasViewDelegate {
  var originReturns = 0
  func canvasViewDidRequestReturnToOrigin(_ canvasView: CanvasView) { originReturns += 1 }
  var launched: [String] = []
  var cancelledFocusTransitions = 0
  func canvasViewDidCancelFocusTransition(_ canvasView: CanvasView) { cancelledFocusTransitions += 1 }
  func canvasView(_ canvasView: CanvasView, didRequestFocus node: WindowNode) {
    XCTFail("Selection must not activate a window")
  }
  func canvasView(_ canvasView: CanvasView, didRequestQuit node: WindowNode) {
    XCTFail("Selection must not quit an app")
  }
  func canvasView(
    _ canvasView: CanvasView, didRequestLaunch bundleIdentifier: String, applicationName: String,
    at anchor: CGPoint
  ) { launched.append(bundleIdentifier) }
  func canvasViewDidRequestBack(_ canvasView: CanvasView) {
    XCTFail("Selection must not navigate back")
  }
  func canvasViewDidRequestForward(_ canvasView: CanvasView) {
    XCTFail("Selection must not navigate forward")
  }
  func canvasView(_ canvasView: CanvasView, setCommandTabShortcut enabled: Bool) -> Bool { false }
  func canvasView(_ canvasView: CanvasView, setPrivateBrowserPreviews enabled: Bool) {}
}
