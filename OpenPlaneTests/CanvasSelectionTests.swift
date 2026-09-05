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
    }
    try check(canvas, delegate)
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
          let original = canvas.camera
          XCTAssertTrue(canvas.handleNavigationKey(tabKey(modifiers: modifiers)))
          canvas.advanceDesktopTransition(to: 0.25)
          XCTAssertEqual(canvas.desktopTransitionOpacity, 0.5, accuracy: 0.001)
          XCTAssertEqual(canvas.camera, original)
          canvas.advanceDesktopTransition(to: 0.5)
          XCTAssertEqual(canvas.camera, pages[index].camera)
          canvas.advanceDesktopTransition(to: 1)
          XCTAssertEqual(try savedPages().selectedID, pages[index].id)
          XCTAssertEqual(canvas.desktopTransitionOpacity, 0)
        }
      }
      XCTAssertEqual(try savedPages().pages, pages)
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

  func testTabClickFadesBeforeChangingCameraAndRestoresEachDesktopExactly() throws {
    try withCanvas { canvas, pages in
      let original = canvas.camera
      try tab(1, in: canvas).performClick(nil)
      XCTAssertEqual(canvas.camera, original)
      canvas.advanceDesktopTransition(to: 0.25)
      XCTAssertEqual(canvas.desktopTransitionOpacity, 0.5, accuracy: 0.001)
      XCTAssertEqual(canvas.camera, original, "The outgoing desktop must not travel during fade-out")
      canvas.advanceDesktopTransition(to: 0.5)
      XCTAssertEqual(canvas.desktopTransitionOpacity, 1)
      XCTAssertEqual(canvas.camera, pages[1].camera)
      canvas.advanceDesktopTransition(to: 0.75)
      XCTAssertEqual(canvas.desktopTransitionOpacity, 0.5, accuracy: 0.001)
      XCTAssertEqual(canvas.camera, pages[1].camera, "The incoming desktop must not travel during fade-in")
      canvas.advanceDesktopTransition(to: 1)
      XCTAssertEqual(canvas.desktopTransitionOpacity, 0)
      XCTAssertTrue(try tab(1, in: canvas).isHidden, "The editable active title replaces its tab button")

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
      XCTAssertEqual(canvas.desktopTransitionOpacity, 0)
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
      XCTAssertEqual(try savedPages().pages.count, 1)
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
  var launched: [String] = []
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
