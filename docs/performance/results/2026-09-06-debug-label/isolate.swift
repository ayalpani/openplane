import AppKit
let app = NSApplication.shared
let mode = CommandLine.arguments[1]
let retainedFont: NSFont? = ["font", "attributes"].contains(mode) ? NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold) : nil
let retainedAttributes: [NSAttributedString.Key: Any] = retainedFont.map { [.font: $0, .foregroundColor: NSColor.white.withAlphaComponent(0.9)] } ?? [:]
for iteration in 0..<100000 {
  autoreleasepool {
    let label = mode == "fixed" ? "Zoom 0.06×" : String(format: mode == "ascii" ? "Zoom %.2fx" : "Zoom %.2f×", 0.06 + Double(iteration % 120) / 100)
    let font = mode == "font" || mode == "attributes" ? retainedFont! : mode == "system" ? NSFont.systemFont(ofSize: 12, weight: .semibold) : NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
    let attributes: [NSAttributedString.Key: Any] = mode == "attributes" ? retainedAttributes : [.font: font, .foregroundColor: NSColor.white.withAlphaComponent(0.9)]
    if iteration < 3 { FileHandle.standardOutput.write(Data("\(iteration) \(label)\n".utf8)) }
    let size = label.size(withAttributes: attributes)
    precondition(size.width > 0 && size.height > 0)
  }
}
print("PASS 100000")
