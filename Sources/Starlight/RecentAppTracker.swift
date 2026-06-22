import Foundation

final class RecentAppTracker {
    private let maxHistoryCount = 50
    private(set) var recentApps: [AppIdentity] = []
    var limit: Int {
        didSet {
            limit = max(1, min(limit, 10))
            trim()
        }
    }

    init(limit: Int) {
        self.limit = max(1, min(limit, 10))
    }

    func record(_ app: AppIdentity) {
        guard !app.bundleIdentifier.isEmpty else { return }

        recentApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        recentApps.insert(app, at: 0)
        trim()
    }

    func brightBundleIdentifiers() -> Set<String> {
        Set(recentApps.prefix(limit).map(\.bundleIdentifier))
    }

    func brightBundleIdentifiersInRecentOrder() -> [String] {
        recentApps.map(\.bundleIdentifier)
    }

    private func trim() {
        if recentApps.count > maxHistoryCount {
            recentApps = Array(recentApps.prefix(maxHistoryCount))
        }
    }
}
