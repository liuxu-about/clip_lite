import Combine
import Foundation

extension Notification.Name {
    static let clipLiteSettingsDidChange = Notification.Name("clipLiteSettingsDidChange")
}

@MainActor
final class SettingsManager: ObservableObject {
    @Published private(set) var settings: AppSettings

    private let defaults: UserDefaults
    private let key = "ClipLite.AppSettings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
    }

    func update(_ mutate: (inout AppSettings) -> Void) {
        var updated = settings
        mutate(&updated)

        if updated.maxItemCount < 1 {
            updated.maxItemCount = 1
        }
        if updated.maxRetentionDays < 1 {
            updated.maxRetentionDays = 1
        }

        settings = updated
        persist(updated)
        NotificationCenter.default.post(name: .clipLiteSettingsDidChange, object: nil)
    }

    private func persist(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            Logger.error("Failed to encode AppSettings")
            return
        }
        defaults.set(data, forKey: key)
    }
}
