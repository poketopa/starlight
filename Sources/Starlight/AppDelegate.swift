import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum MenuLayout {
        static let width: CGFloat = 292
        static let horizontalInset: CGFloat = 12
    }

    private enum AppTiming {
        static let overlayRefreshInterval: TimeInterval = 0.12
        static let singleApplicationRefreshInterval: TimeInterval = 0.25
    }

    private enum StatusItemLayout {
        static let length: CGFloat = 30
        static let imageSize = NSSize(width: 22, height: 22)
    }

    private let settings = SettingsStore.shared
    private let permissionCoordinator = PermissionCoordinator()
    private let focusEventService = FocusEventService()
    private let windowSnapshotService = WindowSnapshotService()
    private lazy var recentAppTracker = RecentAppTracker(
        limit: settings.effectiveRecentAppLimit
    )
    private lazy var overlayManager = DimmingOverlayManager(
        settings: settings,
        windowSnapshotService: windowSnapshotService
    )
    private lazy var settingsWindowController: SettingsWindowController = {
        let controller = SettingsWindowController(settings: settings)
        controller.onWindowDragStateChanged = { [weak self] isDragging in
            guard let self else { return }
            isSettingsWindowDragging = isDragging
            if isDragging {
                overlayManager.suppressForLocalWindowDrag()
            } else {
                updateOverlay(reason: .settingsChange)
            }
        }
        controller.onWindowVisibilityChanged = { [weak self] in
            self?.updateOverlay(reason: .settingsChange)
        }
        return controller
    }()
    private lazy var keyboardShortcutController = KeyboardShortcutController { [weak self] action in
        self?.handleShortcut(action)
    }

    private var statusItem: NSStatusItem?
    private var refreshTimer: Timer?
    private var appliedOpenAtLogin: Bool?
    private var appliedKeyboardShortcutsEnabled: Bool?
    private var isSettingsWindowDragging = false
    private var isDimmingSuppressedForSettingsWindow = false
    private var isDimmingSuppressedWhileDisabled = false
    private var lastSingleApplicationRefreshTime = CACurrentMediaTime()
    private weak var menuIntensityValueLabel: NSTextField?
    private weak var menuSingleModeSwitch: NSSwitch?
    private weak var menuMultipleModeSwitch: NSSwitch?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupFocusEvents()
        keyboardShortcutController.setShortcutsEnabled(settings.keyboardShortcutsEnabled)
        appliedKeyboardShortcutsEnabled = settings.keyboardShortcutsEnabled
        applyOpenAtLoginSettingIfNeeded()
        permissionCoordinator.requestAccessibilityPermission()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: .starlightSettingsDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationActiveStateDidChange),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationActiveStateDidChange),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        refreshTimer = Timer.scheduledTimer(withTimeInterval: AppTiming.overlayRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.handleRefreshTimer()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        focusEventService.stop()
        keyboardShortcutController.shutdown()
        overlayManager.hide()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: StatusItemLayout.length)
        item.isVisible = true
        item.button?.image = Self.statusImage()
        item.button?.imagePosition = .imageOnly
        item.button?.imageScaling = .scaleProportionallyUpOrDown
        item.button?.title = ""
        item.button?.toolTip = "Starlight"
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        updateStatusIcon()
    }

    static func statusImage() -> NSImage {
        if let image = Bundle.main.image(forResource: NSImage.Name("MenuBarIconTemplate")) {
            return preparedStatusImage(image)
        }

        if let image = developmentStatusImage() {
            return preparedStatusImage(image)
        }

        if let image = NSImage(systemSymbolName: "scope", accessibilityDescription: "Starlight") {
            return preparedStatusImage(image)
        }

        let image = NSImage(size: StatusItemLayout.imageSize)
        image.lockFocus()
        NSColor.black.setStroke()
        NSColor.black.setFill()

        let outer = NSBezierPath(ovalIn: NSRect(x: 4, y: 4, width: 14, height: 14))
        outer.lineWidth = 2.0
        outer.stroke()

        NSBezierPath(ovalIn: NSRect(x: 9, y: 9, width: 4, height: 4)).fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func preparedStatusImage(_ image: NSImage) -> NSImage {
        image.isTemplate = true
        image.size = StatusItemLayout.imageSize
        return image
    }

    private static func developmentStatusImage() -> NSImage? {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let imageSetURL = projectRoot
            .appendingPathComponent("icon")
            .appendingPathComponent("Resources")
            .appendingPathComponent("MenuBarIcon.imageset")

        for filename in ["MenuBarIconTemplate@2x.png", "MenuBarIconTemplate.png"] {
            let imageURL = imageSetURL.appendingPathComponent(filename)
            if let image = NSImage(contentsOf: imageURL) {
                return image
            }
        }

        return nil
    }

    private func setupFocusEvents() {
        focusEventService.onActivatedApp = { [weak self] app in
            guard let self else { return }
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else {
                updateOverlay(reason: .settingsChange)
                return
            }
            recentAppTracker.record(app)
            updateOverlay(reason: .focusTransition)
        }
        focusEventService.start()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.clickCount == 2 {
            toggleDimming()
            return
        }

        let menu = NSMenu()
        menu.addItem(headerMenuItem())
        menu.addItem(intensityMenuItem())
        menu.addItem(applicationModeMenuItem())

        let loginItem = NSMenuItem(title: "로그인 시 열기", action: #selector(toggleOpenAtLogin), keyEquivalent: "")
        loginItem.state = settings.openAtLogin ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "설정...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "권한 요청", action: #selector(requestAccessibilityPermission), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Starlight 종료", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func headerMenuItem() -> NSMenuItem {
        let title = NSTextField(labelWithString: "Starlight")
        title.font = .boldSystemFont(ofSize: 16)

        let shortcut = NSTextField(labelWithString: "^⌥⌘F")
        shortcut.textColor = .tertiaryLabelColor
        shortcut.font = .systemFont(ofSize: 12)
        shortcut.alignment = .right

        let toggle = NSSwitch()
        toggle.state = settings.enabled ? .on : .off
        toggle.target = self
        toggle.action = #selector(menuEnabledChanged(_:))

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [title, spacer, shortcut, toggle])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: MenuLayout.horizontalInset, bottom: 10, right: MenuLayout.horizontalInset)
        stack.frame = NSRect(x: 0, y: 0, width: MenuLayout.width, height: 50)

        let item = NSMenuItem()
        item.view = stack
        return item
    }

    private func intensityMenuItem() -> NSMenuItem {
        let slider = NSSlider(value: settings.dimmingIntensity, minValue: 0.0, maxValue: 0.95, target: self, action: #selector(menuIntensityChanged(_:)))
        slider.widthAnchor.constraint(equalToConstant: 190).isActive = true

        let value = NSTextField(labelWithString: "\(Int(round(settings.dimmingIntensity * 100)))%")
        value.alignment = .right
        value.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        value.widthAnchor.constraint(equalToConstant: 38).isActive = true
        menuIntensityValueLabel = value

        let stack = NSStackView(views: [slider, value])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: MenuLayout.horizontalInset, bottom: 12, right: MenuLayout.horizontalInset)
        stack.frame = NSRect(x: 0, y: 0, width: MenuLayout.width, height: 52)

        let item = NSMenuItem()
        item.view = stack
        return item
    }

    private func applicationModeMenuItem() -> NSMenuItem {
        let singleSwitch = modeSwitch(
            isOn: false,
            action: #selector(menuSingleApplicationModeChanged(_:))
        )
        let multipleSwitch = modeSwitch(
            isOn: false,
            action: #selector(menuMultipleApplicationModeChanged(_:))
        )
        menuSingleModeSwitch = singleSwitch
        menuMultipleModeSwitch = multipleSwitch
        refreshMenuModeSwitches()

        let rows = NSStackView(views: [
            modeRow(title: "단일 앱", toggle: singleSwitch),
            modeRow(title: "다중 앱", badge: "BETA", toggle: multipleSwitch)
        ])
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 10

        let note = NSTextField(labelWithString: "다중 앱 적용 시 창 이동 중 지연이나 오차가 생길 수 있습니다.")
        note.textColor = .secondaryLabelColor
        note.font = .systemFont(ofSize: 8)
        note.maximumNumberOfLines = 1
        note.lineBreakMode = .byClipping
        note.preferredMaxLayoutWidth = MenuLayout.width - MenuLayout.horizontalInset * 2
        note.widthAnchor.constraint(equalToConstant: MenuLayout.width - MenuLayout.horizontalInset * 2).isActive = true

        let stack = NSStackView(views: [rows, note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 10, left: MenuLayout.horizontalInset, bottom: 12, right: MenuLayout.horizontalInset)
        stack.frame = NSRect(x: 0, y: 0, width: MenuLayout.width, height: 122)

        let item = NSMenuItem()
        item.view = stack
        return item
    }

    private func modeSwitch(isOn: Bool, action: Selector) -> NSSwitch {
        let toggle = NSSwitch()
        toggle.state = isOn ? .on : .off
        toggle.target = self
        toggle.action = action
        return toggle
    }

    private func modeRow(title: String, badge: String? = nil, toggle: NSSwitch) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)

        let titleStack = NSStackView(views: [label])
        titleStack.orientation = .horizontal
        titleStack.alignment = .centerY
        titleStack.spacing = 6

        if let badge {
            let badgeLabel = NSTextField(labelWithString: badge)
            badgeLabel.font = .systemFont(ofSize: 10, weight: .semibold)
            badgeLabel.textColor = .systemOrange
            titleStack.addArrangedSubview(badgeLabel)
        }

        titleStack.widthAnchor.constraint(equalToConstant: 184).isActive = true

        let row = NSStackView(views: [titleStack, toggle])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.frame = NSRect(x: 0, y: 0, width: MenuLayout.width - MenuLayout.horizontalInset * 2, height: 34)
        return row
    }

    @objc private func menuEnabledChanged(_ sender: NSSwitch) {
        settings.enabled = sender.state == .on
        refreshMenuModeSwitches()
        updateStatusIcon()
        updateOverlay(reason: .settingsChange)
    }

    @objc private func menuSingleApplicationModeChanged(_ sender: NSSwitch) {
        settings.appApplicationMode = sender.state == .on ? .single : .multiple
        refreshMenuModeSwitches()
    }

    @objc private func menuMultipleApplicationModeChanged(_ sender: NSSwitch) {
        settings.appApplicationMode = sender.state == .on ? .multiple : .single
        refreshMenuModeSwitches()
    }

    private func refreshMenuModeSwitches() {
        guard settings.enabled else {
            menuSingleModeSwitch?.state = .off
            menuMultipleModeSwitch?.state = .off
            menuSingleModeSwitch?.isEnabled = false
            menuMultipleModeSwitch?.isEnabled = false
            return
        }

        menuSingleModeSwitch?.isEnabled = true
        menuMultipleModeSwitch?.isEnabled = true
        menuSingleModeSwitch?.state = settings.appApplicationMode == .single ? .on : .off
        menuMultipleModeSwitch?.state = settings.appApplicationMode == .multiple ? .on : .off
    }

    @objc private func toggleDimming() {
        settings.enabled.toggle()
        refreshMenuModeSwitches()
        updateStatusIcon()
        updateOverlay(reason: .settingsChange)
    }

    @objc private func toggleOpenAtLogin() {
        settings.openAtLogin.toggle()
        applyOpenAtLoginSettingIfNeeded()
    }

    @objc private func menuIntensityChanged(_ sender: NSSlider) {
        settings.dimmingIntensity = sender.doubleValue
        menuIntensityValueLabel?.stringValue = "\(Int(round(settings.dimmingIntensity * 100)))%"
    }

    @objc private func openSettings() {
        settingsWindowController.show()
        updateOverlay(reason: .settingsChange)
    }

    @objc private func requestAccessibilityPermission() {
        permissionCoordinator.requestAccessibilityPermission()
        permissionCoordinator.openAccessibilitySettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func settingsDidChange() {
        recentAppTracker.limit = settings.effectiveRecentAppLimit
        if appliedKeyboardShortcutsEnabled != settings.keyboardShortcutsEnabled {
            keyboardShortcutController.setShortcutsEnabled(settings.keyboardShortcutsEnabled)
            appliedKeyboardShortcutsEnabled = settings.keyboardShortcutsEnabled
        }
        applyOpenAtLoginSettingIfNeeded()
        updateStatusIcon()
        updateOverlay(reason: .settingsChange)
    }

    @objc private func applicationActiveStateDidChange() {
        updateOverlay(reason: .settingsChange)
    }

    private func handleRefreshTimer() {
        let now = CACurrentMediaTime()
        guard Self.shouldRunTimedRefresh(
            settingsEnabled: settings.enabled,
            settingsWindowShouldDisableDimming: settingsWindowController.shouldDisableDimming,
            applicationMode: settings.appApplicationMode,
            elapsedSinceLastSingleRefresh: now - lastSingleApplicationRefreshTime,
            singleApplicationRefreshInterval: AppTiming.singleApplicationRefreshInterval
        ) else {
            return
        }

        if settings.appApplicationMode == .single {
            lastSingleApplicationRefreshTime = now
        }

        updateOverlay(reason: .refresh)
    }

    static func shouldRunTimedRefresh(
        settingsEnabled: Bool,
        settingsWindowShouldDisableDimming: Bool,
        applicationMode: AppApplicationMode,
        elapsedSinceLastSingleRefresh: TimeInterval,
        singleApplicationRefreshInterval: TimeInterval
    ) -> Bool {
        guard settingsEnabled, !settingsWindowShouldDisableDimming else {
            return false
        }

        switch applicationMode {
        case .single:
            return elapsedSinceLastSingleRefresh >= singleApplicationRefreshInterval
        case .multiple:
            return true
        }
    }

    private func updateOverlay(reason: DimmingOverlayManager.UpdateReason) {
        guard settings.enabled else {
            suppressDimmingWhileDisabled()
            return
        }

        guard !settingsWindowController.shouldDisableDimming else {
            suppressDimmingForSettingsWindow()
            return
        }

        isDimmingSuppressedForSettingsWindow = false
        isDimmingSuppressedWhileDisabled = false

        guard !isSettingsWindowDragging else {
            overlayManager.suppressForLocalWindowDrag()
            return
        }

        overlayManager.update(
            recentBundleIdentifiers: recentAppTracker.brightBundleIdentifiersInRecentOrder(),
            reason: reason
        )
    }

    private func suppressDimmingForSettingsWindow() {
        guard !isDimmingSuppressedForSettingsWindow else { return }
        isDimmingSuppressedForSettingsWindow = true
        overlayManager.hide()
    }

    private func suppressDimmingWhileDisabled() {
        guard !isDimmingSuppressedWhileDisabled else { return }
        isDimmingSuppressedWhileDisabled = true
        overlayManager.hide()
    }

    private func updateStatusIcon() {
        statusItem?.isVisible = settings.showStatusInMenuBar
        statusItem?.length = StatusItemLayout.length
        statusItem?.button?.contentTintColor = settings.enabled ? nil : .secondaryLabelColor
        statusItem?.button?.imagePosition = .imageOnly
        statusItem?.button?.imageScaling = .scaleProportionallyUpOrDown
        statusItem?.button?.title = ""
        statusItem?.button?.toolTip = settings.enabled ? "Starlight 켬" : "Starlight 끔"
    }

    private func handleShortcut(_ action: KeyboardShortcutController.Action) {
        switch action {
        case .toggle:
            toggleDimming()
        case .intensityUp:
            adjustIntensity(by: 0.05)
        case .intensityDown:
            adjustIntensity(by: -0.05)
        }
    }

    private func adjustIntensity(by delta: Double) {
        settings.dimmingIntensity = settings.dimmingIntensity + delta
    }

    private func applyOpenAtLoginSettingIfNeeded() {
        guard appliedOpenAtLogin != settings.openAtLogin else { return }
        guard canManageOpenAtLogin else {
            appliedOpenAtLogin = settings.openAtLogin
            return
        }

        do {
            if settings.openAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            appliedOpenAtLogin = settings.openAtLogin
        } catch {
            // TODO: Surface ServiceManagement failures in the Info tab when the app has a signed bundle.
            appliedOpenAtLogin = nil
            NSLog("Starlight login item update failed: \(error.localizedDescription)")
        }
    }

    private var canManageOpenAtLogin: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }
}
