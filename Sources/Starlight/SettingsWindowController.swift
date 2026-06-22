import AppKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private enum WindowDragTiming {
        static let settleDelay: TimeInterval = 0.2
    }

    private let settings: SettingsStore

    var onWindowDragStateChanged: ((Bool) -> Void)?
    var onWindowVisibilityChanged: (() -> Void)?

    private let enabledSwitch = NSSwitch()
    private let openAtLoginSwitch = NSSwitch()
    private let showStatusSwitch = NSSwitch()
    private let verticalIntensityControl = VerticalIntensityControl()
    private let intensityValueLabel = NSTextField(labelWithString: "")
    private let colorWell = NSColorWell(frame: .zero)
    private let durationPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let appModeSegmented = NSSegmentedControl(labels: ["단일 앱", "다중 앱"], trackingMode: .selectOne, target: nil, action: nil)
    private let shortcutSwitch = NSSwitch()
    private let recentStepper = NSStepper()
    private let recentLabel = NSTextField(labelWithString: "")
    private var windowMoveEndTimer: Timer?
    private var isWindowDragActive = false

    init(settings: SettingsStore) {
        self.settings = settings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Starlight 설정"
        window.center()
        super.init(window: window)
        window.delegate = self
        setupContent()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refresh()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onWindowVisibilityChanged?()
    }

    var shouldDisableDimming: Bool {
        Self.shouldDisableDimming(
            isVisible: window?.isVisible == true,
            isMiniaturized: window?.isMiniaturized == true
        )
    }

    static func shouldDisableDimming(
        isVisible: Bool,
        isMiniaturized: Bool
    ) -> Bool {
        isVisible && !isMiniaturized
    }

    func windowWillMove(_ notification: Notification) {
        beginWindowDrag()
    }

    func windowDidMove(_ notification: Notification) {
        beginWindowDrag()
        scheduleWindowDragEnd()
    }

    func windowWillClose(_ notification: Notification) {
        finishWindowDrag()
        DispatchQueue.main.async { [weak self] in
            self?.onWindowVisibilityChanged?()
        }
    }

    func windowDidMiniaturize(_ notification: Notification) {
        onWindowVisibilityChanged?()
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        onWindowVisibilityChanged?()
    }


    private func beginWindowDrag() {
        scheduleWindowDragEnd()
        guard !isWindowDragActive else { return }
        isWindowDragActive = true
        onWindowDragStateChanged?(true)
    }

    private func scheduleWindowDragEnd() {
        windowMoveEndTimer?.invalidate()
        windowMoveEndTimer = Timer.scheduledTimer(withTimeInterval: WindowDragTiming.settleDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.finishWindowDragIfReady()
            }
        }
    }

    private func finishWindowDragIfReady() {
        guard (NSEvent.pressedMouseButtons & 1) == 0 else {
            scheduleWindowDragEnd()
            return
        }

        finishWindowDrag()
    }

    private func finishWindowDrag() {
        windowMoveEndTimer?.invalidate()
        windowMoveEndTimer = nil
        guard isWindowDragActive else { return }
        isWindowDragActive = false
        onWindowDragStateChanged?(false)
    }

    private func setupContent() {
        guard let contentView = window?.contentView else { return }

        let tabs = NSTabView()
        tabs.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabs)

        tabs.addTabViewItem(tab(title: "일반", view: generalTab()))
        tabs.addTabViewItem(tab(title: "고급/포커스", view: focusTab()))
        tabs.addTabViewItem(tab(title: "디스플레이", view: displayTab()))
        tabs.addTabViewItem(tab(title: "단축키", view: shortcutsTab()))
        tabs.addTabViewItem(tab(title: "정보", view: infoTab()))

        NSLayoutConstraint.activate([
            tabs.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tabs.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tabs.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            tabs.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    private func tab(title: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: title)
        item.label = title
        item.view = view
        return item
    }

    private func generalTab() -> NSView {
        let controls = tabStack()
        controls.addArrangedSubview(row(label: "Starlight 활성화", control: enabledSwitch))
        controls.addArrangedSubview(row(label: "로그인 시 열기", control: openAtLoginSwitch))
        controls.addArrangedSubview(row(label: "메뉴 막대에 상태 표시", control: showStatusSwitch))

        verticalIntensityControl.translatesAutoresizingMaskIntoConstraints = false
        verticalIntensityControl.target = self
        verticalIntensityControl.action = #selector(verticalIntensityChanged)
        verticalIntensityControl.widthAnchor.constraint(equalToConstant: 78).isActive = true
        verticalIntensityControl.heightAnchor.constraint(equalToConstant: 220).isActive = true

        intensityValueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        intensityValueLabel.alignment = .center
        intensityValueLabel.translatesAutoresizingMaskIntoConstraints = false
        intensityValueLabel.widthAnchor.constraint(equalToConstant: 78).isActive = true

        let intensityStack = NSStackView(views: [verticalIntensityControl, intensityValueLabel])
        intensityStack.orientation = .vertical
        intensityStack.alignment = .centerX
        intensityStack.spacing = 8

        let layout = NSStackView(views: [intensityStack, controls])
        layout.orientation = .horizontal
        layout.alignment = .centerY
        layout.spacing = 44

        enabledSwitch.target = self
        enabledSwitch.action = #selector(enabledChanged)
        openAtLoginSwitch.target = self
        openAtLoginSwitch.action = #selector(openAtLoginChanged)
        showStatusSwitch.target = self
        showStatusSwitch.action = #selector(showStatusChanged)

        return container(for: layout)
    }

    private func focusTab() -> NSView {
        let stack = tabStack()
        stack.addArrangedSubview(row(label: "적용 범위", control: appModeControl()))
        stack.addArrangedSubview(singleLineWarningLabel("다중 앱 적용 시 창 이동 중 지연이나 오차가 생길 수 있습니다."))
        stack.addArrangedSubview(row(label: "최근 앱 유지 개수", control: recentControl()))

        appModeSegmented.target = self
        appModeSegmented.action = #selector(applicationModeChanged)

        return container(for: stack, verticalOffset: -28)
    }

    private func displayTab() -> NSView {
        let stack = tabStack()
        stack.addArrangedSubview(row(label: "흐림 색상", control: colorWell))
        stack.addArrangedSubview(row(label: "애니메이션 시간", control: durationPopup))

        durationPopup.removeAllItems()
        for preset in AnimationDurationPreset.allCases {
            durationPopup.addItem(withTitle: preset.koreanTitle)
            durationPopup.lastItem?.representedObject = preset.rawValue
        }

        colorWell.target = self
        colorWell.action = #selector(colorChanged)
        durationPopup.target = self
        durationPopup.action = #selector(durationChanged)

        return container(for: stack, verticalOffset: -28)
    }

    private func shortcutsTab() -> NSView {
        let stack = tabStack()
        stack.addArrangedSubview(row(label: "전역 단축키 사용", control: shortcutSwitch))

        stack.addArrangedSubview(noteLabel("켜기/끄기: Control Option Command F\n강도 올리기: Control Option Command =\n강도 내리기: Control Option Command -"))

        shortcutSwitch.target = self
        shortcutSwitch.action = #selector(shortcutsEnabledChanged)

        return container(for: stack, verticalOffset: -28)
    }

    private func infoTab() -> NSView {
        let stack = tabStack()

        let title = NSTextField(labelWithString: "Starlight")
        title.font = .boldSystemFont(ofSize: 18)
        stack.addArrangedSubview(title)

        let report = noteLabel("버그 리포트는 lhs5427ll@gmail.com 으로 메일을 보내주세요.")
        stack.addArrangedSubview(report)

        return container(for: stack, verticalOffset: -28)
    }

    private func tabStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        return stack
    }

    private func appModeControl() -> NSStackView {
        appModeSegmented.widthAnchor.constraint(equalToConstant: 150).isActive = true

        let beta = NSTextField(labelWithString: "BETA")
        beta.font = .systemFont(ofSize: 11, weight: .semibold)
        beta.textColor = .systemOrange

        let stack = NSStackView(views: [appModeSegmented, beta])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        return stack
    }

    private func container(for stack: NSStackView, verticalOffset: CGFloat = 0) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 488, height: 352))
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let leading = stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24)
        leading.priority = .defaultLow
        let trailing = stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        trailing.priority = .defaultLow
        let top = stack.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: 24)
        top.priority = .defaultLow
        let bottom = stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -24)
        bottom.priority = .defaultLow

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: verticalOffset),
            leading,
            trailing,
            top,
            bottom
        ])
        return view
    }

    private func row(label: String, control: NSView) -> NSStackView {
        let labelView = NSTextField(labelWithString: label)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(equalToConstant: 170).isActive = true

        let row = NSStackView(views: [labelView, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func noteLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = 360
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 380).isActive = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    private func singleLineWarningLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 11)
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byClipping
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 430).isActive = true
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private func recentControl() -> NSStackView {
        recentStepper.minValue = 1
        recentStepper.maxValue = 10
        recentStepper.increment = 1
        recentStepper.target = self
        recentStepper.action = #selector(recentLimitChanged)

        recentLabel.translatesAutoresizingMaskIntoConstraints = false
        recentLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let stack = NSStackView(views: [recentStepper, recentLabel])
        stack.orientation = .horizontal
        stack.spacing = 8
        return stack
    }

    private func refresh() {
        enabledSwitch.state = settings.enabled ? .on : .off
        openAtLoginSwitch.state = settings.openAtLogin ? .on : .off
        showStatusSwitch.state = settings.showStatusInMenuBar ? .on : .off
        verticalIntensityControl.doubleValue = settings.dimmingIntensity
        intensityValueLabel.stringValue = "\(Int(round(settings.dimmingIntensity * 100)))%"
        colorWell.color = settings.dimmingColor
        selectDuration(settings.animationDuration)
        appModeSegmented.selectedSegment = settings.appApplicationMode == .single ? 0 : 1
        shortcutSwitch.state = settings.keyboardShortcutsEnabled ? .on : .off
        recentStepper.integerValue = settings.recentAppLimit
        recentStepper.isEnabled = settings.appApplicationMode == .multiple
        recentLabel.stringValue = settings.appApplicationMode == .single ? "1" : "\(settings.recentAppLimit)"
    }

    private func selectDuration(_ duration: Double) {
        for item in durationPopup.itemArray {
            guard let value = item.representedObject as? Double else { continue }
            if value == duration {
                durationPopup.select(item)
                return
            }
        }
    }

    @objc private func enabledChanged() {
        settings.enabled = enabledSwitch.state == .on
    }

    @objc private func openAtLoginChanged() {
        settings.openAtLogin = openAtLoginSwitch.state == .on
    }

    @objc private func showStatusChanged() {
        settings.showStatusInMenuBar = showStatusSwitch.state == .on
    }

    @objc private func verticalIntensityChanged() {
        settings.dimmingIntensity = verticalIntensityControl.doubleValue
        intensityValueLabel.stringValue = "\(Int(round(settings.dimmingIntensity * 100)))%"
    }

    @objc private func colorChanged() {
        settings.dimmingColor = colorWell.color
    }

    @objc private func durationChanged() {
        guard let duration = durationPopup.selectedItem?.representedObject as? Double else { return }
        settings.animationDuration = duration
    }

    @objc private func applicationModeChanged() {
        settings.appApplicationMode = appModeSegmented.selectedSegment == 0 ? .single : .multiple
        refresh()
    }

    @objc private func shortcutsEnabledChanged() {
        settings.keyboardShortcutsEnabled = shortcutSwitch.state == .on
    }

    @objc private func recentLimitChanged() {
        settings.recentAppLimit = recentStepper.integerValue
        recentLabel.stringValue = "\(settings.recentAppLimit)"
    }

}

private final class VerticalIntensityControl: NSControl {
    private var storedDoubleValue: Double = 0.5

    override var doubleValue: Double {
        get {
            storedDoubleValue
        }
        set {
            storedDoubleValue = max(0.0, min(0.95, newValue))
            needsDisplay = true
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let trackRect = bounds.insetBy(dx: 10, dy: 6)
        let backgroundPath = NSBezierPath(roundedRect: trackRect, xRadius: 18, yRadius: 18)
        NSColor.controlBackgroundColor.withAlphaComponent(0.9).setFill()
        backgroundPath.fill()

        let fillHeight = trackRect.height * CGFloat(doubleValue / 0.95)
        let fillRect = CGRect(
            x: trackRect.minX,
            y: trackRect.minY,
            width: trackRect.width,
            height: fillHeight
        )

        NSGraphicsContext.saveGraphicsState()
        backgroundPath.addClip()
        let fillPath = NSBezierPath(rect: fillRect)
        NSColor.systemBlue.withAlphaComponent(0.92).setFill()
        fillPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.separatorColor.withAlphaComponent(0.45).setStroke()
        backgroundPath.lineWidth = 1
        backgroundPath.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        updateValue(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updateValue(with: event)
    }

    private func updateValue(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let trackRect = bounds.insetBy(dx: 10, dy: 6)
        let normalized = (point.y - trackRect.minY) / max(trackRect.height, 1)
        doubleValue = Double(normalized) * 0.95
        sendAction(action, to: target)
    }
}
