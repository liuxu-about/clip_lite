import Foundation
import XCTest
@testable import ClipLite

final class SQLiteManagerIntegrationTests: XCTestCase {
    private var tempDirectory: URL!
    private var sqlite: SQLiteManager!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipLiteSQLiteTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        sqlite = try SQLiteManager(path: databasePath.path)
        try sqlite.initializeSchema()
    }

    override func tearDownWithError() throws {
        sqlite = nil
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    func test_cleanup_WithCutoffDate_DeletesOlderRecords() throws {
        let oldDate = Date(timeIntervalSinceNow: -40 * 24 * 60 * 60)
        let newDate = Date()

        let oldItem = makeTextItem(text: "old", createdAt: oldDate)
        let newItem = makeTextItem(text: "new", createdAt: newDate)

        try sqlite.insertClip(oldItem)
        try sqlite.insertClip(newItem)

        let cutoffDate = Date(timeIntervalSinceNow: -30 * 24 * 60 * 60)
        let deleted = try sqlite.cleanup(maxItemCount: 100, cutoffDate: cutoffDate)

        XCTAssertEqual(deleted.count, 1)
        XCTAssertEqual(Set(deleted.map(\.id)), [oldItem.id.uuidString])

        let remaining = try sqlite.fetchRecent(limit: 10)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0].id, newItem.id)
    }

    func test_cleanup_WithMaxItemCount_DeletesOverflowRecords() throws {
        for idx in 0..<4 {
            let createdAt = Date(timeIntervalSinceNow: TimeInterval(-idx))
            try sqlite.insertClip(makeTextItem(text: "item-\(idx)", createdAt: createdAt))
        }

        let deleted = try sqlite.cleanup(maxItemCount: 2, cutoffDate: .distantPast)
        XCTAssertEqual(deleted.count, 2)

        let remaining = try sqlite.fetchRecent(limit: 10)
        XCTAssertEqual(remaining.count, 2)
    }

    private func makeTextItem(text: String, createdAt: Date) -> ClipItem {
        ClipItem(
            type: .text,
            createdAt: createdAt,
            hashValue: Hashing.sha256(text),
            textContent: text,
            textPreview: text
        )
    }

    private var databasePath: URL {
        tempDirectory.appendingPathComponent("clips.sqlite", isDirectory: false)
    }
}
