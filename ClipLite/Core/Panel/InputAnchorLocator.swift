import AppKit
import ApplicationServices
import Foundation

/// Resolves the currently focused input-like element frame (if available) for panel anchoring.
final class InputAnchorLocator {
    private let permissionService: AccessibilityPermissionService
    private var hasPromptedForPermission = false

    init(permissionService: AccessibilityPermissionService) {
        self.permissionService = permissionService
    }

    func focusedElementFrameInScreen() -> NSRect? {
        guard ensureAccessibilityPermission() else {
            return nil
        }

        if let appElement = frontmostApplicationElement(),
           let frame = focusedElementOrWindowFrame(from: appElement) {
            return convertAXRectToAppKit(frame)
        }

        let systemWide = AXUIElementCreateSystemWide()
        if let focusedElement = focusedUIElement(from: systemWide),
           let frame = frame(for: focusedElement) {
            return convertAXRectToAppKit(frame)
        }

        if let focusedApp = focusedApplication(from: systemWide),
           let frame = focusedElementOrWindowFrame(from: focusedApp) {
            return convertAXRectToAppKit(frame)
        }

        return nil
    }

    private func ensureAccessibilityPermission() -> Bool {
        if permissionService.isTrusted(prompt: false) {
            return true
        }

        if !hasPromptedForPermission {
            hasPromptedForPermission = true
            _ = permissionService.isTrusted(prompt: true)
            Logger.warning("Accessibility permission missing; panel anchor falls back to default position.")
        }

        return false
    }

    private func frontmostApplicationElement() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    private func focusedApplication(from systemWide: AXUIElement) -> AXUIElement? {
        copyAXElement(from: systemWide, attribute: kAXFocusedApplicationAttribute as CFString)
    }

    private func focusedUIElement(from axElement: AXUIElement) -> AXUIElement? {
        copyAXElement(from: axElement, attribute: kAXFocusedUIElementAttribute as CFString)
    }

    private func focusedWindow(from axElement: AXUIElement) -> AXUIElement? {
        copyAXElement(from: axElement, attribute: kAXFocusedWindowAttribute as CFString)
    }

    private func copyAXElement(from element: AXUIElement, attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            attribute,
            &value
        )
        guard result == .success, let rawValue = value else {
            return nil
        }
        guard CFGetTypeID(rawValue) == AXUIElementGetTypeID() else {
            return nil
        }
        return (rawValue as! AXUIElement)
    }

    private func focusedElementOrWindowFrame(from axElement: AXUIElement) -> CGRect? {
        if let focusedElement = focusedUIElement(from: axElement),
           let focusedElementFrame = frame(for: focusedElement) {
            return focusedElementFrame
        }

        if let focusedWindow = focusedWindow(from: axElement),
           let focusedWindowFrame = frame(for: focusedWindow) {
            return focusedWindowFrame
        }

        return nil
    }

    private func frame(for element: AXUIElement) -> CGRect? {
        guard let positionValue = copyAXValue(from: element, attribute: kAXPositionAttribute as CFString),
              let sizeValue = copyAXValue(from: element, attribute: kAXSizeAttribute as CFString) else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size),
              size.width > 0,
              size.height > 0 else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func copyAXValue(from element: AXUIElement, attribute: CFString) -> AXValue? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let rawValue = value else {
            return nil
        }
        guard CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }
        return (rawValue as! AXValue)
    }

    private func convertAXRectToAppKit(_ rect: CGRect) -> NSRect {
        for screen in NSScreen.screens {
            let convertedY = screen.frame.maxY - rect.origin.y - rect.height
            let converted = CGRect(
                x: rect.origin.x,
                y: convertedY,
                width: rect.width,
                height: rect.height
            )
            if screen.frame.intersects(converted) {
                return converted
            }
        }

        return rect
    }
}
