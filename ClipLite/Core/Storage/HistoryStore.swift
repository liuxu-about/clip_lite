import Foundation

enum SaveClipResult {
    case inserted(ClipItem)
    case ignored(String)
    case failed(String)
}

final class HistoryStore: @unchecked Sendable {
    private let sqlite: SQLiteManager
    private let fileStorage: FileStorage
    private let thumbnailGenerator: ThumbnailGenerator
    private let queue = DispatchQueue(label: "com.cliplite.history.store")

    init(
        databasePath: String? = nil,
        fileStorage: FileStorage = FileStorage(),
        thumbnailGenerator: ThumbnailGenerator = ThumbnailGenerator()
    ) throws {
        let resolvedDatabasePath: String
        if let databasePath {
            let dbURL = URL(fileURLWithPath: databasePath)
            let parentDirectory = dbURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            resolvedDatabasePath = dbURL.path
        } else {
            let dbURL = try AppPaths.databaseFileURL()
            resolvedDatabasePath = dbURL.path
        }

        sqlite = try SQLiteManager(path: resolvedDatabasePath)
        try sqlite.initializeSchema()
        self.fileStorage = fileStorage
        self.thumbnailGenerator = thumbnailGenerator
    }

    func saveTextClip(_ rawText: String, settings: AppSettings) -> SaveClipResult {
        queue.sync {
            let normalized = ClipboardParser.normalizeText(rawText)
            if settings.ignoreWhitespaceText &&
                normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .ignored("Empty or whitespace-only text")
            }

            let hash = Hashing.sha256(normalized)

            do {
                if settings.ignoreConsecutiveDuplicates,
                    let latestHash = try sqlite.fetchLatestHash(),
                    latestHash == hash {
                    return .ignored("Consecutive duplicate")
                }

                let item = ClipItem(
                    type: .text,
                    hashValue: hash,
                    textContent: normalized,
                    textPreview: ClipboardParser.makePreview(normalized)
                )

                try sqlite.insertClip(item)
                return .inserted(item)
            } catch {
                return .failed("SQLite write failed: \(error)")
            }
        }
    }

    func saveImageClip(data: Data, width: Int, height: Int, settings: AppSettings) -> SaveClipResult {
        queue.sync {
            let hash = Hashing.sha256(data)

            do {
                if settings.ignoreConsecutiveDuplicates,
                    let latestHash = try sqlite.fetchLatestHash(),
                    latestHash == hash {
                    return .ignored("Consecutive duplicate")
                }

                let clipID = UUID()
                let originalRelativePath = try fileStorage.saveOriginalImage(data: data, id: clipID)

                var thumbnailRelativePath: String?
                if let thumbnailData = thumbnailGenerator.generateThumbnailData(from: data) {
                    do {
                        thumbnailRelativePath = try fileStorage.saveThumbnailImage(data: thumbnailData, id: clipID)
                    } catch {
                        Logger.warning("Thumbnail write failed for clip \(clipID): \(error)")
                    }
                }

                let preview = "Image \(width)x\(height)"
                let item = ClipItem(
                    id: clipID,
                    type: .image,
                    hashValue: hash,
                    textContent: nil,
                    textPreview: preview,
                    imagePath: originalRelativePath,
                    thumbnailPath: thumbnailRelativePath,
                    fileSize: Int64(data.count),
                    imageWidth: width,
                    imageHeight: height
                )

                do {
                    try sqlite.insertClip(item)
                    return .inserted(item)
                } catch {
                    fileStorage.delete(relativePath: originalRelativePath)
                    if let thumbnailRelativePath {
                        fileStorage.delete(relativePath: thumbnailRelativePath)
                    }
                    return .failed("SQLite write failed: \(error)")
                }
            } catch {
                return .failed("Image storage failed: \(error)")
            }
        }
    }

    func fetchRecent(limit: Int = 200) -> [ClipItem] {
        queue.sync {
            do {
                return try sqlite.fetchRecent(limit: limit)
            } catch {
                Logger.error("Fetch recent clips failed: \(error)")
                return []
            }
        }
    }

    func cleanup(maxItemCount: Int, maxRetentionDays: Int) -> Int {
        queue.sync {
            let safeCount = max(1, maxItemCount)
            let safeDays = max(1, maxRetentionDays)
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -safeDays, to: Date()) ?? Date()

            do {
                let records = try sqlite.cleanup(maxItemCount: safeCount, cutoffDate: cutoffDate)
                for record in records {
                    if let imagePath = record.imagePath {
                        fileStorage.delete(relativePath: imagePath)
                    }
                    if let thumbnailPath = record.thumbnailPath {
                        fileStorage.delete(relativePath: thumbnailPath)
                    }
                }
                return records.count
            } catch {
                Logger.error("Cleanup failed: \(error)")
                return 0
            }
        }
    }
}
