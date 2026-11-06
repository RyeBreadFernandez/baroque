// Prints the window number of iPhone Mirroring's window, for screencapture -l: scripts/mirror_setup.py photographs
// that window alone, so other windows over it never end up in its pictures.
// Build: swiftc -O scripts/mirror/winid.swift -o build/mirror-winid
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in windows where (w[kCGWindowOwnerName as String] as? String) == "iPhone Mirroring" && (w[kCGWindowLayer as String] as? Int) == 0 {
    if let bounds = w[kCGWindowBounds as String] as? [String: CGFloat], (bounds["Height"] ?? 0) > 300 {
        print(w[kCGWindowNumber as String] as? Int ?? 0)
        exit(0)
    }
}
exit(1)
