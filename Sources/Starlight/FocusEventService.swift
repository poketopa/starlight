import AppKit
import Foundation

@MainActor
final class FocusEventService {
    var onActivatedApp: ((AppIdentity) -> Void)?

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleActivatedApplication(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        if let app = NSWorkspace.shared.frontmostApplication {
            publish(app)
        }
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func handleActivatedApplication(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        publish(app)
    }

    private func publish(_ app: NSRunningApplication) {
        guard let bundleIdentifier = app.bundleIdentifier else { return }
        let name = app.localizedName ?? bundleIdentifier
        onActivatedApp?(AppIdentity(bundleIdentifier: bundleIdentifier, name: name))
    }
}
