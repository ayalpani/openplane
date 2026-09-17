import AppKit

@MainActor
final class FixtureDelegate: NSObject, NSApplicationDelegate {
  var windows: [NSWindow] = []
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSWindow.allowsAutomaticWindowTabbing = false
    let menu = NSMenu()
    let root = NSMenuItem()
    menu.addItem(root)
    let submenu = NSMenu()
    submenu.addItem(withTitle: "Quit Input Fixture", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    root.submenu = submenu
    NSApp.mainMenu = menu
    for (index, title) in ["Input Fixture A", "Input Fixture B"].enumerated() {
      let window = NSWindow(contentRect: NSRect(x: 180 + index * 120, y: 180 + index * 80,
        width: 540, height: 340), styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered, defer: false)
      window.tabbingMode = .disallowed
      window.title = title
      window.isReleasedWhenClosed = false
      let label = NSTextField(labelWithString: title + "\nDisposable test window — no document")
      label.font = .systemFont(ofSize: 26)
      label.frame = NSRect(x: 30, y: 100, width: 490, height: 100)
      window.contentView?.addSubview(label)
      window.makeKeyAndOrderFront(nil)
      windows.append(window)
    }
    Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
      MainActor.assumeIsolated {
        let titles = NSApp.windows.filter { $0.isVisible }.map { $0.title }.sorted().joined(separator: "\n")
        try? titles.write(toFile: "/tmp/openplane-input-fix/visible-windows.txt", atomically: true, encoding: .utf8)
      }
    }
    NSApp.activate(ignoringOtherApps: true)
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
@main
@MainActor
struct FixtureMain {
  static func main() {
    let app = NSApplication.shared
    let delegate = FixtureDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
  }
}
