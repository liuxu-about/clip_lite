import Foundation

enum AppPathError: Error {
    case outsideRoot
    case invalidRelativePath
}

enum AppPaths {
    static func clipLiteRootDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let root = appSupport.appendingPathComponent("ClipLite", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func databaseDirectory() throws -> URL {
        let root = try clipLiteRootDirectory()
        let dbDir = root.appendingPathComponent("Database", isDirectory: true)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        return dbDir
    }

    static func databaseFileURL() throws -> URL {
        let dbDir = try databaseDirectory()
        return dbDir.appendingPathComponent("clips.sqlite", isDirectory: false)
    }

    static func imagesRootDirectory() throws -> URL {
        let root = try clipLiteRootDirectory()
        let images = root.appendingPathComponent("Images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        return images
    }

    static func originalImagesDirectory() throws -> URL {
        let images = try imagesRootDirectory()
        let originals = images.appendingPathComponent("originals", isDirectory: true)
        try FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
        return originals
    }

    static func thumbnailImagesDirectory() throws -> URL {
        let images = try imagesRootDirectory()
        let thumbs = images.appendingPathComponent("thumbnails", isDirectory: true)
        try FileManager.default.createDirectory(at: thumbs, withIntermediateDirectories: true)
        return thumbs
    }

    static func makeRelativePath(from absoluteURL: URL) throws -> String {
        let root = try normalizedRootDirectory()
        let absolute = try validatedPathUnderRoot(absoluteURL, root: root)
        let rootPath = root.path
        return String(absolute.path.dropFirst(rootPath.count + 1))
    }

    static func resolveRelativePath(_ relativePath: String) throws -> URL {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppPathError.invalidRelativePath
        }

        let root = try normalizedRootDirectory()
        let candidate = root.appendingPathComponent(trimmed, isDirectory: false)
        return try validatedPathUnderRoot(candidate, root: root)
    }

    private static func normalizedRootDirectory() throws -> URL {
        try clipLiteRootDirectory().standardizedFileURL.resolvingSymlinksInPath()
    }

    private static func validatedPathUnderRoot(_ url: URL, root: URL) throws -> URL {
        let normalized = url.standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = root.path
        let path = normalized.path

        guard path.hasPrefix(rootPath + "/") else {
            throw AppPathError.outsideRoot
        }

        return normalized
    }
}
