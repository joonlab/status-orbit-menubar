import Foundation
import SQLite3
import os

/// 외부 의존성 없이 시스템 SQLite3 C API 를 직접 호출.
/// DB: ~/Library/Application Support/StatusOrbit/incidents.sqlite
final class IncidentDatabase: @unchecked Sendable {

    static let shared = IncidentDatabase()

    private let logger = Logger(subsystem: "com.joon.statusorbit", category: "DB")
    private let queue = DispatchQueue(label: "com.joon.statusorbit.db")
    private var db: OpaquePointer?

    // MARK: - Lifecycle

    private init() {
        do {
            let url = try Self.databaseURL()
            try openAndMigrate(at: url)
            logger.info("DB opened at \(url.path, privacy: .public)")
        } catch {
            logger.error("DB init failed: \(String(describing: error))")
        }
    }

    deinit { if db != nil { sqlite3_close(db) } }

    static func databaseURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
        let dir = appSupport.appendingPathComponent("StatusOrbit", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("incidents.sqlite")
    }

    private func openAndMigrate(at url: URL) throws {
        var handle: OpaquePointer?
        let rc = sqlite3_open(url.path, &handle)
        guard rc == SQLITE_OK else {
            throw NSError(domain: "Orbit.SQLite", code: Int(rc),
                          userInfo: [NSLocalizedDescriptionKey: "open failed (\(rc))"])
        }
        self.db = handle

        let schema = """
        CREATE TABLE IF NOT EXISTS incidents (
            id           TEXT PRIMARY KEY,
            service_id   TEXT NOT NULL,
            level        TEXT NOT NULL,
            message      TEXT,
            started_at   INTEGER NOT NULL,
            ended_at     INTEGER,
            category     TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_incidents_service ON incidents(service_id);
        CREATE INDEX IF NOT EXISTS idx_incidents_started ON incidents(started_at);
        """
        try exec(schema)
    }

    // MARK: - Public API

    /// level 이 바뀐 경우에만 호출. 이전 진행중 row 가 있으면 ended_at 을 now 로 채우고,
    /// 새 row 를 insert. operational → operational 같은 동일 level 은 호출하지 말 것.
    func recordLevelChange(
        serviceId: String,
        toLevel: StatusLevel,
        message: String?,
        category: ServiceCategory,
        at: Date = Date()
    ) {
        queue.sync {
            let ts = Int64(at.timeIntervalSince1970)

            // 1) 진행 중 row 종료
            let close = "UPDATE incidents SET ended_at = ? WHERE service_id = ? AND ended_at IS NULL;"
            if let stmt = try? prepare(close) {
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_int64(stmt, 1, ts)
                sqlite3_bind_text(stmt, 2, (serviceId as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }

            // 2) operational 로 회복한 경우엔 새 row 만들지 않음 (장애 종료로 처리).
            guard toLevel != .operational else { return }

            // 3) 새 row insert
            let insert = """
            INSERT INTO incidents (id, service_id, level, message, started_at, ended_at, category)
            VALUES (?, ?, ?, ?, ?, NULL, ?);
            """
            guard let stmt = try? prepare(insert) else { return }
            defer { sqlite3_finalize(stmt) }
            let id = UUID().uuidString
            sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (serviceId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (toLevel.rawValue as NSString).utf8String, -1, nil)
            if let m = message {
                sqlite3_bind_text(stmt, 4, (m as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            sqlite3_bind_int64(stmt, 5, ts)
            sqlite3_bind_text(stmt, 6, (category.rawValue as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
    }

    struct IncidentRow: Sendable, Identifiable {
        let id: String
        let serviceId: String
        let level: StatusLevel
        let message: String?
        let startedAt: Date
        let endedAt: Date?
        let category: ServiceCategory
    }

    func fetch(serviceId: String? = nil, since: Date, until: Date = Date()) -> [IncidentRow] {
        queue.sync {
            var rows: [IncidentRow] = []
            let sinceTs = Int64(since.timeIntervalSince1970)
            let untilTs = Int64(until.timeIntervalSince1970)

            let sql: String
            if serviceId != nil {
                sql = """
                SELECT id, service_id, level, message, started_at, ended_at, category
                FROM incidents
                WHERE service_id = ? AND started_at >= ? AND started_at <= ?
                ORDER BY started_at DESC;
                """
            } else {
                sql = """
                SELECT id, service_id, level, message, started_at, ended_at, category
                FROM incidents
                WHERE started_at >= ? AND started_at <= ?
                ORDER BY started_at DESC;
                """
            }

            guard let stmt = try? prepare(sql) else { return [] }
            defer { sqlite3_finalize(stmt) }

            var col: Int32 = 1
            if let s = serviceId {
                sqlite3_bind_text(stmt, col, (s as NSString).utf8String, -1, nil); col += 1
            }
            sqlite3_bind_int64(stmt, col, sinceTs); col += 1
            sqlite3_bind_int64(stmt, col, untilTs)

            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let svc = String(cString: sqlite3_column_text(stmt, 1))
                let lvlStr = String(cString: sqlite3_column_text(stmt, 2))
                let msg: String? = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil
                    : String(cString: sqlite3_column_text(stmt, 3))
                let startedTs = sqlite3_column_int64(stmt, 4)
                let endedTs: Int64? = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil
                    : sqlite3_column_int64(stmt, 5)
                let catStr = String(cString: sqlite3_column_text(stmt, 6))

                rows.append(IncidentRow(
                    id: id,
                    serviceId: svc,
                    level: StatusLevel(rawValue: lvlStr) ?? .unknown,
                    message: msg,
                    startedAt: Date(timeIntervalSince1970: TimeInterval(startedTs)),
                    endedAt: endedTs.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                    category: ServiceCategory(rawValue: catStr) ?? .ai
                ))
            }
            return rows
        }
    }

    /// 지정 기간의 다운타임 분 (operational 외 시간 합계)
    func downtimeMinutes(serviceId: String, since: Date, until: Date = Date()) -> Int {
        let rows = fetch(serviceId: serviceId, since: since, until: until)
        var seconds: TimeInterval = 0
        for r in rows {
            let s = r.startedAt
            let e = r.endedAt ?? min(until, Date())
            seconds += max(0, e.timeIntervalSince(s))
        }
        return Int(seconds / 60)
    }

    /// 지난 N 시간을 시간 단위 bucket 으로 분할. 각 칸은 그 시간 동안의 worst level.
    /// Sparkline 렌더링용. now 기준 가장 오래된 칸이 [0], 가장 최근 칸이 [hours-1].
    func bucketsByHour(serviceId: String, hours: Int, now: Date = Date()) -> [StatusLevel] {
        let since = now.addingTimeInterval(-TimeInterval(hours) * 3600)
        var buckets: [StatusLevel] = Array(repeating: .operational, count: hours)

        let rows = fetch(serviceId: serviceId, since: since, until: now)
        for r in rows {
            let s = max(r.startedAt, since)
            let e = r.endedAt ?? now
            let startHour = Int(s.timeIntervalSince(since) / 3600)
            let endHour   = min(hours - 1, Int(e.timeIntervalSince(since) / 3600))
            guard endHour >= 0 else { continue }
            let from = max(0, startHour)
            for h in from...endHour where h >= 0 && h < hours {
                if r.level.severityRank > buckets[h].severityRank {
                    buckets[h] = r.level
                }
            }
        }
        return buckets
    }

    // MARK: - Helpers

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw NSError(domain: "Orbit.SQLite", code: Int(rc),
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        if rc != SQLITE_OK {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw NSError(domain: "Orbit.SQLite", code: Int(rc),
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return stmt
    }
}
