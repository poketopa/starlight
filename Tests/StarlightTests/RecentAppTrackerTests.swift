#if canImport(XCTest)
import XCTest
@testable import Starlight

final class RecentAppTrackerTests: XCTestCase {
    func testRecordMovesExistingAppToFront() {
        let tracker = RecentAppTracker(limit: 3)

        tracker.record(AppIdentity(bundleIdentifier: "a", name: "A"))
        tracker.record(AppIdentity(bundleIdentifier: "b", name: "B"))
        tracker.record(AppIdentity(bundleIdentifier: "a", name: "A"))

        XCTAssertEqual(tracker.recentApps.map(\.bundleIdentifier), ["a", "b"])
    }

    func testBrightBundleIdentifiersRespectLimitButHistoryStaysLonger() {
        let tracker = RecentAppTracker(limit: 2)

        tracker.record(AppIdentity(bundleIdentifier: "a", name: "A"))
        tracker.record(AppIdentity(bundleIdentifier: "b", name: "B"))
        tracker.record(AppIdentity(bundleIdentifier: "c", name: "C"))

        XCTAssertEqual(tracker.recentApps.map(\.bundleIdentifier), ["c", "b", "a"])
        XCTAssertEqual(tracker.brightBundleIdentifiers(), ["c", "b"])
        XCTAssertEqual(tracker.brightBundleIdentifiersInRecentOrder(), ["c", "b", "a"])
    }

}
#endif
