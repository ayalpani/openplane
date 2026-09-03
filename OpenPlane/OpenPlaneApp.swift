import AppKit

@main
@MainActor
enum OpenPlaneApp {
  static func main() {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.regular)
    if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
      application.applicationIconImage = NSImage(contentsOf: iconURL)
    }
    application.run()
  }
}
