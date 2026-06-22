#if canImport(XCTest)
import XCTest
@testable import Starlight

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testSettingsWindowDisablesDimmingOnlyWhileVisibleAndNotMiniaturized() {
        XCTAssertFalse(
            SettingsWindowController.shouldDisableDimming(
                isVisible: false,
                isMiniaturized: false
            )
        )
        XCTAssertFalse(
            SettingsWindowController.shouldDisableDimming(
                isVisible: true,
                isMiniaturized: true
            )
        )
        XCTAssertTrue(
            SettingsWindowController.shouldDisableDimming(
                isVisible: true,
                isMiniaturized: false
            )
        )
    }
}
#endif
