import Foundation

final class FileStorage {
    func saveOriginalImage(data: Data, id: UUID) throws -> String {
        let fileURL = try AppPaths.originalImagesDirectory().appendingPathComponent("\(id.uuidString).png")
        try data.write(to: fileURL, options: .atomic)
        return try AppPaths.makeRelativePath(from: fileURL)
    }

    func saveThumbnailImage(data: Data, id: UUID) throws -> String {
        let fileURL = try AppPaths.thumbnailImagesDirectory().appendingPathComponent("\(id.uuidString).jpg")
        try data.write(to: fileURL, options: .atomic)
        return try AppPaths.makeRelativePath(from: fileURL)
    }

    func delete(relativePath: String) {
        guard let url = try? AppPaths.resolveRelativePath(relativePath) else {
            Logger.warning("Rejected file deletion for invalid path: \(relativePath)")
            return
        }

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Logger.warning("Failed to delete file at \(url.path): \(error)")
        }
    }
}
