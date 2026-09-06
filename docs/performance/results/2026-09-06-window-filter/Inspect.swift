import AppKit
@main struct Inspect {
 @MainActor static func main() async throws {
  let windows = try await WindowService().discover(on: NSScreen.main!)
  print("total=\(windows.count)")
  for w in windows where w.bundleIdentifier == "com.google.Chrome" || w.bundleIdentifier == "com.openplane.window-filter-fixture" {
   print("bundle=\(w.bundleIdentifier) id=\(w.id) frame=\(w.frame) matched=\(w.accessibilityElement != nil)")
  }
 }
}
