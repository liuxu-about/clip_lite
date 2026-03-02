import AppKit
import Foundation

final class ThumbnailGenerator {
    func generateThumbnailData(from imageData: Data, maxPixel: CGFloat = 280) -> Data? {
        guard let image = NSImage(data: imageData) else {
            return nil
        }

        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return nil
        }

        let ratio = min(maxPixel / sourceSize.width, maxPixel / sourceSize.height, 1.0)
        let targetSize = NSSize(width: max(1, floor(sourceSize.width * ratio)), height: max(1, floor(sourceSize.height * ratio)))

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width),
            pixelsHigh: Int(targetSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        NSGraphicsContext.current = context
        context.imageInterpolation = .high

        let targetRect = NSRect(origin: .zero, size: targetSize)
        image.draw(in: targetRect, from: .zero, operation: .copy, fraction: 1.0)
        context.flushGraphics()

        if let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) {
            return jpegData
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}
