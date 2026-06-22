#if canImport(XCTest)
import Foundation
import XCTest
@testable import Starlight

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testDefaultSettingsMatchInitialProductConfiguration() {
        let settings = makeSettings(suiteName: "StarlightTests.defaultSettingsMatchInitialProductConfiguration")

        XCTAssertEqual(settings.dimmingIntensity, 0.5)
        XCTAssertTrue(settings.openAtLogin)
        XCTAssertTrue(settings.showStatusInMenuBar)
        XCTAssertEqual(settings.appApplicationMode, .single)
        XCTAssertEqual(settings.effectiveRecentAppLimit, 1)
        XCTAssertEqual(settings.animationDuration, 0.5)
    }

    func testAnimationDurationUsesNearestPreset() {
        let settings = makeSettings(suiteName: "StarlightTests.animationDurationUsesNearestPreset")

        settings.animationDuration = 0.42

        XCTAssertEqual(settings.animationDuration, 0.5)
    }

    func testNewSettingsPersistInDefaults() {
        let suiteName = "StarlightTests.newSettingsPersistInDefaults"
        let settings = makeSettings(suiteName: suiteName)

        settings.openAtLogin = true
        settings.showStatusInMenuBar = false
        settings.appApplicationMode = .single
        settings.keyboardShortcutsEnabled = false

        let defaults = UserDefaults(suiteName: suiteName)!
        let reloadedSettings = SettingsStore(defaults: defaults)
        XCTAssertTrue(reloadedSettings.openAtLogin)
        XCTAssertFalse(reloadedSettings.showStatusInMenuBar)
        XCTAssertEqual(reloadedSettings.appApplicationMode, .single)
        XCTAssertEqual(reloadedSettings.effectiveRecentAppLimit, 1)
        XCTAssertFalse(reloadedSettings.keyboardShortcutsEnabled)
    }

    func testChangedSettingPostsOneNotification() {
        let settings = makeSettings(suiteName: "StarlightTests.changedSettingPostsOneNotification")
        let expectation = expectation(description: "settings change notification")
        expectation.expectedFulfillmentCount = 1

        let observer = NotificationCenter.default.addObserver(
            forName: .starlightSettingsDidChange,
            object: settings,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        settings.dimmingIntensity = 0.7

        wait(for: [expectation], timeout: 1.0)
    }

    func testUnchangedSettingDoesNotPostNotification() {
        let settings = makeSettings(suiteName: "StarlightTests.unchangedSettingDoesNotPostNotification")
        settings.dimmingIntensity = 0.7

        let expectation = expectation(description: "no settings change notification")
        expectation.isInverted = true

        let observer = NotificationCenter.default.addObserver(
            forName: .starlightSettingsDidChange,
            object: settings,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        settings.dimmingIntensity = 0.7

        wait(for: [expectation], timeout: 0.2)
    }

    private func makeSettings(suiteName: String) -> SettingsStore {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SettingsStore(defaults: defaults)
    }
}
#endif
