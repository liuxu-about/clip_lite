import Foundation
import XCTest
@testable import ClipLite

final class HistoryStoreIntegrationTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipLiteHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    func test_saveTextClipAndFetchRecent_ReturnsNewestFirst() throws {
        let store = try makeStore()
        let settings = settings(ignoreConsecutiveDuplicates: false, ignoreWhitespaceText: true)

        guard case .inserted = store.saveTextClip("first", settings: settings) else {
            XCTFail("Expected first insert to succeed")
            return
        }

        Thread.sleep(forTimeInterval: 0.02)

        guard case .inserted = store.saveTextClip("second", settings: settings) else {
            XCTFail("Expected second insert to succeed")
            return
        }

        let items = store.fetchRecent(limit: 10)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].textContent, "second")
        XCTAssertEqual(items[1].textContent, "first")
    }

    func test_saveTextClip_WhenConsecutiveDuplicateEnabled_IgnoresSecondEntry() throws {
        let store = try makeStore()
        let settings = settings(ignoreConsecutiveDuplicates: true, ignoreWhitespaceText: true)

        guard case .inserted = store.saveTextClip("duplicate", settings: settings) else {
            XCTFail("Expected first insert to succeed")
            return
        }

        guard case .ignored = store.saveTextClip("duplicate", settings: settings) else {
            XCTFail("Expected second insert to be ignored as consecutive duplicate")
            return
        }

        let items = store.fetchRecent(limit: 10)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].textContent, "duplicate")
    }

    func test_cleanup_WhenMaxItemCountExceeded_DeletesOverflow() throws {
        let store = try makeStore()
        let settings = settings(ignoreConsecutiveDuplicates: false, ignoreWhitespaceText: true)

        for index in 1...5 {
            guard case .inserted = store.saveTextClip("item-\(index)", settings: settings) else {
                XCTFail("Expected insert \(index) to succeed")
                return
            }
            Thread.sleep(forTimeInterval: 0.01)
        }

        let deleted = store.cleanup(maxItemCount: 3, maxRetentionDays: 365)
        XCTAssertEqual(deleted, 2)

        let items = store.fetchRecent(limit: 10)
        XCTAssertEqual(items.count, 3)
    }

    private func makeStore() throws -> HistoryStore {
        try HistoryStore(databasePath: databasePath.path)
    }

    private var databasePath: URL {
        tempDirectory.appendingPathComponent("clips.sqlite", isDirectory: false)
    }

    private func settings(
        ignoreConsecutiveDuplicates: Bool,
        ignoreWhitespaceText: Bool
    ) -> AppSettings {
        var settings = AppSettings.default
        settings.ignoreConsecutiveDuplicates = ignoreConsecutiveDuplicates
        settings.ignoreWhitespaceText = ignoreWhitespaceText
        return settings
    }
}
