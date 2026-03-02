import AppKit
import Foundation

struct ClipboardImagePayload: Sendable {
    let data: Data
    let width: Int
    let height: Int
}

enum ClipboardPayload: Sendable {
    case text(String)
    case image(ClipboardImagePayload)
}

struct ClipboardParser {
    func parse(from pasteboard: NSPasteboard) -> ClipboardPayload? {
        if let image = parseImage(from: pasteboard) {
            return .image(image)
        }

        if let text = pasteboard.string(forType: .string) {
            return .text(text)
        }

        return nil
    }

    private func parseImage(from pasteboard: NSPasteboard) -> ClipboardImagePayload? {
        if let pngData = pasteboard.data(forType: .png),
           let image = NSImage(data: pngData) {
            return payload(from: image, fallbackData: pngData)
        }

        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData) {
            return payload(from: image, fallbackData: tiffData)
        }

        if let image = NSImage(pasteboard: pasteboard),
           let tiffData = image.tiffRepresentation {
            return payload(from: image, fallbackData: tiffData)
        }

        return nil
    }

    private func payload(from image: NSImage, fallbackData: Data) -> ClipboardImagePayload? {
        let size = image.size
        let width = Int(max(1, round(size.width)))
        let height = Int(max(1, round(size.height)))

        let encodedData: Data
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            encodedData = png
        } else {
            encodedData = fallbackData
        }

        return ClipboardImagePayload(data: encodedData, width: width, height: height)
    }

    static func normalizeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    static func makePreview(_ text: String, maxLength: Int = 120) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ⏎ ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if compact.count <= maxLength {
            return compact
        }

        let endIndex = compact.index(compact.startIndex, offsetBy: maxLength)
        return String(compact[..<endIndex]) + "..."
    }
}
