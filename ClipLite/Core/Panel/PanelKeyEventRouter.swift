import AppKit
import Foundation

@MainActor
final class PanelKeyEventRouter {
    private var localMonitor: Any?

    private let onMoveUp: () -> Void
    private let onMoveDown: () -> Void
    private let onConfirm: () -> Void
    private let onSelectByNumber: (Int) -> Bool
    private let onSearchTrigger: () -> Bool
    private let onTogglePreview: () -> Bool
    private let onEscape: () -> Void

    init(
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onConfirm: @escaping () -> Void,
        onSelectByNumber: @escaping (Int) -> Bool,
        onSearchTrigger: @escaping () -> Bool,
        onTogglePreview: @escaping () -> Bool,
        onEscape: @escaping () -> Void
    ) {
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onConfirm = onConfirm
        self.onSelectByNumber = onSelectByNumber
        self.onSearchTrigger = onSearchTrigger
        self.onTogglePreview = onTogglePreview
        self.onEscape = onEscape
    }

    func start() {
        guard localMonitor == nil else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event: event) == true ? nil : event
        }
    }

    func stop() {
        guard let localMonitor else { return }
        NSEvent.removeMonitor(localMonitor)
        self.localMonitor = nil
    }

    private func handle(event: NSEvent) -> Bool {
        if handleSearchTrigger(event: event) {
            return true
        }

        if handleNumericSelection(event: event) {
            return true
        }

        switch Int(event.keyCode) {
        case 126: // up
            onMoveUp()
            return true
        case 125: // down
            onMoveDown()
            return true
        case 36, 76: // return / keypad enter
            onConfirm()
            return true
        case 49: // space
            return handleSpaceToggle(event: event)
        case 53: // escape
            onEscape()
            return true
        default:
            return false
        }
    }

    private func handleNumericSelection(event: NSEvent) -> Bool {
        if !event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            return false
        }

        guard
            let chars = event.charactersIgnoringModifiers,
            chars.count == 1,
            let char = chars.first,
            let number = Int(String(char)),
            (1...9).contains(number)
        else {
            return false
        }

        return onSelectByNumber(number)
    }

    private func handleSearchTrigger(event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        guard modifiers == [.command] else {
            return false
        }

        guard event.charactersIgnoringModifiers?.lowercased() == "f" else {
            return false
        }

        return onSearchTrigger()
    }

    private func handleSpaceToggle(event: NSEvent) -> Bool {
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            return false
        }

        return onTogglePreview()
    }
}
