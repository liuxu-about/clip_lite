import Foundation
import XCTest
@testable import ClipLite

final class ClipboardMonitorTests: XCTestCase {
    func test_burstPolling_CapturesRapidConsecutiveCopies() {
        let source = MockClipboardSource()
        let savedState = SavedTextState()

        let monitor = ClipboardMonitor(
            clipboardSource: source,
            parsePayload: {
                source.currentPayload
            },
            savePayload: { payload, _ in
                guard case .text(let text) = payload else {
                    return .ignored("Unexpected payload type")
                }

                savedState.append(text)

                let item = ClipItem(
                    type: .text,
                    hashValue: Hashing.sha256(text + UUID().uuidString),
                    textContent: text,
                    textPreview: text
                )
                return .inserted(item)
            },
            pollingInterval: 10.0,
            burstPollingInterval: 0.01,
            burstPollIterations: 40
        )
        monitor.settingsProvider = { .default }
        monitor.start()
        defer { monitor.stop() }

        source.copyText("A")
        monitor.pollNowForTesting()

        source.copyText("B")
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        source.copyText("C")

        let deadline = Date().addingTimeInterval(1.0)
        while savedState.count < 3, Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }

        XCTAssertEqual(savedState.snapshot(), ["A", "B", "C"])
    }
}

private final class MockClipboardSource: ClipboardChangeSource {
    private let lock = NSLock()
    private var internalChangeCount = 0
    private var internalPayload: ClipboardPayload?

    var changeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return internalChangeCount
    }

    var currentPayload: ClipboardPayload? {
        lock.lock()
        defer { lock.unlock() }
        return internalPayload
    }

    func copyText(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        internalChangeCount += 1
        internalPayload = .text(text)
    }
}

private final class SavedTextState: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return values.count
    }

    func append(_ value: String) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}
