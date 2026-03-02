import Foundation

enum HistoryFetchPolicy {
    static func fetchLimit(maxItemCount: Int) -> Int {
        max(1, maxItemCount)
    }
}
