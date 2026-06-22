#if canImport(XCTest)
import AppKit
import XCTest
@testable import Starlight

@MainActor
final class AppDelegateTests: XCTestCase {
    func testStatusImageLoadsConfiguredMenuBarIcon() {
        let image = AppDelegate.statusImage()

        XCTAssertEqual(image.size, NSSize(width: 22, height: 22))
        XCTAssertTrue(image.isTemplate)
        XCTAssertTrue(
            image.representations.contains { representation in
                representation is NSBitmapImageRep
                    && representation.pixelsWide == 44
                    && representation.pixelsHigh == 44
            }
        )
    }

    func testTimedRefreshSkipsWhenDimmingIsDisabled() {
        XCTAssertFalse(
            AppDelegate.shouldRunTimedRefresh(
                settingsEnabled: false,
                settingsWindowShouldDisableDimming: false,
                applicationMode: .multiple,
                elapsedSinceLastSingleRefresh: 10,
                singleApplicationRefreshInterval: 0.25
            )
        )
    }

    func testTimedRefreshSkipsWhileSettingsWindowDisablesDimming() {
        XCTAssertFalse(
            AppDelegate.shouldRunTimedRefresh(
                settingsEnabled: true,
                settingsWindowShouldDisableDimming: true,
                applicationMode: .multiple,
                elapsedSinceLastSingleRefresh: 10,
                singleApplicationRefreshInterval: 0.25
            )
        )
    }

    func testTimedRefreshThrottlesSingleApplicationMode() {
        XCTAssertFalse(
            AppDelegate.shouldRunTimedRefresh(
                settingsEnabled: true,
                settingsWindowShouldDisableDimming: false,
                applicationMode: .single,
                elapsedSinceLastSingleRefresh: 0.1,
                singleApplicationRefreshInterval: 0.25
            )
        )
        XCTAssertTrue(
            AppDelegate.shouldRunTimedRefresh(
                settingsEnabled: true,
                settingsWindowShouldDisableDimming: false,
                applicationMode: .single,
                elapsedSinceLastSingleRefresh: 0.25,
                singleApplicationRefreshInterval: 0.25
            )
        )
    }

    func testTimedRefreshKeepsMultipleApplicationModeResponsive() {
        XCTAssertTrue(
            AppDelegate.shouldRunTimedRefresh(
                settingsEnabled: true,
                settingsWindowShouldDisableDimming: false,
                applicationMode: .multiple,
                elapsedSinceLastSingleRefresh: 0,
                singleApplicationRefreshInterval: 0.25
            )
        )
    }
}
#endif
