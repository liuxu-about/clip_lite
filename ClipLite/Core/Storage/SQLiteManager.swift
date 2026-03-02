import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct CleanupRecord {
    let id: String
    let imagePath: String?
    let thumbnailPath: String?
}

enum SQLiteError: Error {
    case openDatabase(String)
    case prepareStatement(String)
    case execute(String)
}

final class SQLiteManager {
    private var db: OpaquePointer?

    init(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            db = nil
            throw SQLiteError.openDatabase(message)
        }
    }

    deinit {
        sqlite3_close(db)
    }

    func initializeSchema() throws {
        let createSQL = """
        CREATE TABLE IF NOT EXISTS clip_history (
            id TEXT PRIMARY KEY,
            type INTEGER NOT NULL,
            content TEXT,
            text_preview TEXT,
            image_path TEXT,
            thumbnail_path TEXT,
            file_size INTEGER,
            image_width INTEGER,
            image_height INTEGER,
            created_at REAL NOT NULL,
            hash_value TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_clip_history_created_at
        ON clip_history(created_at DESC);

        CREATE INDEX IF NOT EXISTS idx_clip_history_hash
        ON clip_history(hash_value);
        """
        try execute(createSQL)

        try migrateMissingColumnsIfNeeded()
    }

    func fetchLatestHash() throws -> String? {
        let sql = "SELECT hash_value FROM clip_history ORDER BY created_at DESC LIMIT 1;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareStatement(lastErrorMessage())
        }

        if sqlite3_step(statement) == SQLITE_ROW,
           let cString = sqlite3_column_text(statement, 0) {
            return String(cString: cString)
        }

        return nil
    }

    func insertClip(_ item: ClipItem) throws {
        let sql = """
        INSERT INTO clip_history (
            id,
            type,
            content,
            text_preview,
            image_path,
            thumbnail_path,
            file_size,
            image_width,
            image_height,
            created_at,
            hash_value
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareStatement(lastErrorMessage())
        }

        bindText(statement, index: 1, value: item.id.uuidString)
        sqlite3_bind_int(statement, 2, Int32(item.type.rawValue))
        bindText(statement, index: 3, value: item.textContent)
        bindText(statement, index: 4, value: item.textPreview)
        bindText(statement, index: 5, value: item.imagePath)
        bindText(statement, index: 6, value: item.thumbnailPath)

        if let fileSize = item.fileSize {
            sqlite3_bind_int64(statement, 7, fileSize)
        } else {
            sqlite3_bind_null(statement, 7)
        }

        if let imageWidth = item.imageWidth {
            sqlite3_bind_int(statement, 8, Int32(imageWidth))
        } else {
            sqlite3_bind_null(statement, 8)
        }

        if let imageHeight = item.imageHeight {
            sqlite3_bind_int(statement, 9, Int32(imageHeight))
        } else {
            sqlite3_bind_null(statement, 9)
        }

        sqlite3_bind_double(statement, 10, item.createdAt.timeIntervalSince1970)
        bindText(statement, index: 11, value: item.hashValue)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.execute(lastErrorMessage())
        }
    }

    func fetchRecent(limit: Int) throws -> [ClipItem] {
        let sql = """
        SELECT
            id,
            type,
            content,
            text_preview,
            image_path,
            thumbnail_path,
            file_size,
            image_width,
            image_height,
            created_at,
            hash_value
        FROM clip_history
        ORDER BY created_at DESC
        LIMIT ?;
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareStatement(lastErrorMessage())
        }

        sqlite3_bind_int(statement, 1, Int32(limit))

        var items: [ClipItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idString = stringValue(statement, index: 0),
                let type = ClipType(rawValue: Int(sqlite3_column_int(statement, 1))),
                let createdAt = dateValue(statement, index: 9),
                let hashValue = stringValue(statement, index: 10)
            else {
                continue
            }

            let item = ClipItem(
                id: UUID(uuidString: idString) ?? UUID(),
                type: type,
                createdAt: createdAt,
                hashValue: hashValue,
                textContent: stringValue(statement, index: 2),
                textPreview: stringValue(statement, index: 3) ?? "",
                imagePath: stringValue(statement, index: 4),
                thumbnailPath: stringValue(statement, index: 5),
                fileSize: int64Value(statement, index: 6),
                imageWidth: intValue(statement, index: 7),
                imageHeight: intValue(statement, index: 8)
            )
            items.append(item)
        }

        return items
    }

    func cleanup(maxItemCount: Int, cutoffDate: Date) throws -> [CleanupRecord] {
        var recordsByID: [String: CleanupRecord] = [:]

        let older = try fetchCleanupRecords(sql: """
            SELECT id, image_path, thumbnail_path
            FROM clip_history
            WHERE created_at < ?;
            """, bind: { statement in
            sqlite3_bind_double(statement, 1, cutoffDate.timeIntervalSince1970)
        })

        for record in older {
            recordsByID[record.id] = record
        }

        let overflow = try fetchCleanupRecords(sql: """
            SELECT id, image_path, thumbnail_path
            FROM clip_history
            ORDER BY created_at DESC
            LIMIT -1 OFFSET ?;
            """, bind: { statement in
            sqlite3_bind_int(statement, 1, Int32(maxItemCount))
        })

        for record in overflow {
            recordsByID[record.id] = record
        }

        let targets = Array(recordsByID.values)
        guard !targets.isEmpty else {
            return []
        }

        let placeholders = Array(repeating: "?", count: targets.count).joined(separator: ",")
        let deleteSQL = "DELETE FROM clip_history WHERE id IN (\(placeholders));"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareStatement(lastErrorMessage())
        }

        for (idx, record) in targets.enumerated() {
            bindText(statement, index: Int32(idx + 1), value: record.id)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.execute(lastErrorMessage())
        }

        return targets
    }

    private func fetchCleanupRecords(sql: String, bind: (OpaquePointer?) -> Void) throws -> [CleanupRecord] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareStatement(lastErrorMessage())
        }

        bind(statement)

        var results: [CleanupRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = stringValue(statement, index: 0) else {
                continue
            }

            results.append(
                CleanupRecord(
                    id: id,
                    imagePath: stringValue(statement, index: 1),
                    thumbnailPath: stringValue(statement, index: 2)
                )
            )
        }

        return results
    }

    private func migrateMissingColumnsIfNeeded() throws {
        let existing = try currentColumns(table: "clip_history")

        if !existing.contains("image_path") {
            try execute("ALTER TABLE clip_history ADD COLUMN image_path TEXT;")
        }
        if !existing.contains("thumbnail_path") {
            try execute("ALTER TABLE clip_history ADD COLUMN thumbnail_path TEXT;")
        }
        if !existing.contains("file_size") {
            try execute("ALTER TABLE clip_history ADD COLUMN file_size INTEGER;")
        }
        if !existing.contains("image_width") {
            try execute("ALTER TABLE clip_history ADD COLUMN image_width INTEGER;")
        }
        if !existing.contains("image_height") {
            try execute("ALTER TABLE clip_history ADD COLUMN image_height INTEGER;")
        }
    }

    private func currentColumns(table: String) throws -> Set<String> {
        let sql = "PRAGMA table_info(\(table));"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareStatement(lastErrorMessage())
        }

        var names: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 1) {
                names.insert(String(cString: cString))
            }
        }

        return names
    }

    private func bindText(_ statement: OpaquePointer?, index: Int32, value: String?) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }

        _ = value.withCString { cString in
            sqlite3_bind_text(statement, index, cString, -1, sqliteTransient)
        }
    }

    private func stringValue(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let cString = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: cString)
    }

    private func intValue(_ statement: OpaquePointer?, index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return Int(sqlite3_column_int(statement, index))
    }

    private func int64Value(_ statement: OpaquePointer?, index: Int32) -> Int64? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return sqlite3_column_int64(statement, index)
    }

    private func dateValue(_ statement: OpaquePointer?, index: Int32) -> Date? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }

    private func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(errorMessage)
            throw SQLiteError.execute(message)
        }
    }

    private func lastErrorMessage() -> String {
        String(cString: sqlite3_errmsg(db))
    }
}
