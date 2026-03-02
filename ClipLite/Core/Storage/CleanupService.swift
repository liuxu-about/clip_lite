import Foundation

final class CleanupService {
    private let historyStore: HistoryStore
    private let queue = DispatchQueue(label: "com.cliplite.cleanup", qos: .utility)

    private var pendingWorkItem: DispatchWorkItem?

    init(historyStore: HistoryStore) {
        self.historyStore = historyStore
    }

    func runNow(settings: AppSettings, reason: String) {
        queue.async { [historyStore] in
            let deleted = historyStore.cleanup(
                maxItemCount: settings.maxItemCount,
                maxRetentionDays: settings.maxRetentionDays
            )
            Logger.info("Cleanup run (\(reason)): deleted=\(deleted)")
        }
    }

    func scheduleThrottled(settings: AppSettings, reason: String, delay: TimeInterval = 2.0) {
        pendingWorkItem?.cancel()

        let work = DispatchWorkItem { [historyStore] in
            let deleted = historyStore.cleanup(
                maxItemCount: settings.maxItemCount,
                maxRetentionDays: settings.maxRetentionDays
            )
            Logger.info("Cleanup run (\(reason), throttled): deleted=\(deleted)")
        }

        pendingWorkItem = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
