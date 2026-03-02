import AppKit
import Carbon
import Foundation

enum PasteExecutionResult {
    case autoPasted
    case copiedOnly(reason: String)
    case failed(reason: String)
}

final class PasteExecutor {
    var onDidWritePasteboard: ((Int) -> Void)?

    private let permissionService: AccessibilityPermissionService

    init(permissionService: AccessibilityPermissionService) {
        self.permissionService = permissionService
    }

    func paste(item: ClipItem, promptForPermissionIfNeeded: Bool) -> PasteExecutionResult {
        guard writeToPasteboard(item: item) else {
            return .failed(reason: "Unable to write item into system pasteboard")
        }

        let trusted = permissionService.isTrusted(prompt: promptForPermissionIfNeeded)
        guard trusted else {
            return .copiedOnly(reason: "Accessibility permission is missing. Content is copied; press Command+V manually.")
        }

        guard postCommandV() else {
            return .copiedOnly(reason: "Failed to synthesize Command+V. Content is copied; press Command+V manually.")
        }

        return .autoPasted
    }

    private func writeToPasteboard(item: ClipItem) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let success: Bool

        switch item.type {
        case .text:
            guard let text = item.textContent else { return false }
            success = pasteboard.setString(text, forType: .string)

        case .image:
            guard
                let relativePath = item.imagePath,
                let imageURL = try? AppPaths.resolveRelativePath(relativePath),
                let image = NSImage(contentsOf: imageURL)
            else {
                return false
            }

            if pasteboard.writeObjects([image]) {
                success = true
            } else if let tiff = image.tiffRepresentation {
                success = pasteboard.setData(tiff, forType: .tiff)
            } else {
                success = false
            }
        }

        if success {
            onDidWritePasteboard?(pasteboard.changeCount)
        }

        return success
    }

    private func postCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: true
              ),
              let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
              ) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
