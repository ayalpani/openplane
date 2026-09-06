import AppKit
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let main = NSWindow(contentRect: NSRect(x: 200,y: 300,width: 500,height: 300),styleMask: [.titled,.closable],backing: .buffered,defer: false)
main.title = "OpenPlane Test Window"
let helper = NSWindow(contentRect: NSRect(x: 850,y: 300,width: 650,height: 220),styleMask: .borderless,backing: .buffered,defer: false)
helper.setAccessibilityElement(false)
helper.setAccessibilityRole(.unknown)
main.orderFrontRegardless();helper.orderFrontRegardless()
app.run()
