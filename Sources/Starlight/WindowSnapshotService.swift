import AppKit
import CoreGraphics
import Foundation

struct WindowSnapshot {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let bundleIdentifier: String
    let frame: CGRect
}

final class WindowSnapshotService {
    private let currentPID = ProcessInfo.processInfo.processIdentifier

    func snapshots() -> [WindowSnapshot] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let desktopMaxY = Self.desktopMaxY(screenFrames: NSScreen.screens.map(\.frame))
        return rawWindows.compactMap { info in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { return nil }
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID else { return nil }
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != currentPID else { return nil }
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            guard let x = bounds["X"], let y = bounds["Y"], let width = bounds["Width"], let height = bounds["Height"] else {
                return nil
            }
            guard width >= 40, height >= 40 else { return nil }
            guard let app = NSRunningApplication(processIdentifier: pid),
                  let bundleIdentifier = app.bundleIdentifier else { return nil }

            return WindowSnapshot(
                windowID: windowID,
                ownerPID: pid,
                bundleIdentifier: bundleIdentifier,
                frame: Self.convertQuartzWindowRect(
                    CGRect(x: x, y: y, width: width, height: height),
                    desktopMaxY: desktopMaxY
                )
            )
        }
    }

    static func desktopMaxY(screenFrames: [CGRect]) -> CGFloat {
        screenFrames.map(\.maxY).max() ?? CGDisplayBounds(CGMainDisplayID()).maxY
    }

    static func convertQuartzWindowRect(_ rect: CGRect, desktopMaxY: CGFloat) -> CGRect {
        return CGRect(
            x: rect.origin.x,
            y: desktopMaxY - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
