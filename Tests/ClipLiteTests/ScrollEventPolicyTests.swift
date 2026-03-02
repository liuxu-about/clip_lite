import AppKit
import XCTest
@testable import ClipLite

final class ScrollEventPolicyTests: XCTestCase {
    func test_shouldAllowScroll_MouseWheelDeltaOnly_ReturnsTrue() {
        let allowed = ScrollEventPolicy.shouldAllowScroll(
            scrollingDeltaX: 0,
            scrollingDeltaY: 1,
            phase: [],
            momentumPhase: []
        )

        XCTAssertTrue(allowed)
    }

    func test_shouldAllowScroll_TrackpadPhaseOnly_ReturnsTrue() {
        let allowed = ScrollEventPolicy.shouldAllowScroll(
            scrollingDeltaX: 0,
            scrollingDeltaY: 0,
            phase: .began,
            momentumPhase: []
        )

        XCTAssertTrue(allowed)
    }

    func test_shouldAllowScroll_NoDeltaNoPhase_ReturnsFalse() {
        let allowed = ScrollEventPolicy.shouldAllowScroll(
            scrollingDeltaX: 0,
            scrollingDeltaY: 0,
            phase: [],
            momentumPhase: []
        )

        XCTAssertFalse(allowed)
    }
}
