import AppKit
final class Delegate: NSObject, NSApplicationDelegate {
 var windows: [NSWindow] = []
 func applicationDidFinishLaunching(_ n: Notification) {
  for index in 1...2 {
   let window = NSWindow(contentRect: NSRect(x: 100 + index * 50,y: 100 + index * 50,width: 420,height: 250),styleMask:[.titled,.closable],backing:.buffered,defer:false)
   window.isReleasedWhenClosed = false
   window.title = "Close Test \(index)"
   windows.append(window); window.makeKeyAndOrderFront(nil)
  }
  NSApp.activate(ignoringOtherApps:true)
 }
 func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
  guard let window = windows.first(where: { $0.isVisible }) else { return .terminateNow }
  let alert = NSAlert(); alert.messageText = "Close the test window?"
  alert.addButton(withTitle:"Close Test"); alert.addButton(withTitle:"Cancel")
  alert.beginSheetModal(for:window) { result in sender.reply(toApplicationShouldTerminate: result == .alertFirstButtonReturn) }
  return .terminateLater
 }
}
let app = NSApplication.shared
let delegate = Delegate()
app.setActivationPolicy(.regular); app.delegate = delegate; app.run()
