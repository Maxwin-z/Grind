//
//  HeartbeatRepository.swift
//  Grind
//
//  Repository for heartbeat data access
//  Encapsulates all heartbeat database operations
//

import Foundation
import GRDB

/// Repository for managing heartbeat records
class HeartbeatRepository {
    private let dbManager = DatabaseManager.shared

    // MARK: - Create

    /// Save a new heartbeat
    func save(_ heartbeat: Heartbeat) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            try heartbeat.insert(db)
        }
    }

    /// Save multiple heartbeats in a batch
    func saveBatch(_ heartbeats: [Heartbeat]) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            for heartbeat in heartbeats {
                try heartbeat.insert(db)
            }
        }
    }

    // MARK: - Read

    /// Get heartbeats for a specific date range
    func getHeartbeats(from startDate: Date, to endDate: Date) throws -> [Heartbeat] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        return try db.read { db in
            try Heartbeat
                .filter(Heartbeat.Columns.timestamp >= startDate && Heartbeat.Columns.timestamp <= endDate)
                .order(Heartbeat.Columns.timestamp.desc)
                .fetchAll(db)
        }
    }

    /// Get heartbeats for today
    func getTodayHeartbeats() throws -> [Heartbeat] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try getHeartbeats(from: startOfDay, to: endOfDay)
    }

    /// Get heartbeats for a specific app
    func getHeartbeats(forApp appName: String, from startDate: Date, to endDate: Date) throws -> [Heartbeat] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        return try db.read { db in
            try Heartbeat
                .filter(
                    Heartbeat.Columns.appName == appName &&
                    Heartbeat.Columns.timestamp >= startDate &&
                    Heartbeat.Columns.timestamp <= endDate
                )
                .order(Heartbeat.Columns.timestamp.desc)
                .fetchAll(db)
        }
    }

    /// Get the last recorded heartbeat
    func getLastHeartbeat() throws -> Heartbeat? {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        return try db.read { db in
            try Heartbeat
                .order(Heartbeat.Columns.timestamp.desc)
                .limit(1)
                .fetchOne(db)
        }
    }

    // MARK: - Aggregations

    /// Get total active time for today
    func getTodayActiveTime() throws -> TimeInterval {
        let heartbeats = try getTodayHeartbeats()

        // Apply heartbeat algorithm (max 120s gap)
        var totalTime: TimeInterval = 0
        var lastTimestamp: Date?

        for heartbeat in heartbeats.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let last = lastTimestamp {
                let gap = heartbeat.timestamp.timeIntervalSince(last)
                // Only count if gap is within 120 seconds (per PRD FR-003)
                if gap <= 120 {
                    totalTime += min(gap, 120)
                }
            }
            lastTimestamp = heartbeat.timestamp
        }

        return totalTime
    }

    /// Get keystroke count for today
    func getTodayKeystrokeCount() throws -> Int {
        let heartbeats = try getTodayHeartbeats()
        return heartbeats.reduce(0) { $0 + $1.keystrokeCount }
    }

    /// Get activity statistics for a specific app
    func getActivityStats(forBundleId bundleId: String, from startDate: Date, to endDate: Date) throws -> AppActivityStats? {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        let heartbeats = try db.read { db in
            try Heartbeat
                .filter(
                    Heartbeat.Columns.bundleId == bundleId &&
                    Heartbeat.Columns.timestamp >= startDate &&
                    Heartbeat.Columns.timestamp <= endDate
                )
                .order(Heartbeat.Columns.timestamp.asc)
                .fetchAll(db)
        }

        guard !heartbeats.isEmpty else { return nil }

        // Calculate total active time using heartbeat algorithm
        var totalTime: TimeInterval = 0
        var lastTimestamp: Date?
        var sessionCount = 0

        for heartbeat in heartbeats {
            if let last = lastTimestamp {
                let gap = heartbeat.timestamp.timeIntervalSince(last)
                if gap <= 120 {
                    // Add the gap time (up to 120s for continuous sessions)
                    // Each heartbeat is ~2 seconds apart during active use
                    totalTime += min(gap, 120)
                } else {
                    // New session started after gap > 120s
                    sessionCount += 1
                }
            } else {
                sessionCount = 1
            }
            lastTimestamp = heartbeat.timestamp
        }

        // Add final heartbeat duration (assume 2 seconds for the last beat)
        if !heartbeats.isEmpty {
            totalTime += 2.0
        }

        // Aggregate counts
        let totalKeystrokes = heartbeats.reduce(0) { $0 + $1.keystrokeCount }
        let totalMouseMovements = heartbeats.reduce(0) { $0 + $1.mouseMovementCount }
        let totalMouseClicks = heartbeats.reduce(0) { $0 + $1.mouseClickCount }

        let firstHeartbeat = heartbeats.first!
        let lastHeartbeat = heartbeats.last!

        return AppActivityStats(
            id: bundleId,
            appName: firstHeartbeat.appName,
            bundleId: bundleId,
            totalActiveTime: totalTime,
            totalKeystrokes: totalKeystrokes,
            totalMouseMovements: totalMouseMovements,
            totalMouseClicks: totalMouseClicks,
            sessionCount: sessionCount,
            lastActiveTime: lastHeartbeat.timestamp,
            category: firstHeartbeat.category
        )
    }

    /// Get activity statistics for all apps today
    func getAllAppActivityStats() throws -> [AppActivityStats] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let heartbeats = try getHeartbeats(from: startOfDay, to: endOfDay)

        // Group heartbeats by bundle ID
        let groupedHeartbeats = Dictionary(grouping: heartbeats) { $0.bundleId }

        var stats: [AppActivityStats] = []

        for (bundleId, _) in groupedHeartbeats {
            if let appStats = try getActivityStats(forBundleId: bundleId, from: startOfDay, to: endOfDay) {
                stats.append(appStats)
            }
        }

        // Sort by total active time (descending)
        return stats.sorted { $0.totalActiveTime > $1.totalActiveTime }
    }

    // MARK: - Delete

    /// Delete heartbeats older than a certain date
    func deleteHeartbeats(olderThan date: Date) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            try Heartbeat
                .filter(Heartbeat.Columns.timestamp < date)
                .deleteAll(db)
        }
    }

    /// Delete all heartbeats (use with caution)
    func deleteAll() throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            try Heartbeat.deleteAll(db)
        }
    }
}

// MARK: - Database Errors

enum DatabaseError: Error, LocalizedError {
    case notInitialized
    case saveFailed
    case queryFailed

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database not initialized"
        case .saveFailed:
            return "Failed to save to database"
        case .queryFailed:
            return "Database query failed"
        }
    }
}
