import AppKit
import ApplicationServices
for app in NSRunningApplication.runningApplications(withBundleIdentifier: "com.googlecode.iterm2") {
 let ax = AXUIElementCreateApplication(app.processIdentifier)
 var raw: CFTypeRef?
 let result = AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &raw)
 print("pid", app.processIdentifier, "inventory", result.rawValue)
 for window in raw as? [AXUIElement] ?? [] {
  for key in [kAXRoleAttribute, kAXSubroleAttribute, kAXMinimizedAttribute, kAXModalAttribute] {
   var value: CFTypeRef?; let r = AXUIElementCopyAttributeValue(window, key as CFString, &value)
   print(key, r.rawValue, value ?? "nil" as CFString)
  }
  var close: CFTypeRef?; let r = AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &close)
  print("closeButton", r.rawValue, close != nil)
 }
}
func visit(_ el: AXUIElement, depth: Int) {
 guard depth < 5 else { return }
 var raw: CFTypeRef?
 AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &raw)
 if raw as? String == kAXButtonRole as String {
  AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &raw); print("dialog button", raw as? String ?? "")
 }
 AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &raw)
 for child in raw as? [AXUIElement] ?? [] { visit(child, depth: depth + 1) }
}
for app in NSRunningApplication.runningApplications(withBundleIdentifier: "com.googlecode.iterm2") {
 var raw: CFTypeRef?; AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier), kAXWindowsAttribute as CFString, &raw)
 for w in raw as? [AXUIElement] ?? [] {
  var role: CFTypeRef?; AXUIElementCopyAttributeValue(w,kAXSubroleAttribute as CFString,&role)
  if role as? String == kAXDialogSubrole as String { visit(w,depth:0) }
 }
}
