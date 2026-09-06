import AppKit
let app = NSApplication.shared
for iteration in 0..<100000 {
  autoreleasepool {
    let label = String(format: "Zoom %.2f×", 0.06 + Double(iteration % 120) / 100)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
      .foregroundColor: NSColor.white.withAlphaComponent(0.9),
    ]
    let size = label.size(withAttributes: attributes)
    precondition(size.width > 0 && size.height > 0)
  }
  if iteration % 10000 == 0 { print(iteration) }
}
