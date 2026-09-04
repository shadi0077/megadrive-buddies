import CoreGraphics
import Foundation

// Reports on-screen window geometry for a named app. Window *metadata* needs
// no screen-recording permission, only window images do.
let target = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "MegaDrive Buddies"
let samples = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2])! : 10
for i in 0..<samples {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                          kCGNullWindowID) as? [[String: Any]] ?? []
    let mine = list.filter { ($0[kCGWindowOwnerName as String] as? String) == target }
    let desc = mine.map { w -> String in
        let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
        let alpha = w[kCGWindowAlpha as String] as? Double ?? -1
        let layer = w[kCGWindowLayer as String] as? Int ?? -1
        return String(format: "[L%d a%.2f %.0fx%.0f @ %.0f,%.0f]",
                      layer, alpha, b["Width"] ?? 0, b["Height"] ?? 0, b["X"] ?? 0, b["Y"] ?? 0)
    }.joined(separator: " ")
    print("t=\(i)  windows=\(mine.count)  \(desc)")
    fflush(stdout)
    Thread.sleep(forTimeInterval: 1.5)
}
