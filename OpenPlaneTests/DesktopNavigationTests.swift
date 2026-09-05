import XCTest

@testable import OpenPlane

final class DesktopNavigationTests: XCTestCase {
  private enum Target: String, CaseIterable {
    case openCode = "window:openCode"
    case claude = "window:claude"
    case activityMonitor = "window:activityMonitor"
    case appStore = "window:appStore"
    case music = "window:music"
    case quickTime = "window:quickTime"
    case finder = "app:finder"
    case ollama = "app:ollama"
    case wisprFlow = "app:wisprFlow"
    case chrome = "window:chrome"
    case iTerm2 = "window:iTerm2"
    case betterTouchTool = "app:betterTouchTool"
    case altTab = "app:altTab"
    case chatGPT = "window:chatGPT"
    case surfshark = "app:surfshark"
    case telegram = "window:telegram"
    case slack = "window:slack"
    case paperPrimary = "window:paperPrimary"
    case paperSecondary = "window:paperSecondary"
    case whatsApp = "app:whatsApp"
    case blender = "window:blender"
    case libreOffice = "app:libreOffice"
  }

  private struct Node {
    let id: Target
    let frame: CGRect
    // Fixed expected destinations, ordered left / right / up / down.
    let neighbors: [Target?]

    init(
      _ id: Target, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
      neighbors: [Target?]
    ) {
      self.id = id
      frame = CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
      self.neighbors = neighbors
    }
  }

  // Frozen from the desktop the user approved on 2026-09-05.
  // Open windows use their persisted slot geometry; closed cards use the
  // 1728 × 1117 fullview size. Paper has two distinct live window slots.
  // Names are stable fixture aliases, not volatile macOS window IDs.
  // Do not regenerate expected neighbors from directionalNeighbor at test time.
  // Changes to this contract require an intentional product decision.
  private let nodes = [
    Node(
      .openCode, x: 3118.2015554292, y: 4362.627030995282, width: 1728, height: 1084,
      neighbors: [.iTerm2, .blender, .chatGPT, .chrome]),
    Node(
      .claude, x: 3126.192310057939, y: 7446.91571188125, width: 1728, height: 947,
      neighbors: [.appStore, .ollama, nil, .chatGPT]),
    Node(
      .activityMonitor, x: -2511.058256270087, y: 4525.761489402441, width: 1623.463338533541,
      height: 1084,
      neighbors: [.whatsApp, .iTerm2, .surfshark, .quickTime]),
    Node(
      .appStore, x: -2671.095312499994, y: 7683.210937499996, width: 1728,
      height: 1040.926567164179,
      neighbors: [.slack, .claude, nil, .surfshark]),
    Node(
      .music, x: 5370.178479596498, y: 2882.443099539242, width: 1728, height: 1057.959183673469,
      neighbors: [.chrome, nil, .blender, .altTab]),
    Node(
      .quickTime, x: -2901.346043456694, y: 2499.359854055056, width: 542, height: 1084,
      neighbors: [.paperPrimary, .chrome, .activityMonitor, .libreOffice]),
    Node(
      .finder, x: 787.9607828882445, y: -1278.615848581301, width: 1728, height: 1117,
      neighbors: [.paperSecondary, .wisprFlow, .iTerm2, .libreOffice]),
    Node(
      .ollama, x: 5330.500848248167, y: 5930.823512799583, width: 1728, height: 1117,
      neighbors: [.chatGPT, nil, .claude, .blender]),
    Node(
      .wisprFlow, x: 2858.207548972093, y: -1280.494954236737, width: 1728, height: 1117,
      neighbors: [.finder, .altTab, .chrome, .libreOffice]),
    Node(
      .chrome, x: 3026.79165757414, y: 2888.115871654975, width: 1728, height: 1011,
      neighbors: [.quickTime, .music, .openCode, .wisprFlow]),
    Node(
      .iTerm2, x: -290.581644736244, y: 4011.720944695615, width: 1377.290043290043, height: 1084,
      neighbors: [.activityMonitor, .openCode, .betterTouchTool, .finder]),
    Node(
      .betterTouchTool, x: -633.6950129804317, y: 6016.357090697121, width: 1728, height: 1117,
      neighbors: [.surfshark, .chatGPT, .appStore, .iTerm2]),
    Node(
      .altTab, x: 4956.310456705214, y: -1256.394616012064, width: 1728, height: 1117,
      neighbors: [.wisprFlow, nil, .music, .libreOffice]),
    Node(
      .chatGPT, x: 3064.56358906437, y: 5941.379590246353, width: 1728, height: 1009,
      neighbors: [.betterTouchTool, .ollama, .claude, .openCode]),
    Node(
      .surfshark, x: -2626.1177800218, y: 6004.284346438115, width: 1728, height: 1117,
      neighbors: [.slack, .betterTouchTool, .appStore, .activityMonitor]),
    Node(
      .telegram, x: -6796.462669329714, y: 5311.368991775639, width: 1728, height: 1009,
      neighbors: [nil, .surfshark, .slack, .whatsApp]),
    Node(
      .slack, x: -6803.446897933893, y: 6638.131792532951, width: 1728, height: 1014,
      neighbors: [nil, .surfshark, .appStore, .telegram]),
    Node(
      .paperPrimary, x: -6699.903655980685, y: 1683.022975266501, width: 1728, height: 1014,
      neighbors: [nil, .quickTime, .whatsApp, .paperSecondary]),
    Node(
      .paperSecondary, x: -4731.903655980685, y: 435.022975266501, width: 1728, height: 1008,
      neighbors: [.paperPrimary, .quickTime, .paperPrimary, .libreOffice]),
    Node(
      .whatsApp, x: -6767.261903263785, y: 4040.672494852441, width: 1728, height: 1117,
      neighbors: [nil, .activityMonitor, .telegram, .paperPrimary]),
    Node(
      .blender, x: 5302.4348496339, y: 4354.716037344505, width: 1728, height: 1084,
      neighbors: [.openCode, nil, .ollama, .music]),
    Node(
      .libreOffice, x: -2583.93458456098, y: -4307.115898177777, width: 1728, height: 1117,
      neighbors: [.paperSecondary, .finder, .quickTime, nil]),
  ]

  private let directions: [CanvasDirection] = [.left, .right, .up, .down]

  func testApprovedDesktopFixtureIsComplete() {
    XCTAssertEqual(nodes.count, 22)
    XCTAssertEqual(Set(nodes.map(\.id)), Set(Target.allCases))
    XCTAssertEqual(Set(nodes.map(\.id)).count, nodes.count)
    for node in nodes {
      XCTAssertEqual(node.neighbors.count, directions.count, node.id.rawValue)
      XCTAssertFalse(node.neighbors.contains(node.id), "A target must not point to itself")
    }
  }

  func testAll88DirectionalChoicesMatchApprovedDesktop() {
    for node in nodes {
      let candidates = nodes.filter { $0.id != node.id }.map {
        (id: $0.id.rawValue, frame: $0.frame)
      }
      for (index, direction) in directions.enumerated() {
        XCTAssertEqual(
          CanvasMath.directionalNeighbor(
            from: node.frame, candidates: candidates, direction: direction),
          node.neighbors[index]?.rawValue,
          "\(node.id.rawValue) → \(direction)"
        )
      }
    }
  }

  func testApprovedDesktopChoicesSurviveCameraChangesAndCandidateReordering() {
    let bounds = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    let cameras = [
      CameraState(center: .zero, zoom: 0.06),
      CameraState(center: CGPoint(x: 3064, y: 5941), zoom: 1),
      CameraState(center: CGPoint(x: -9000, y: -5000), zoom: 2.5),
    ]
    let orders = [
      nodes, Array(nodes.reversed()), Array(nodes.dropFirst(7)) + Array(nodes.prefix(7)),
    ]
    for camera in cameras {
      for order in orders {
        for node in nodes {
          let frame = CanvasMath.viewRect(for: node.frame, camera: camera, bounds: bounds)
          let candidates = order.filter { $0.id != node.id }.map {
            (
              id: $0.id.rawValue,
              frame: CanvasMath.viewRect(for: $0.frame, camera: camera, bounds: bounds)
            )
          }
          for (index, direction) in directions.enumerated() {
            XCTAssertEqual(
              CanvasMath.directionalNeighbor(
                from: frame, candidates: candidates, direction: direction),
              node.neighbors[index]?.rawValue,
              "\(node.id.rawValue) → \(direction), zoom \(camera.zoom)"
            )
          }
        }
      }
    }
  }

  func testChainedNavigationVisitsEveryNodeAndStopsAtBoundaries() throws {
    // Each next step starts at the actual result of the previous one.
    // This route crosses app groups, both Paper windows and closed cards,
    // reverses direction, revisits targets, and presses past top/bottom edges.
    let route: [(CanvasDirection, Target)] = [
      (.right, .ollama), (.down, .blender), (.down, .music),
      (.left, .chrome), (.up, .openCode), (.left, .iTerm2),
      (.up, .betterTouchTool), (.left, .surfshark), (.left, .slack),
      (.down, .telegram), (.down, .whatsApp), (.down, .paperPrimary),
      (.down, .paperSecondary), (.right, .quickTime), (.up, .activityMonitor),
      (.right, .iTerm2), (.down, .finder), (.right, .wisprFlow),
      (.right, .altTab), (.down, .libreOffice), (.down, .libreOffice),
      (.right, .finder), (.down, .libreOffice), (.up, .quickTime),
      (.up, .activityMonitor), (.up, .surfshark), (.up, .appStore),
      (.up, .appStore), (.right, .claude), (.up, .claude), (.down, .chatGPT),
    ]
    var selected = Target.chatGPT.rawValue
    var visited: Set<String> = [selected]
    for (index, step) in route.enumerated() {
      let origin = try XCTUnwrap(nodes.first { $0.id.rawValue == selected })
      let candidates = nodes.filter { $0.id != origin.id }.map {
        (id: $0.id.rawValue, frame: $0.frame)
      }
      selected =
        CanvasMath.directionalNeighbor(
          from: origin.frame, candidates: candidates, direction: step.0
        ) ?? selected
      XCTAssertEqual(
        selected, step.1.rawValue, "Step \(index + 1): \(origin.id.rawValue) → \(step.0)")
      visited.insert(selected)
    }
    XCTAssertEqual(visited, Set(nodes.map { $0.id.rawValue }))
  }
}
