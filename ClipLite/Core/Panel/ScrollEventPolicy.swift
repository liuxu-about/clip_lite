import AppKit
import Foundation

enum ScrollEventPolicy {
    static func shouldAllowScroll(
        scrollingDeltaX: CGFloat,
        scrollingDeltaY: CGFloat,
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase
    ) -> Bool {
        if scrollingDeltaX != 0 || scrollingDeltaY != 0 {
            return true
        }

        if phase != [] || momentumPhase != [] {
            return true
        }

        return false
    }
}
