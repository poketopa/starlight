import AppKit
import Foundation
import QuartzCore

@MainActor
final class DimmingOverlayManager {
    enum UpdateReason {
        case focusTransition
        case settingsChange
        case refresh
    }

    private let settings: SettingsStore
    private let windowSnapshotService: WindowSnapshotService
    private var overlayWindows: [NSScreen: OverlayWindow] = [:]
    private var dragSuppressionStates: [NSScreen: DragSuppressionState] = [:]

    init(settings: SettingsStore, windowSnapshotService: WindowSnapshotService) {
        self.settings = settings
        self.windowSnapshotService = windowSnapshotService
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func update(
        recentBundleIdentifiers: [String],
        reason: UpdateReason
    ) {
        guard settings.enabled else {
            hide()
            return
        }

        ensureWindowsForCurrentScreens()

        let snapshots = windowSnapshotService.snapshots()
        for screen in NSScreen.screens {
            let targetSnapshots = DimmingOverlayManager.highlightSnapshots(
                snapshots: snapshots,
                screenFrame: screen.frame,
                recentBundleIdentifiers: recentBundleIdentifiers,
                mode: settings.appApplicationMode,
                limit: settings.recentAppLimit
            )
            let targetRects = targetSnapshots.map(\.frame)

            switch settings.appApplicationMode {
            case .single:
                guard let target = targetSnapshots.first else {
                    overlayWindows[screen]?.orderOut(animationDuration: 0)
                    continue
                }

                overlayWindows[screen]?.renderBehindTargetWindow(
                    dimmingColor: settings.dimmingColor,
                    intensity: settings.dimmingIntensity,
                    animationDuration: settings.animationDuration,
                    reason: reason,
                    targetWindows: [target],
                    targetWindowID: target.windowID,
                    protectedRects: []
                )
            case .multiple:
                switch dragSuppressionDecision(for: screen, targetSnapshots: targetSnapshots, reason: reason) {
                case .suppress:
                    overlayWindows[screen]?.suppressForDrag()
                case .render(let renderReason):
                    overlayWindows[screen]?.renderMask(
                        dimmingColor: settings.dimmingColor,
                        intensity: settings.dimmingIntensity,
                        animationDuration: settings.animationDuration,
                        reason: renderReason,
                        targetRects: targetRects
                    )
                }
            }
        }
    }

    static func zOrderTarget(
        snapshots: [WindowSnapshot],
        screenFrame: CGRect,
        recentBundleIdentifiers: [String]
    ) -> WindowSnapshot? {
        let screenSnapshots = snapshots.filter { $0.frame.intersects(screenFrame) }
        let screenBundles = Set(screenSnapshots.map(\.bundleIdentifier))
        guard let selectedBundle = recentBundleIdentifiers.first(where: { screenBundles.contains($0) }) else {
            return nil
        }

        return screenSnapshots.first { $0.bundleIdentifier == selectedBundle }
    }

    static func highlightSnapshots(
        snapshots: [WindowSnapshot],
        screenFrame: CGRect,
        recentBundleIdentifiers: [String],
        mode: AppApplicationMode,
        limit: Int
    ) -> [WindowSnapshot] {
        switch mode {
        case .single:
            return zOrderTarget(
                snapshots: snapshots,
                screenFrame: screenFrame,
                recentBundleIdentifiers: recentBundleIdentifiers
            ).map { [$0] } ?? []
        case .multiple:
            return targetSnapshots(
                snapshots: snapshots,
                screenFrame: screenFrame,
                recentBundleIdentifiers: recentBundleIdentifiers,
                limit: limit
            )
        }
    }

    static func targetSnapshots(
        snapshots: [WindowSnapshot],
        screenFrame: CGRect,
        recentBundleIdentifiers: [String],
        limit: Int
    ) -> [WindowSnapshot] {
        let screenSnapshots = snapshots.filter { $0.frame.intersects(screenFrame) }
        let screenBundles = Set(screenSnapshots.map(\.bundleIdentifier))
        let selectedBundles = recentBundleIdentifiers
            .filter { screenBundles.contains($0) }
            .prefix(max(1, limit))
        let selectedSet = Set(selectedBundles)
        return screenSnapshots.filter { selectedSet.contains($0.bundleIdentifier) }
    }

    static func targetRects(
        snapshots: [WindowSnapshot],
        screenFrame: CGRect,
        recentBundleIdentifiers: [String],
        limit: Int
    ) -> [CGRect] {
        targetSnapshots(
            snapshots: snapshots,
            screenFrame: screenFrame,
            recentBundleIdentifiers: recentBundleIdentifiers,
            limit: limit
        )
        .map(\.frame)
    }

    static func windowFramesByID(_ snapshots: [WindowSnapshot]) -> [CGWindowID: CGRect] {
        Dictionary(uniqueKeysWithValues: snapshots.map { ($0.windowID, $0.frame) })
    }

    static func targetWindowsMoved(
        previousFrames: [CGWindowID: CGRect],
        currentSnapshots: [WindowSnapshot],
        tolerance: CGFloat = 2.0
    ) -> Bool {
        currentSnapshots.contains { snapshot in
            guard let previousFrame = previousFrames[snapshot.windowID] else { return false }
            return abs(previousFrame.minX - snapshot.frame.minX) > tolerance
                || abs(previousFrame.minY - snapshot.frame.minY) > tolerance
                || abs(previousFrame.width - snapshot.frame.width) > tolerance
                || abs(previousFrame.height - snapshot.frame.height) > tolerance
        }
    }

    static func shouldSuppressForWindowDrag(
        previousFrames: [CGWindowID: CGRect],
        currentSnapshots: [WindowSnapshot],
        primaryMouseButtonPressed: Bool
    ) -> Bool {
        guard primaryMouseButtonPressed else { return false }
        guard Set(previousFrames.keys) == Set(currentSnapshots.map(\.windowID)) else { return false }
        return targetWindowsMoved(previousFrames: previousFrames, currentSnapshots: currentSnapshots)
    }

    static func transitionOutRects(previous: [CGRect], current: [CGRect]) -> [CGRect] {
        previous.filter { previousRect in
            !current.contains { currentRect in
                rectanglesRepresentSameHighlight(previousRect, currentRect)
            }
        }
    }

    static func protectedRects(
        for patchRect: CGRect,
        protectedRects: [CGRect]
    ) -> [CGRect] {
        protectedRects.compactMap { protectedRect in
            let intersection = patchRect.intersection(protectedRect)
            guard !intersection.isNull, !intersection.isEmpty else { return nil }
            return CGRect(
                x: intersection.minX - patchRect.minX,
                y: intersection.minY - patchRect.minY,
                width: intersection.width,
                height: intersection.height
            )
        }
    }

    static func outgoingAlphaForConstantComposite(targetAlpha: CGFloat, incomingAlpha: CGFloat) -> CGFloat {
        let clampedTarget = max(0.0, min(targetAlpha, 0.95))
        let clampedIncoming = max(0.0, min(incomingAlpha, clampedTarget))
        let denominator = max(0.001, 1.0 - clampedIncoming)
        return max(0.0, min(0.95, 1.0 - ((1.0 - clampedTarget) / denominator)))
    }

    static func shouldPreserveInFlightMaskTransition(reason: UpdateReason, transitionInFlight: Bool) -> Bool {
        reason == .refresh && transitionInFlight
    }

    private func dragSuppressionDecision(
        for screen: NSScreen,
        targetSnapshots: [WindowSnapshot],
        reason: UpdateReason
    ) -> DragSuppressionDecision {
        let currentFrames = DimmingOverlayManager.windowFramesByID(targetSnapshots)
        guard reason == .refresh,
              settings.appApplicationMode == .multiple else {
            dragSuppressionStates[screen] = DragSuppressionState(previousTargetFrames: currentFrames)
            return .render(reason)
        }

        var state = dragSuppressionStates[screen] ?? DragSuppressionState()
        defer {
            state.previousTargetFrames = currentFrames
            dragSuppressionStates[screen] = state
        }

        guard !targetSnapshots.isEmpty else {
            guard state.isSuppressed else {
                state.stableRefreshCount = 0
                return .render(reason)
            }

            state.stableRefreshCount += 1
            if state.stableRefreshCount >= 2 {
                state.stableRefreshCount = 0
                state.isSuppressed = false
                return .render(.focusTransition)
            }

            return .suppress
        }

        guard !state.previousTargetFrames.isEmpty else {
            state.stableRefreshCount = 0
            state.isSuppressed = false
            return .render(reason)
        }

        if DimmingOverlayManager.shouldSuppressForWindowDrag(
            previousFrames: state.previousTargetFrames,
            currentSnapshots: targetSnapshots,
            primaryMouseButtonPressed: DimmingOverlayManager.primaryMouseButtonPressed
        ) {
            state.stableRefreshCount = 0
            state.isSuppressed = true
            return .suppress
        }

        guard state.isSuppressed else {
            return .render(reason)
        }

        state.stableRefreshCount += 1
        if state.stableRefreshCount >= 2 {
            state.stableRefreshCount = 0
            state.isSuppressed = false
            return .render(.focusTransition)
        }

        return .suppress
    }

    func hide() {
        dragSuppressionStates.removeAll()
        overlayWindows.values.forEach { $0.orderOut(animationDuration: settings.animationDuration) }
    }

    func suppressForLocalWindowDrag() {
        dragSuppressionStates.removeAll()
        ensureWindowsForCurrentScreens()
        overlayWindows.values.forEach { $0.suppressForDrag() }
    }

    @objc private func handleScreenParametersChanged() {
        overlayWindows.values.forEach { $0.close() }
        overlayWindows.removeAll()
        dragSuppressionStates.removeAll()
        ensureWindowsForCurrentScreens()
    }

    private func ensureWindowsForCurrentScreens() {
        let currentScreens = Set(NSScreen.screens)
        for screen in currentScreens where overlayWindows[screen] == nil {
            overlayWindows[screen] = OverlayWindow(screen: screen)
        }

        for screen in overlayWindows.keys where !currentScreens.contains(screen) {
            overlayWindows[screen]?.close()
            overlayWindows.removeValue(forKey: screen)
            dragSuppressionStates.removeValue(forKey: screen)
        }
    }

    private static func rectanglesRepresentSameHighlight(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        guard lhs.width > 0, lhs.height > 0, rhs.width > 0, rhs.height > 0 else {
            return false
        }

        if lhs.equalTo(rhs) {
            return true
        }

        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, !intersection.isEmpty else {
            return false
        }

        let smallerArea = min(lhs.area, rhs.area)
        guard smallerArea > 0 else {
            return false
        }

        return intersection.area / smallerArea >= 0.85
    }

    private static var primaryMouseButtonPressed: Bool {
        (NSEvent.pressedMouseButtons & 1) == 1
    }
}

private struct DragSuppressionState {
    var previousTargetFrames: [CGWindowID: CGRect] = [:]
    var stableRefreshCount = 0
    var isSuppressed = false
}

private enum DragSuppressionDecision {
    case render(DimmingOverlayManager.UpdateReason)
    case suppress
}

@MainActor
private final class OverlayWindow {
    private let screen: NSScreen
    private var panel: NSPanel
    private var overlayView: OverlayView
    private var brightRects: [CGRect] = []
    private var brightTargetWindowID: CGWindowID?
    private var renderGeneration = 0
    private var transitionInFlight = false
    private var panelHandoff: PanelHandoff?
    private var panelHandoffTimer: Timer?
    private var retiringPanels: [NSPanel] = []

    init(screen: NSScreen) {
        self.screen = screen
        let panelBundle = OverlayWindow.makePanelBundle(screen: screen)
        overlayView = panelBundle.view
        panel = panelBundle.panel
    }

    private static func makePanelBundle(screen: NSScreen) -> (panel: NSPanel, view: OverlayView) {
        let overlayView = OverlayView(screenFrame: screen.frame)
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        panel.contentView = overlayView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.ignoresMouseEvents = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.hasShadow = false

        return (panel, overlayView)
    }

    func renderMask(
        dimmingColor: NSColor,
        intensity: Double,
        animationDuration: Double,
        reason: DimmingOverlayManager.UpdateReason,
        targetRects: [CGRect]
    ) {
        let wasVisible = panel.isVisible
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        cancelPanelHandoff(closeRetiringPanels: true)

        if DimmingOverlayManager.shouldPreserveInFlightMaskTransition(
            reason: reason,
            transitionInFlight: transitionInFlight
        ) {
            panel.orderFrontRegardless()
            applyPanelAlpha(
                to: CGFloat(intensity),
                animationDuration: animationDuration,
                reason: reason,
                wasVisible: wasVisible
            )
            return
        }

        renderGeneration += 1
        transitionInFlight = false
        overlayView.removeTransitionPatches()

        let transitionOutRects = transitionOutRects(
            to: targetRects,
            reason: reason,
            animationDuration: animationDuration,
            wasVisible: wasVisible
        )
        let baseTargetRects = targetRects + transitionOutRects

        overlayView.configure(
            dimmingColor: dimmingColor,
            intensity: 1.0,
            targetRects: baseTargetRects
        )
        panel.orderFrontRegardless()
        applyPanelAlpha(
            to: CGFloat(intensity),
            animationDuration: animationDuration,
            reason: reason,
            wasVisible: wasVisible
        )
        animateTransitionOutIfNeeded(
            transitionOutRects,
            dimmingColor: dimmingColor,
            animationDuration: animationDuration,
            finalTargetRects: targetRects
        )
        brightRects = targetRects
        brightTargetWindowID = nil
    }

    func renderBehindTargetWindow(
        dimmingColor: NSColor,
        intensity: Double,
        animationDuration: Double,
        reason: DimmingOverlayManager.UpdateReason,
        targetWindows: [WindowSnapshot],
        targetWindowID: CGWindowID,
        protectedRects: [CGRect]
    ) {
        let wasVisible = panel.isVisible
        panel.level = .normal
        let currentRects = targetWindows.map(\.frame)
        let effectiveReason = reason

        if effectiveReason == .refresh, transitionInFlight {
            panel.order(.below, relativeTo: Int(targetWindowID))
            overlayView.configure(
                dimmingColor: dimmingColor,
                intensity: 1.0,
                targetRects: protectedRects
            )
            return
        }

        let clampedIntensity = CGFloat(max(0.0, min(intensity, 0.95)))
        let shouldAnimatePanelHandoff = effectiveReason == .focusTransition
            && wasVisible
            && animationDuration > 0
            && clampedIntensity > 0
            && brightTargetWindowID.map { $0 != targetWindowID } == true

        if shouldAnimatePanelHandoff {
            startPanelHandoff(
                dimmingColor: dimmingColor,
                targetAlpha: clampedIntensity,
                animationDuration: animationDuration,
                targetWindowID: targetWindowID,
                currentRects: currentRects,
                protectedRects: protectedRects
            )
            return
        }

        cancelPanelHandoff(closeRetiringPanels: true)

        if effectiveReason == .refresh {
            overlayView.configure(
                dimmingColor: dimmingColor,
                intensity: 1.0,
                targetRects: protectedRects
            )
            if !wasVisible {
                panel.alphaValue = CGFloat(max(0.0, min(intensity, 0.95)))
            }
            panel.order(.below, relativeTo: Int(targetWindowID))
            applyPanelAlpha(
                to: CGFloat(intensity),
                animationDuration: animationDuration,
                reason: effectiveReason,
                wasVisible: wasVisible
            )
            brightRects = currentRects
            brightTargetWindowID = targetWindowID
            return
        }

        renderGeneration += 1
        transitionInFlight = false
        overlayView.removeTransitionPatches()
        overlayView.configure(
            dimmingColor: dimmingColor,
            intensity: 1.0,
            targetRects: protectedRects
        )

        if !wasVisible {
            panel.alphaValue = 0.0
        }
        panel.order(.below, relativeTo: Int(targetWindowID))
        applyPanelAlpha(
            to: CGFloat(intensity),
            animationDuration: animationDuration,
            reason: effectiveReason,
            wasVisible: wasVisible
        )
        brightRects = currentRects
        brightTargetWindowID = targetWindowID
    }

    private func transitionOutRects(
        to targetRects: [CGRect],
        reason: DimmingOverlayManager.UpdateReason,
        animationDuration: Double,
        wasVisible: Bool
    ) -> [CGRect] {
        guard wasVisible, reason == .focusTransition, animationDuration > 0 else {
            return []
        }

        return DimmingOverlayManager.transitionOutRects(previous: brightRects, current: targetRects)
    }

    private func animateTransitionOutIfNeeded(
        _ transitionOutRects: [CGRect],
        dimmingColor: NSColor,
        animationDuration: Double,
        finalTargetRects: [CGRect]
    ) {
        guard !transitionOutRects.isEmpty, animationDuration > 0 else {
            return
        }

        let generation = renderGeneration
        transitionInFlight = true
        overlayView.animateDimmingPatches(
            rects: transitionOutRects,
            protectedRects: finalTargetRects,
            dimmingColor: dimmingColor,
            duration: animationDuration
        ) { [weak self] in
            guard let self, self.renderGeneration == generation else {
                return
            }

            self.transitionInFlight = false
            self.overlayView.removeTransitionPatches()
            self.overlayView.configure(
                dimmingColor: dimmingColor,
                intensity: 1.0,
                targetRects: finalTargetRects
            )
        }
    }

    private func applyPanelAlpha(
        to targetAlpha: CGFloat,
        animationDuration: Double,
        reason: DimmingOverlayManager.UpdateReason,
        wasVisible: Bool
    ) {
        let clampedAlpha = max(0.0, min(targetAlpha, 0.95))

        switch reason {
        case .focusTransition:
            guard !wasVisible, animationDuration > 0 else {
                panel.alphaValue = clampedAlpha
                return
            }
            panel.alphaValue = 0.0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = clampedAlpha
            }
        case .settingsChange:
            panel.alphaValue = clampedAlpha
        case .refresh:
            if !wasVisible {
                panel.alphaValue = clampedAlpha
            }
        }
    }

    private func startPanelHandoff(
        dimmingColor: NSColor,
        targetAlpha: CGFloat,
        animationDuration: Double,
        targetWindowID: CGWindowID,
        currentRects: [CGRect],
        protectedRects: [CGRect]
    ) {
        // Use full-screen panel handoff here; rect cutouts recreate the rounded-corner flash.
        cancelPanelHandoff(closeRetiringPanels: true)

        renderGeneration += 1
        transitionInFlight = true

        let generation = renderGeneration
        let retiringPanel = panel
        let retiringView = overlayView
        retiringView.removeTransitionPatches()
        retiringView.configure(
            dimmingColor: dimmingColor,
            intensity: 1.0,
            targetRects: protectedRects
        )
        retiringPanel.alphaValue = targetAlpha

        let incoming = OverlayWindow.makePanelBundle(screen: screen)
        incoming.view.configure(
            dimmingColor: dimmingColor,
            intensity: 1.0,
            targetRects: protectedRects
        )
        incoming.panel.level = .normal
        incoming.panel.alphaValue = 0.0
        incoming.panel.order(.below, relativeTo: Int(targetWindowID))

        panel = incoming.panel
        overlayView = incoming.view
        retiringPanels.append(retiringPanel)

        brightRects = currentRects
        brightTargetWindowID = targetWindowID

        let handoff = PanelHandoff(
            generation: generation,
            retiringPanel: retiringPanel,
            incomingPanel: incoming.panel,
            targetAlpha: targetAlpha,
            duration: animationDuration
        )
        panelHandoff = handoff

        let timer = Timer(
            timeInterval: 1.0 / 60.0,
            target: self,
            selector: #selector(stepPanelHandoff(_:)),
            userInfo: handoff,
            repeats: true
        )
        panelHandoffTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        stepPanelHandoff(timer)
    }

    @objc private func stepPanelHandoff(_ timer: Timer) {
        guard let handoff = timer.userInfo as? PanelHandoff,
              panelHandoff === handoff,
              handoff.generation == renderGeneration else {
            timer.invalidate()
            return
        }

        let elapsed = CACurrentMediaTime() - handoff.startTime
        let rawProgress = handoff.duration <= 0 ? 1.0 : min(1.0, elapsed / handoff.duration)
        let progress = OverlayWindow.easeInOut(CGFloat(rawProgress))
        let incomingAlpha = handoff.targetAlpha * progress
        let retiringAlpha = DimmingOverlayManager.outgoingAlphaForConstantComposite(
            targetAlpha: handoff.targetAlpha,
            incomingAlpha: incomingAlpha
        )

        handoff.incomingPanel.alphaValue = incomingAlpha
        handoff.retiringPanel.alphaValue = retiringAlpha

        guard rawProgress >= 1.0 else {
            return
        }

        timer.invalidate()
        panelHandoffTimer = nil
        panelHandoff = nil
        transitionInFlight = false
        handoff.incomingPanel.alphaValue = handoff.targetAlpha
        handoff.retiringPanel.close()
        retiringPanels.removeAll { $0 === handoff.retiringPanel }
    }

    private func cancelPanelHandoff(closeRetiringPanels: Bool) {
        let hadPanelHandoff = panelHandoff != nil || !retiringPanels.isEmpty

        panelHandoffTimer?.invalidate()
        panelHandoffTimer = nil
        panelHandoff = nil

        if closeRetiringPanels {
            retiringPanels.forEach { $0.close() }
            retiringPanels.removeAll()
            if hadPanelHandoff {
                transitionInFlight = false
            }
        }
    }

    private static func easeInOut(_ progress: CGFloat) -> CGFloat {
        let clamped = max(0.0, min(progress, 1.0))
        return clamped * clamped * (3.0 - 2.0 * clamped)
    }

    func suppressForDrag() {
        renderGeneration += 1
        transitionInFlight = false
        cancelPanelHandoff(closeRetiringPanels: true)
        overlayView.removeTransitionPatches()
        panel.alphaValue = 0.0
        panel.orderOut(nil)
    }

    func orderOut(animationDuration: Double) {
        cancelPanelHandoff(closeRetiringPanels: false)
        renderGeneration += 1
        let generation = renderGeneration

        let visibleRetiringPanels = retiringPanels.filter(\.isVisible)
        let visiblePanels = ([panel] + visibleRetiringPanels).filter(\.isVisible)
        guard !visiblePanels.isEmpty else { return }

        guard animationDuration > 0 else {
            visiblePanels.forEach { $0.orderOut(nil) }
            visibleRetiringPanels.forEach { $0.close() }
            retiringPanels.removeAll()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            visiblePanels.forEach { $0.animator().alphaValue = 0.0 }
        } completionHandler: {
            Task { @MainActor in
                guard self.renderGeneration == generation else { return }
                visiblePanels.forEach { $0.orderOut(nil) }
                visibleRetiringPanels.forEach { $0.close() }
                self.retiringPanels.removeAll()
            }
        }
    }

    func close() {
        cancelPanelHandoff(closeRetiringPanels: true)
        panel.close()
    }
}

@MainActor
private final class PanelHandoff {
    let generation: Int
    let retiringPanel: NSPanel
    let incomingPanel: NSPanel
    let targetAlpha: CGFloat
    let duration: Double
    let startTime = CACurrentMediaTime()

    init(
        generation: Int,
        retiringPanel: NSPanel,
        incomingPanel: NSPanel,
        targetAlpha: CGFloat,
        duration: Double
    ) {
        self.generation = generation
        self.retiringPanel = retiringPanel
        self.incomingPanel = incomingPanel
        self.targetAlpha = targetAlpha
        self.duration = duration
    }
}

private extension CGRect {
    var area: CGFloat {
        max(0, width) * max(0, height)
    }
}

@MainActor
private final class OverlayView: NSView {
    private let screenFrame: CGRect
    private var dimmingColor = NSColor.black
    private var intensity: CGFloat = 0.55
    private var targetRects: [CGRect] = []

    init(screenFrame: CGRect) {
        self.screenFrame = screenFrame
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(dimmingColor: NSColor, intensity: CGFloat, targetRects: [CGRect]) {
        self.dimmingColor = dimmingColor
        self.intensity = max(0, min(intensity, 0.95))
        self.targetRects = targetRects
        needsDisplay = true
    }

    func removeTransitionPatches() {
        subviews
            .compactMap { $0 as? TransitionPatchView }
            .forEach { $0.removeFromSuperview() }
    }

    func animateDimmingPatches(
        rects: [CGRect],
        protectedRects: [CGRect],
        dimmingColor: NSColor,
        duration: Double,
        completion: @escaping @MainActor @Sendable () -> Void
    ) {
        removeTransitionPatches()

        let patches = rects.map { targetRect in
            let localPatchRect = localHighlightRect(for: targetRect)
            return TransitionPatchView(
                frame: localPatchRect,
                protectedRects: DimmingOverlayManager.protectedRects(
                    for: localPatchRect,
                    protectedRects: protectedRects.map { localHighlightRect(for: $0) }
                ),
                dimmingColor: dimmingColor
            )
        }
        patches.forEach { patch in
            patch.alphaValue = 0.0
            addSubview(patch)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            patches.forEach { $0.animator().alphaValue = 1.0 }
        } completionHandler: {
            Task { @MainActor in
                completion()
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setBlendMode(.normal)
        dimmingColor.withAlphaComponent(intensity).setFill()
        bounds.fill()

        context.setBlendMode(.clear)
        for targetRect in targetRects {
            NSBezierPath(roundedRect: localHighlightRect(for: targetRect), xRadius: 8, yRadius: 8).fill()
        }
        context.setBlendMode(.normal)
    }

    private func localHighlightRect(for targetRect: CGRect) -> CGRect {
        CGRect(
            x: targetRect.minX - screenFrame.minX,
            y: targetRect.minY - screenFrame.minY,
            width: targetRect.width,
            height: targetRect.height
        )
    }
}

@MainActor
private final class TransitionPatchView: NSView {
    private let protectedRects: [CGRect]
    private let dimmingColor: NSColor

    init(frame: CGRect, protectedRects: [CGRect], dimmingColor: NSColor) {
        self.protectedRects = protectedRects
        self.dimmingColor = dimmingColor
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setBlendMode(.normal)
        dimmingColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()

        // Clear each protected rect independently. An even-odd compound path re-fills
        // overlaps between protected windows, causing a dark flash in stacked highlights.
        context.setBlendMode(.clear)
        for protectedRect in protectedRects {
            NSBezierPath(roundedRect: protectedRect, xRadius: 8, yRadius: 8).fill()
        }
        context.setBlendMode(.normal)
    }
}
