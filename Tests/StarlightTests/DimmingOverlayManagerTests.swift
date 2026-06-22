#if canImport(XCTest)
import CoreGraphics
import XCTest
@testable import Starlight

@MainActor
final class DimmingOverlayManagerTests: XCTestCase {
    func testTargetSelectionPicksRecentAppsPresentOnEachDisplay() {
        let leftScreen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let rightScreen = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        let snapshots = [
            WindowSnapshot(windowID: 101, ownerPID: 1, bundleIdentifier: "a", frame: CGRect(x: 10, y: 10, width: 100, height: 100)),
            WindowSnapshot(windowID: 102, ownerPID: 2, bundleIdentifier: "b", frame: CGRect(x: 1010, y: 10, width: 100, height: 100)),
            WindowSnapshot(windowID: 103, ownerPID: 3, bundleIdentifier: "c", frame: CGRect(x: 1130, y: 10, width: 100, height: 100)),
            WindowSnapshot(windowID: 104, ownerPID: 4, bundleIdentifier: "d", frame: CGRect(x: 250, y: 10, width: 100, height: 100))
        ]

        let leftTargets = DimmingOverlayManager.targetRects(
            snapshots: snapshots,
            screenFrame: leftScreen,
            recentBundleIdentifiers: ["a", "b", "c", "d"],
            limit: 3
        )
        let rightTargets = DimmingOverlayManager.targetRects(
            snapshots: snapshots,
            screenFrame: rightScreen,
            recentBundleIdentifiers: ["a", "b", "c", "d"],
            limit: 3
        )

        XCTAssertEqual(leftTargets, [
            CGRect(x: 10, y: 10, width: 100, height: 100),
            CGRect(x: 250, y: 10, width: 100, height: 100)
        ])
        XCTAssertEqual(rightTargets, [
            CGRect(x: 1010, y: 10, width: 100, height: 100),
            CGRect(x: 1130, y: 10, width: 100, height: 100)
        ])
    }

    func testZOrderTargetPicksTopmostRecentWindowOnScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let snapshots = [
            WindowSnapshot(windowID: 201, ownerPID: 1, bundleIdentifier: "a", frame: CGRect(x: 10, y: 10, width: 100, height: 100)),
            WindowSnapshot(windowID: 202, ownerPID: 2, bundleIdentifier: "b", frame: CGRect(x: 150, y: 10, width: 100, height: 100)),
            WindowSnapshot(windowID: 203, ownerPID: 1, bundleIdentifier: "a", frame: CGRect(x: 300, y: 10, width: 100, height: 100))
        ]

        let target = DimmingOverlayManager.zOrderTarget(
            snapshots: snapshots,
            screenFrame: screen,
            recentBundleIdentifiers: ["a", "b"]
        )

        XCTAssertEqual(target?.windowID, 201)
    }

    func testSingleApplicationModeHighlightsOnlyTopmostWindowWhenAppHasMultipleWindows() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let snapshots = [
            WindowSnapshot(windowID: 211, ownerPID: 1, bundleIdentifier: "a", frame: CGRect(x: 10, y: 10, width: 100, height: 100)),
            WindowSnapshot(windowID: 212, ownerPID: 1, bundleIdentifier: "a", frame: CGRect(x: 150, y: 10, width: 100, height: 100)),
            WindowSnapshot(windowID: 213, ownerPID: 2, bundleIdentifier: "b", frame: CGRect(x: 300, y: 10, width: 100, height: 100))
        ]

        let targets = DimmingOverlayManager.highlightSnapshots(
            snapshots: snapshots,
            screenFrame: screen,
            recentBundleIdentifiers: ["a", "b"],
            mode: .single,
            limit: 3
        )

        XCTAssertEqual(targets.map(\.windowID), [211])
    }

    func testMultipleApplicationModeStillHighlightsAllWindowsForSelectedApps() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let snapshots = [
            WindowSnapshot(windowID: 221, ownerPID: 1, bundleIdentifier: "a", frame: CGRect(x: 10, y: 10, width: 100, height: 100)),
            WindowSnapshot(windowID: 222, ownerPID: 1, bundleIdentifier: "a", frame: CGRect(x: 150, y: 10, width: 100, height: 100)),
            WindowSnapshot(windowID: 223, ownerPID: 2, bundleIdentifier: "b", frame: CGRect(x: 300, y: 10, width: 100, height: 100))
        ]

        let targets = DimmingOverlayManager.highlightSnapshots(
            snapshots: snapshots,
            screenFrame: screen,
            recentBundleIdentifiers: ["a", "b"],
            mode: .multiple,
            limit: 2
        )

        XCTAssertEqual(targets.map(\.windowID), [221, 222, 223])
    }

    func testRefreshPreservesInFlightMaskTransition() {
        XCTAssertTrue(
            DimmingOverlayManager.shouldPreserveInFlightMaskTransition(
                reason: .refresh,
                transitionInFlight: true
            )
        )
        XCTAssertFalse(
            DimmingOverlayManager.shouldPreserveInFlightMaskTransition(
                reason: .focusTransition,
                transitionInFlight: true
            )
        )
        XCTAssertFalse(
            DimmingOverlayManager.shouldPreserveInFlightMaskTransition(
                reason: .refresh,
                transitionInFlight: false
            )
        )
    }

    func testTransitionOutRectsOnlyReturnsHighlightsThatLeftFocus() {
        let previous = [
            CGRect(x: 10, y: 10, width: 100, height: 100),
            CGRect(x: 200, y: 10, width: 100, height: 100)
        ]
        let current = [
            CGRect(x: 202, y: 12, width: 100, height: 100),
            CGRect(x: 400, y: 10, width: 100, height: 100)
        ]

        let transitionOutRects = DimmingOverlayManager.transitionOutRects(
            previous: previous,
            current: current
        )

        XCTAssertEqual(transitionOutRects, [
            CGRect(x: 10, y: 10, width: 100, height: 100)
        ])
    }

    func testProtectedRectsAreRelativeToTransitionPatch() {
        let transitionPatch = CGRect(x: 100, y: 100, width: 200, height: 160)
        let currentHighlights = [
            CGRect(x: 150, y: 120, width: 80, height: 60),
            CGRect(x: 500, y: 500, width: 20, height: 20)
        ]

        let protectedRects = DimmingOverlayManager.protectedRects(
            for: transitionPatch,
            protectedRects: currentHighlights
        )

        XCTAssertEqual(protectedRects, [
            CGRect(x: 50, y: 20, width: 80, height: 60)
        ])
    }

    func testProtectedRectsClipPartiallyOverlappingHighlights() {
        let transitionPatch = CGRect(x: 100, y: 100, width: 100, height: 100)
        let currentHighlights = [
            CGRect(x: 150, y: 50, width: 100, height: 100)
        ]

        let protectedRects = DimmingOverlayManager.protectedRects(
            for: transitionPatch,
            protectedRects: currentHighlights
        )

        XCTAssertEqual(protectedRects, [
            CGRect(x: 50, y: 0, width: 50, height: 50)
        ])
    }

    func testTargetWindowsMovedIgnoresSmallCoordinateJitter() {
        let previous = [
            CGWindowID(301): CGRect(x: 10, y: 10, width: 100, height: 100)
        ]
        let current = [
            WindowSnapshot(windowID: 301, ownerPID: 1, bundleIdentifier: "a", frame: CGRect(x: 11, y: 10.5, width: 100, height: 100))
        ]

        XCTAssertFalse(DimmingOverlayManager.targetWindowsMoved(previousFrames: previous, currentSnapshots: current))
    }

    func testTargetWindowsMovedDetectsWindowDrag() {
        let previous = [
            CGWindowID(302): CGRect(x: 10, y: 10, width: 100, height: 100)
        ]
        let current = [
            WindowSnapshot(windowID: 302, ownerPID: 1, bundleIdentifier: "a", frame: CGRect(x: 24, y: 10, width: 100, height: 100))
        ]

        XCTAssertTrue(DimmingOverlayManager.targetWindowsMoved(previousFrames: previous, currentSnapshots: current))
    }

    func testWindowMovementDoesNotSuppressDimmingWithoutPressedMouseButton() {
        let previous = [
            CGWindowID(303): CGRect(x: 10, y: 10, width: 100, height: 100)
        ]
        let current = [
            WindowSnapshot(windowID: 303, ownerPID: 1, bundleIdentifier: "a", frame: CGRect(x: 24, y: 10, width: 100, height: 100))
        ]

        XCTAssertFalse(
            DimmingOverlayManager.shouldSuppressForWindowDrag(
                previousFrames: previous,
                currentSnapshots: current,
                primaryMouseButtonPressed: false
            )
        )
    }

    func testWindowMovementSuppressesDimmingWhenPrimaryMouseButtonIsPressed() {
        let previous = [
            CGWindowID(304): CGRect(x: 10, y: 10, width: 100, height: 100)
        ]
        let current = [
            WindowSnapshot(windowID: 304, ownerPID: 1, bundleIdentifier: "a", frame: CGRect(x: 24, y: 10, width: 100, height: 100))
        ]

        XCTAssertTrue(
            DimmingOverlayManager.shouldSuppressForWindowDrag(
                previousFrames: previous,
                currentSnapshots: current,
                primaryMouseButtonPressed: true
            )
        )
    }

    func testWindowSetChangesDoNotSuppressDimmingAsDrag() {
        let previous = [
            CGWindowID(305): CGRect(x: 10, y: 10, width: 100, height: 100)
        ]
        let current = [
            WindowSnapshot(windowID: 305, ownerPID: 1, bundleIdentifier: "a", frame: CGRect(x: 24, y: 10, width: 100, height: 100)),
            WindowSnapshot(windowID: 306, ownerPID: 1, bundleIdentifier: "a", frame: CGRect(x: 160, y: 10, width: 100, height: 100))
        ]

        XCTAssertFalse(
            DimmingOverlayManager.shouldSuppressForWindowDrag(
                previousFrames: previous,
                currentSnapshots: current,
                primaryMouseButtonPressed: true
            )
        )
    }

    func testPanelHandoffKeepsBackgroundCompositeAlphaStable() {
        let targetAlpha: CGFloat = 0.46
        for progress in stride(from: CGFloat(0), through: CGFloat(1), by: CGFloat(0.1)) {
            let incomingAlpha = targetAlpha * progress
            let outgoingAlpha = DimmingOverlayManager.outgoingAlphaForConstantComposite(
                targetAlpha: targetAlpha,
                incomingAlpha: incomingAlpha
            )
            let compositeAlpha = incomingAlpha + outgoingAlpha - incomingAlpha * outgoingAlpha

            XCTAssertEqual(compositeAlpha, targetAlpha, accuracy: 0.0001)
        }
    }

}
#endif
