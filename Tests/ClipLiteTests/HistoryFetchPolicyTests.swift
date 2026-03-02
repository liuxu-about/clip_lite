import XCTest
@testable import ClipLite

final class HistoryFetchPolicyTests: XCTestCase {
    func test_fetchLimit_PositiveValue_ReturnsSameValue() {
        XCTAssertEqual(HistoryFetchPolicy.fetchLimit(maxItemCount: 500), 500)
    }

    func test_fetchLimit_Zero_ReturnsOne() {
        XCTAssertEqual(HistoryFetchPolicy.fetchLimit(maxItemCount: 0), 1)
    }

    func test_fetchLimit_NegativeValue_ReturnsOne() {
        XCTAssertEqual(HistoryFetchPolicy.fetchLimit(maxItemCount: -32), 1)
    }
}
