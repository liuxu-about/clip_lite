import AppKit
import Foundation
import SwiftUI

@MainActor
final class ClipboardPanelController: NSObject {
    private static let panelWidth: CGFloat = 748
    private static let panelHeight: CGFloat = 372

    var onDidHide: (() -> Void)?

    private let viewModel: ClipboardPanelViewModel
    private let onConfirmSelection: () -> Void
    private var panel: ClipboardPanel?
    private var isHiding = false

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    init(viewModel: ClipboardPanelViewModel, onConfirmSelection: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onConfirmSelection = onConfirmSelection
        super.init()
    }

    func show(anchorRect: NSRect? = nil) {
        let panel = ensurePanel()
        panel.setFrame(
            presentedFrame(anchorRect: anchorRect, width: Self.panelWidth, height: Self.panelHeight),
            display: true
        )
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard let panel, panel.isVisible, !isHiding else { return }
        isHiding = true
        panel.orderOut(nil)
        isHiding = false
        onDidHide?()
    }

    private func ensurePanel() -> ClipboardPanel {
        if let panel {
            return panel
        }

        let panel = ClipboardPanel(
            contentRect: topCenteredFrame(width: Self.panelWidth, height: Self.panelHeight)
        )
        panel.delegate = self

        let rootView = ClipboardPanelView(
            viewModel: viewModel,
            onConfirmSelection: onConfirmSelection
        )
        let hostingView = NSHostingView(rootView: rootView)
        panel.contentView = hostingView

        self.panel = panel
        return panel
    }

    private func presentedFrame(anchorRect: NSRect?, width: CGFloat, height: CGFloat) -> NSRect {
        guard let anchorRect else {
            return topCenteredFrame(width: width, height: height)
        }

        let anchorCenter = CGPoint(x: anchorRect.midX, y: anchorRect.midY)
        guard let screen = screenContaining(point: anchorCenter) ?? NSScreen.main else {
            return topCenteredFrame(width: width, height: height)
        }

        let visible = screen.visibleFrame
        let horizontalGap: CGFloat = 10
        let verticalGap: CGFloat = 8

        // Always prefer right side of the anchor. If it overflows, clamp within screen
        // bounds instead of flipping to the left side.
        var x = anchorRect.maxX + horizontalGap
        var y = anchorRect.minY - height - verticalGap

        if y < visible.minY {
            y = anchorRect.maxY + verticalGap
        }

        x = min(max(x, visible.minX), visible.maxX - width)
        y = min(max(y, visible.minY), visible.maxY - height)

        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func screenContaining(point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func topCenteredFrame(width: CGFloat, height: CGFloat) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 240, y: 360, width: width, height: height)
        }

        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.midX - (width / 2)
        let y = visibleFrame.maxY - height - 120
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

extension ClipboardPanelController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
