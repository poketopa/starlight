import AppKit
import Foundation

extension Notification.Name {
    static let starlightSettingsDidChange = Notification.Name("StarlightSettingsDidChange")
}

enum AnimationDurationPreset: Double, CaseIterable {
    case off = 0.0
    case fast = 0.3
    case normal = 0.5
    case slow = 1.0
    case verySlow = 3.0

    var koreanTitle: String {
        switch self {
        case .off:
            "끔"
        case .fast:
            "0.3초"
        case .normal:
            "0.5초"
        case .slow:
            "1초"
        case .verySlow:
            "3초"
        }
    }

    static func nearest(to duration: Double) -> AnimationDurationPreset {
        allCases.min { abs($0.rawValue - duration) < abs($1.rawValue - duration) } ?? .normal
    }
}

enum AppApplicationMode: String, CaseIterable, Codable {
    case single
    case multiple

    var koreanTitle: String {
        switch self {
        case .single:
            "단일 앱 적용"
        case .multiple:
            "다중 앱 적용 (BETA)"
        }
    }
}

@MainActor
final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults: UserDefaults

    private enum Key {
        static let enabled = "enabled"
        static let dimmingIntensity = "dimmingIntensity"
        static let dimmingColorHex = "dimmingColorHex"
        static let animationDuration = "animationDuration"
        static let recentAppLimit = "recentAppLimit"
        static let openAtLogin = "openAtLogin"
        static let showStatusInMenuBar = "showStatusInMenuBar"
        static let appApplicationMode = "appApplicationMode"
        static let keyboardShortcutsEnabled = "keyboardShortcutsEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { set(newValue, for: Key.enabled) }
    }

    var dimmingIntensity: Double {
        get { clamp(defaults.double(forKey: Key.dimmingIntensity), min: 0.0, max: 0.95) }
        set { set(clamp(newValue, min: 0.0, max: 0.95), for: Key.dimmingIntensity) }
    }

    var dimmingColor: NSColor {
        get { NSColor(hex: defaults.string(forKey: Key.dimmingColorHex) ?? "000000") ?? .black }
        set { set(newValue.hexString ?? "000000", for: Key.dimmingColorHex) }
    }

    var animationDuration: Double {
        get { AnimationDurationPreset.nearest(to: defaults.double(forKey: Key.animationDuration)).rawValue }
        set { set(AnimationDurationPreset.nearest(to: newValue).rawValue, for: Key.animationDuration) }
    }

    var recentAppLimit: Int {
        get { max(1, min(defaults.integer(forKey: Key.recentAppLimit), 10)) }
        set { set(max(1, min(newValue, 10)), for: Key.recentAppLimit) }
    }

    var effectiveRecentAppLimit: Int {
        appApplicationMode == .single ? 1 : recentAppLimit
    }

    var openAtLogin: Bool {
        get { defaults.bool(forKey: Key.openAtLogin) }
        set { set(newValue, for: Key.openAtLogin) }
    }

    var showStatusInMenuBar: Bool {
        get { defaults.bool(forKey: Key.showStatusInMenuBar) }
        set { set(newValue, for: Key.showStatusInMenuBar) }
    }

    var appApplicationMode: AppApplicationMode {
        get {
            guard let value = defaults.string(forKey: Key.appApplicationMode),
                  let mode = AppApplicationMode(rawValue: value) else {
                return .single
            }
            return mode
        }
        set { set(newValue.rawValue, for: Key.appApplicationMode) }
    }

    var keyboardShortcutsEnabled: Bool {
        get { defaults.bool(forKey: Key.keyboardShortcutsEnabled) }
        set { set(newValue, for: Key.keyboardShortcutsEnabled) }
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.dimmingIntensity: 0.5,
            Key.dimmingColorHex: "000000",
            Key.animationDuration: AnimationDurationPreset.normal.rawValue,
            Key.recentAppLimit: 3,
            Key.openAtLogin: true,
            Key.showStatusInMenuBar: true,
            Key.appApplicationMode: AppApplicationMode.single.rawValue,
            Key.keyboardShortcutsEnabled: true
        ])
    }

    private func set(_ value: Bool, for key: String) {
        guard defaults.bool(forKey: key) != value else { return }
        defaults.set(value, forKey: key)
        notify()
    }

    private func set(_ value: Double, for key: String) {
        guard defaults.double(forKey: key) != value else { return }
        defaults.set(value, forKey: key)
        notify()
    }

    private func set(_ value: Int, for key: String) {
        guard defaults.integer(forKey: key) != value else { return }
        defaults.set(value, forKey: key)
        notify()
    }

    private func set(_ value: String, for key: String) {
        guard defaults.string(forKey: key) != value else { return }
        defaults.set(value, forKey: key)
        notify()
    }

    private func notify() {
        NotificationCenter.default.post(name: .starlightSettingsDidChange, object: self)
    }
}

private func clamp<T: Comparable>(_ value: T, min lower: T, max upper: T) -> T {
    Swift.max(lower, Swift.min(value, upper))
}

extension NSColor {
    convenience init?(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard sanitized.count == 6, let value = Int(sanitized, radix: 16) else { return nil }
        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        self.init(calibratedRed: red, green: green, blue: blue, alpha: 1.0)
    }

    var hexString: String? {
        guard let color = usingColorSpace(.deviceRGB) else { return nil }
        let red = Int(round(color.redComponent * 255.0))
        let green = Int(round(color.greenComponent * 255.0))
        let blue = Int(round(color.blueComponent * 255.0))
        return String(format: "%02X%02X%02X", red, green, blue)
    }
}
