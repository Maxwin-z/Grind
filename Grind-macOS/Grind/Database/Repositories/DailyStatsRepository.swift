//
//  DailyStatsRepository.swift
//  Grind
//
//  Repository for daily statistics data access
//  Handles aggregated daily data for efficient dashboard queries
//

import Foundation
import GRDB

/// Repository for managing daily statistics records
class DailyStatsRepository {
    static let shared = DailyStatsRepository()
    private let dbManager = DatabaseManager.shared

    private init() {}

    // MARK: - Create/Update

    /// Save or update a daily stats record
    func save(_ stats: DailyStats) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            try stats.save(db)  // Uses REPLACE conflict policy for composite key
        }
    }

    /// Save multiple daily stats in a batch
    func saveBatch(_ statsList: [DailyStats]) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            for stats in statsList {
                try stats.save(db)
            }
        }
    }

    /// Update or insert daily stats for a specific app on a specific date
    func upsert(date: String, appName: String, category: String, updates: (inout DailyStats) -> Void) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            if var existing = try DailyStats
                .filter(DailyStats.Columns.date == date && DailyStats.Columns.appName == appName)
                .fetchOne(db) {
                // Update existing record
                updates(&existing)
                try existing.update(db)
            } else {
                // Create new record
                var newStats = DailyStats(date: date, appName: appName, category: category)
                updates(&newStats)
                try newStats.insert(db)
            }
        }
    }

    // MARK: - Read

    /// Get daily stats for a specific date
    func getStats(forDate date: String) throws -> [DailyStats] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        return try db.read { db in
            try DailyStats
                .filter(DailyStats.Columns.date == date)
                .order(DailyStats.Columns.totalDuration.desc)
                .fetchAll(db)
        }
    }

    /// Get daily stats for a date range
    func getStats(from startDate: String, to endDate: String) throws -> [DailyStats] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        return try db.read { db in
            try DailyStats
                .filter(DailyStats.Columns.date >= startDate && DailyStats.Columns.date <= endDate)
                .order(DailyStats.Columns.date.asc, DailyStats.Columns.totalDuration.desc)
                .fetchAll(db)
        }
    }

    /// Get daily stats for a specific app in date range
    func getStats(forApp appName: String, from startDate: String, to endDate: String) throws -> [DailyStats] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        return try db.read { db in
            try DailyStats
                .filter(
                    DailyStats.Columns.appName == appName &&
                    DailyStats.Columns.date >= startDate &&
                    DailyStats.Columns.date <= endDate
                )
                .order(DailyStats.Columns.date.asc)
                .fetchAll(db)
        }
    }

    /// Get today's daily stats
    func getTodayStats() throws -> [DailyStats] {
        let today = DailyStats.dateString(from: Date())
        return try getStats(forDate: today)
    }

    // MARK: - Aggregations for iOS Dashboard

    /// Get last N days of activity grouped by (date, app)
    /// Returns array sorted by date ASC, duration DESC within each date
    func getLastNDaysStats(days: Int) throws -> [DailyStats] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: endDate))!

        let startDateStr = DailyStats.dateString(from: startDate)
        let endDateStr = DailyStats.dateString(from: endDate)

        return try getStats(from: startDateStr, to: endDateStr)
    }

    /// Get last 7 days activity grouped by (date, app) for iOS dashboard
    func getLast7DaysStats() throws -> [DailyStats] {
        return try getLastNDaysStats(days: 7)
    }

    /// Get last 30 days activity for historical sync
    func getLast30DaysStats() throws -> [DailyStats] {
        return try getLastNDaysStats(days: 30)
    }

    /// Get total duration per day (all apps combined) for a date range
    func getTotalDurationPerDay(from startDate: String, to endDate: String) throws -> [(date: String, totalDuration: Int, totalKeystrokes: Int)] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        struct DayTotal: Decodable, FetchableRecord {
            let date: String
            let totalDuration: Int
            let totalKeystrokes: Int
        }

        return try db.read { db in
            let request = DailyStats
                .select(
                    DailyStats.Columns.date,
                    sum(DailyStats.Columns.totalDuration).forKey("totalDuration"),
                    sum(DailyStats.Columns.keystrokeCount).forKey("totalKeystrokes")
                )
                .filter(DailyStats.Columns.date >= startDate && DailyStats.Columns.date <= endDate)
                .group(DailyStats.Columns.date)
                .order(DailyStats.Columns.date.asc)
                .asRequest(of: DayTotal.self)

            let results = try request.fetchAll(db)
            return results.map { ($0.date, $0.totalDuration, $0.totalKeystrokes) }
        }
    }

    /// Get total duration per app across all dates in range
    func getTotalDurationPerApp(from startDate: String, to endDate: String) throws -> [(appName: String, totalDuration: Int, totalKeystrokes: Int)] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        struct AppTotal: Decodable, FetchableRecord {
            let appName: String
            let totalDuration: Int
            let totalKeystrokes: Int
        }

        return try db.read { db in
            let request = DailyStats
                .select(
                    DailyStats.Columns.appName,
                    sum(DailyStats.Columns.totalDuration).forKey("totalDuration"),
                    sum(DailyStats.Columns.keystrokeCount).forKey("totalKeystrokes")
                )
                .filter(DailyStats.Columns.date >= startDate && DailyStats.Columns.date <= endDate)
                .group(DailyStats.Columns.appName)
                .order(sum(DailyStats.Columns.totalDuration).desc)
                .asRequest(of: AppTotal.self)

            let results = try request.fetchAll(db)
            return results.map { ($0.appName, $0.totalDuration, $0.totalKeystrokes) }
        }
    }

    /// Get total duration per category for a date range
    func getTotalDurationPerCategory(from startDate: String, to endDate: String) throws -> [(category: String, totalDuration: Int, totalKeystrokes: Int)] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        struct CategoryTotal: Decodable, FetchableRecord {
            let category: String
            let totalDuration: Int
            let totalKeystrokes: Int
        }

        return try db.read { db in
            let request = DailyStats
                .select(
                    DailyStats.Columns.category,
                    sum(DailyStats.Columns.totalDuration).forKey("totalDuration"),
                    sum(DailyStats.Columns.keystrokeCount).forKey("totalKeystrokes")
                )
                .filter(DailyStats.Columns.date >= startDate && DailyStats.Columns.date <= endDate)
                .group(DailyStats.Columns.category)
                .order(sum(DailyStats.Columns.totalDuration).desc)
                .asRequest(of: CategoryTotal.self)

            let results = try request.fetchAll(db)
            return results.map { ($0.category, $0.totalDuration, $0.totalKeystrokes) }
        }
    }

    // MARK: - Delete

    /// Delete daily stats for a specific date
    func deleteStats(forDate date: String) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            try DailyStats
                .filter(DailyStats.Columns.date == date)
                .deleteAll(db)
        }
    }

    /// Delete daily stats older than a certain date
    func deleteStats(olderThan date: String) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            try DailyStats
                .filter(DailyStats.Columns.date < date)
                .deleteAll(db)
        }
    }

    /// Delete all daily stats (use with caution)
    func deleteAll() throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            try DailyStats.deleteAll(db)
        }
    }
}
