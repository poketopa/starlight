#if canImport(XCTest)
import CoreGraphics
import XCTest
@testable import Starlight

final class WindowSnapshotServiceTests: XCTestCase {
    func testDesktopMaxYUsesHighestScreenEdge() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1000, height: 800),
            CGRect(x: 0, y: 800, width: 1000, height: 600),
            CGRect(x: 1000, y: -300, width: 1000, height: 700)
        ]

        XCTAssertEqual(WindowSnapshotService.desktopMaxY(screenFrames: screens), 1400)
    }

    func testQuartzRectConversionHandlesScreenAboveMainDisplay() {
        let desktopMaxY: CGFloat = 1400
        let appKitRect = CGRect(x: 120, y: 900, width: 320, height: 180)
        let quartzRect = CGRect(
            x: appKitRect.minX,
            y: desktopMaxY - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        )

        XCTAssertEqual(
            WindowSnapshotService.convertQuartzWindowRect(quartzRect, desktopMaxY: desktopMaxY),
            appKitRect
        )
    }

    func testQuartzRectConversionHandlesNegativeYScreenBelowMainDisplay() {
        let desktopMaxY: CGFloat = 800
        let appKitRect = CGRect(x: 50, y: -420, width: 240, height: 160)
        let quartzRect = CGRect(
            x: appKitRect.minX,
            y: desktopMaxY - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        )

        XCTAssertEqual(
            WindowSnapshotService.convertQuartzWindowRect(quartzRect, desktopMaxY: desktopMaxY),
            appKitRect
        )
    }
}
#endif
