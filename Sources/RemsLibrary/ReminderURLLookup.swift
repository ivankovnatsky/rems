// FIXME: HACK — This reads Reminders' private SQLite database directly because
// EKCalendarItem.url is broken and always returns nil.
// See: https://developer.apple.com/forums/thread/128140
// TODO: Remove this workaround when Apple fixes the EventKit url property.

import Foundation
import SQLite3

/// SQLITE_TRANSIENT tells SQLite to make its own copy of bound strings,
/// avoiding dangling pointer issues with temporary Swift string buffers.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// SQLite default parameter limit.
private let sqliteMaxVariableNumber = 999

/// Looks up reminder URLs from the Reminders app's private CoreData SQLite
/// database. This is necessary because `EKCalendarItem.url` always returns nil
/// due to a long-standing Apple bug.
public enum ReminderURLLookup {

    private static let lock = NSLock()
    private static var _cachedURLs: [String: URL] = [:]

    /// Cached URL lookup results, keyed by `calendarItemExternalIdentifier`.
    /// Thread-safe: all access is serialized through a lock.
    public static var cachedURLs: [String: URL] {
        get { lock.lock(); defer { lock.unlock() }; return _cachedURLs }
        set { lock.lock(); defer { lock.unlock() }; _cachedURLs = newValue }
    }

    /// Batch-lookup URLs for the given external IDs and populate `cachedURLs`.
    public static func prefetch(externalIDs: [String]) {
        cachedURLs = lookupURLs(for: externalIDs)
    }

    /// Clear cached results.
    public static func clearCache() {
        cachedURLs = [:]
    }

    // MARK: - Private

    /// Known paths where the Reminders SQLite DB might live.
    private static let databaseSearchPaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Group Containers/group.com.apple.reminders/Container_v1/Stores",
            "\(home)/Library/Reminders/Container_v1/Stores",
        ]
    }()

    /// Find all `Data-*.sqlite` files across known paths.
    private static func findDatabaseFiles() -> [String] {
        let fm = FileManager.default
        var results: [String] = []
        for dir in databaseSearchPaths {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for file in contents where file.hasPrefix("Data-") && file.hasSuffix(".sqlite") {
                results.append("\(dir)/\(file)")
            }
        }
        return results
    }

    /// Look up URLs for a set of external IDs by querying the Reminders SQLite DB.
    /// Returns an empty dictionary on any error (DB not found, locked, schema mismatch, etc.).
    private static func lookupURLs(for externalIDs: [String]) -> [String: URL] {
        guard !externalIDs.isEmpty else { return [:] }

        var result: [String: URL] = [:]
        let dbFiles = findDatabaseFiles()
        guard !dbFiles.isEmpty else { return [:] }

        for dbPath in dbFiles {
            // Chunk IDs to stay under SQLite's variable limit (999).
            // One slot is used for Z_ENT, leaving 998 for IDs.
            let chunkSize = sqliteMaxVariableNumber - 1
            for chunk in stride(from: 0, to: externalIDs.count, by: chunkSize) {
                let end = min(chunk + chunkSize, externalIDs.count)
                let slice = Array(externalIDs[chunk..<end])
                guard let urls = queryDatabase(at: dbPath, externalIDs: slice) else { continue }
                result.merge(urls) { existing, _ in existing }
            }
        }

        return result
    }

    /// Query a single SQLite database for URL attachments matching the given external IDs.
    private static func queryDatabase(at path: String, externalIDs: [String]) -> [String: URL]? {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close(db) }

        // Dynamically look up Z_ENT for REMCDURLAttachment
        guard let zEnt = lookupEntityID(db: db, entityName: "REMCDURLAttachment") else { return nil }

        // Build the query. We batch external IDs using IN (...).
        let placeholders = externalIDs.map { _ in "?" }.joined(separator: ", ")
        let sql = """
            SELECT ZR.ZCKIDENTIFIER, ZO.ZURL
            FROM ZREMCDOBJECT ZO
            JOIN ZREMCDREMINDER ZR ON ZO.ZREMINDER = ZR.Z_PK
                OR ZO.ZREMINDER1 = ZR.Z_PK
                OR ZO.ZREMINDER2 = ZR.Z_PK
                OR ZO.ZREMINDER3 = ZR.Z_PK
                OR ZO.ZREMINDER4 = ZR.Z_PK
                OR ZO.ZREMINDER5 = ZR.Z_PK
            WHERE ZO.Z_ENT = ?
            AND ZR.ZCKIDENTIFIER IN (\(placeholders))
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        // Bind Z_ENT as first parameter
        guard sqlite3_bind_int(stmt, 1, zEnt) == SQLITE_OK else { return nil }

        // Bind external IDs using withCString for safe C interop
        for (i, eid) in externalIDs.enumerated() {
            let rc = eid.withCString { cStr in
                sqlite3_bind_text(stmt, Int32(i + 2), cStr, -1, SQLITE_TRANSIENT)
            }
            guard rc == SQLITE_OK else { return nil }
        }

        var result: [String: URL] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let ckIdRaw = sqlite3_column_text(stmt, 0),
                  let urlRaw = sqlite3_column_text(stmt, 1)
            else { continue }

            let ckId = String(cString: ckIdRaw)
            let urlString = String(cString: urlRaw)
            if let url = URL(string: urlString) {
                result[ckId] = url
            }
        }

        return result
    }

    /// Look up Z_ENT value for a given entity name from Z_PRIMARYKEY.
    private static func lookupEntityID(db: OpaquePointer?, entityName: String) -> Int32? {
        let sql = "SELECT Z_ENT FROM Z_PRIMARYKEY WHERE Z_NAME = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        let rc = entityName.withCString { cStr in
            sqlite3_bind_text(stmt, 1, cStr, -1, SQLITE_TRANSIENT)
        }
        guard rc == SQLITE_OK else { return nil }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return sqlite3_column_int(stmt, 0)
    }
}
