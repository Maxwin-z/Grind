//
//  TimeBlockRepository.swift
//  Grind
//
//  Repository for time block data access
//  Handles 5-minute aggregated data
//

import Foundation
import GRDB

/// Repository for managing 5-minute time blocks
class TimeBlockRepository {
    private let dbManager = DatabaseManager.shared

    // MARK: - Create/Update

    /// Save or update a time block
    func save(_ block: TimeBlock) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            try block.save(db)  // Uses REPLACE conflict policy
        }
    }

    /// Increment a time block's duration and keystroke count
    /// Creates block if it doesn't exist
    func increment(blockStart: Date, appName: String, category: String, duration: Int, keystrokes: Int, isTyping: Bool, projectName: String? = nil) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            // Try to fetch existing block
            if var existing = try TimeBlock
                .filter(TimeBlock.Columns.blockStart == blockStart && TimeBlock.Columns.appName == appName)
                .fetchOne(db) {
                // Update existing
                existing.activeDuration += duration
                if isTyping {
                    existing.typingDuration += duration
                }
                existing.keystrokeCount += keystrokes
                try existing.update(db)
            } else {
                // Create new
                let newBlock = TimeBlock(
                    blockStart: blockStart,
                    appName: appName,
                    category: category,
                    activeDuration: duration,
                    typingDuration: isTyping ? duration : 0,
                    keystrokeCount: keystrokes,
                    projectName: projectName
                )
                try newBlock.insert(db)
            }
        }
    }

    // MARK: - Read

    /// Get time blocks for a date range
    func getBlocks(from startDate: Date, to endDate: Date) throws -> [TimeBlock] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        return try db.read { db in
            try TimeBlock
                .filter(TimeBlock.Columns.blockStart >= startDate && TimeBlock.Columns.blockStart <= endDate)
                .order(TimeBlock.Columns.blockStart.asc)
                .fetchAll(db)
        }
    }

    /// Get time blocks for today
    func getTodayBlocks() throws -> [TimeBlock] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try getBlocks(from: startOfDay, to: endOfDay)
    }

    /// Get time blocks for a specific app
    func getBlocks(forApp appName: String, from startDate: Date, to endDate: Date) throws -> [TimeBlock] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        return try db.read { db in
            try TimeBlock
                .filter(
                    TimeBlock.Columns.appName == appName &&
                    TimeBlock.Columns.blockStart >= startDate &&
                    TimeBlock.Columns.blockStart <= endDate
                )
                .order(TimeBlock.Columns.blockStart.asc)
                .fetchAll(db)
        }
    }

    /// Get time blocks grouped by category
    func getBlocksByCategory(from startDate: Date, to endDate: Date) throws -> [String: [TimeBlock]] {
        let blocks = try getBlocks(from: startDate, to: endDate)
        return Dictionary(grouping: blocks) { $0.category }
    }

    // MARK: - Aggregations

    /// Get total duration per app for a date range
    func getTotalDurationPerApp(from startDate: Date, to endDate: Date) throws -> [(appName: String, duration: Int)] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        struct AppDuration: Decodable, FetchableRecord {
            let appName: String
            let totalDuration: Int
        }

        return try db.read { db in
            let request = TimeBlock
                .select(
                    TimeBlock.Columns.appName,
                    sum(TimeBlock.Columns.activeDuration).forKey("totalDuration")
                )
                .filter(TimeBlock.Columns.blockStart >= startDate && TimeBlock.Columns.blockStart <= endDate)
                .group(TimeBlock.Columns.appName)
                .order(sum(TimeBlock.Columns.activeDuration).desc)
                .asRequest(of: AppDuration.self)

            let results = try request.fetchAll(db)
            return results.map { ($0.appName, $0.totalDuration) }
        }
    }

    /// Get total duration per category
    func getTotalDurationPerCategory(from startDate: Date, to endDate: Date) throws -> [(category: String, duration: Int)] {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        struct CategoryDuration: Decodable, FetchableRecord {
            let category: String
            let totalDuration: Int
        }

        return try db.read { db in
            let request = TimeBlock
                .select(
                    TimeBlock.Columns.category,
                    sum(TimeBlock.Columns.activeDuration).forKey("totalDuration")
                )
                .filter(TimeBlock.Columns.blockStart >= startDate && TimeBlock.Columns.blockStart <= endDate)
                .group(TimeBlock.Columns.category)
                .order(sum(TimeBlock.Columns.activeDuration).desc)
                .asRequest(of: CategoryDuration.self)

            let results = try request.fetchAll(db)
            return results.map { ($0.category, $0.totalDuration) }
        }
    }

    // MARK: - Delete

    /// Delete time blocks older than a certain date
    func deleteBlocks(olderThan date: Date) throws {
        guard let db = dbManager.getDatabase() else {
            throw DatabaseError.notInitialized
        }

        try db.write { db in
            try TimeBlock
                .filter(TimeBlock.Columns.blockStart < date)
                .deleteAll(db)
        }
    }
}
