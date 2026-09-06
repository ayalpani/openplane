import Cocoa
let rect = CGDisplayBounds(CGMainDisplayID())
for y in stride(from: 220, through: 650, by: 20) {
  CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: rect.maxX - 160, y: CGFloat(y)), mouseButton: .left)?.post(tap: .cghidEventTap)
  Thread.sleep(forTimeInterval: 0.02)
}
