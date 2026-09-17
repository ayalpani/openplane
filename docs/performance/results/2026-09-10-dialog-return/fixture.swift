import AppKit
final class Delegate: NSObject, NSApplicationDelegate {
 var window: NSWindow!
 func applicationDidFinishLaunching(_ n: Notification) {
  window = NSWindow(contentRect: NSRect(x: 100,y: 100,width: 420,height: 250),styleMask:[.titled,.closable],backing:.buffered,defer:false)
  window.title = "OpenPlane Close Test"
  window.makeKeyAndOrderFront(nil)
  NSApp.activate(ignoringOtherApps:true)
 }
 func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
  let alert = NSAlert(); alert.messageText = "Close the test window?"
  alert.addButton(withTitle:"Close Test"); alert.addButton(withTitle:"Cancel")
  alert.beginSheetModal(for:window) { result in sender.reply(toApplicationShouldTerminate: result == .alertFirstButtonReturn) }
  return .terminateLater
 }
}
let app = NSApplication.shared
let delegate = Delegate()
app.setActivationPolicy(.regular); app.delegate = delegate; app.run()
