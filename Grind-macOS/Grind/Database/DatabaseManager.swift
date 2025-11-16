//
//  DatabaseManager.swift
//  Grind
//
//  Central database management using GRDB
//  Handles database setup, migrations, and access
//

import Foundation
import GRDB

/// Singleton database manager for the application
/// Provides thread-safe database access and migration handling
class DatabaseManager {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?

    /// Database file location
    private var databaseURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let appDirectory = appSupport.appendingPathComponent("Grind", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: appDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return appDirectory.appendingPathComponent("grind.db")
    }

    private init() {
        setupDatabase()
    }

    /// Initialize database connection and run migrations
    private func setupDatabase() {
        do {
            // Create database queue
            dbQueue = try DatabaseQueue(path: databaseURL.path)

            // Run migrations
            try runMigrations()

            print("✅ Database initialized at: \(databaseURL.path)")
        } catch {
            print("❌ Database setup failed: \(error)")
        }
    }

    /// Get database queue for queries
    func getDatabase() -> DatabaseQueue? {
        return dbQueue
    }

    // MARK: - Migrations

    /// Run all database migrations
    private func runMigrations() throws {
        var migrator = DatabaseMigrator()

        // Migration v1: Create core tables
        migrator.registerMigration("v1_initial_schema") { db in
            try self.createHeartbeatsTable(db)
            try self.createTimeBlocksTable(db)
            try self.createDailyStatsTable(db)
            try self.createAppCategoriesTable(db)
        }

        // Migration v2: Add indexes for performance
        migrator.registerMigration("v2_add_indexes") { db in
            try self.createIndexes(db)
        }

        // Migration v3: Add mouse tracking columns
        migrator.registerMigration("v3_add_mouse_tracking") { db in
            try db.alter(table: "heartbeats") { t in
                t.add(column: "mouseMovementCount", .integer).notNull().defaults(to: 0)
                t.add(column: "mouseClickCount", .integer).notNull().defaults(to: 0)
            }
            print("✅ Added mouse tracking columns to heartbeats table")
        }

        // Run migrations
        try migrator.migrate(dbQueue!)
    }

    // MARK: - Table Creation (from PRD FR-008)

    private func createHeartbeatsTable(_ db: Database) throws {
        try db.create(table: "heartbeats") { t in
            t.column("id", .text).primaryKey()
            t.column("timestamp", .datetime).notNull()
            t.column("appName", .text).notNull()
            t.column("bundleId", .text).notNull()
            t.column("windowTitle", .text)
            t.column("projectName", .text)
            t.column("filePath", .text)
            t.column("language", .text)
            t.column("category", .text).notNull()
            t.column("isTyping", .boolean).notNull()
            t.column("idleSeconds", .double).notNull()
            t.column("keystrokeCount", .integer).notNull().defaults(to: 0)
        }
        print("✅ Created table: heartbeats")
    }

    private func createTimeBlocksTable(_ db: Database) throws {
        try db.create(table: "blocks_5min") { t in
            t.column("blockStart", .datetime).notNull()
            t.column("appName", .text).notNull()
            t.column("category", .text).notNull()
            t.column("activeDuration", .integer).notNull()
            t.column("typingDuration", .integer).notNull()
            t.column("keystrokeCount", .integer).notNull()
            t.column("projectName", .text)

            // Composite primary key
            t.primaryKey(["blockStart", "appName"])
        }
        print("✅ Created table: blocks_5min")
    }

    private func createDailyStatsTable(_ db: Database) throws {
        try db.create(table: "daily_stats") { t in
            t.column("date", .text).notNull()
            t.column("appName", .text).notNull()
            t.column("category", .text).notNull()
            t.column("totalDuration", .integer).notNull()
            t.column("typingDuration", .integer).notNull()
            t.column("keystrokeCount", .integer).notNull()
            t.column("sessionsCount", .integer).notNull()
            t.column("firstActive", .datetime)
            t.column("lastActive", .datetime)

            // Composite primary key
            t.primaryKey(["date", "appName"])
        }
        print("✅ Created table: daily_stats")
    }

    private func createAppCategoriesTable(_ db: Database) throws {
        try db.create(table: "app_categories") { t in
            t.column("bundleId", .text).primaryKey()
            t.column("appName", .text).notNull()
            t.column("category", .text).notNull()
            t.column("isCodeEditor", .boolean).notNull().defaults(to: false)
            t.column("isTerminal", .boolean).notNull().defaults(to: false)
            t.column("userOverride", .boolean).notNull().defaults(to: false)
        }

        // Seed with default categories
        try seedDefaultCategories(db)

        print("✅ Created table: app_categories")
    }

    /// Seed database with default app categories
    private func seedDefaultCategories(_ db: Database) throws {
        for (bundleId, mapping) in AppCategory.defaultMappings {
            let category = AppCategory(
                bundleId: bundleId,
                appName: mapping.name,
                category: mapping.category,
                isCodeEditor: mapping.isCodeEditor,
                isTerminal: mapping.isTerminal,
                userOverride: false
            )
            try category.insert(db)
        }
        print("✅ Seeded \(AppCategory.defaultMappings.count) default app categories")
    }

    // MARK: - Indexes

    private func createIndexes(_ db: Database) throws {
        // Heartbeats indexes for common queries
        try db.create(index: "idx_heartbeats_timestamp", on: "heartbeats", columns: ["timestamp"])
        try db.create(index: "idx_heartbeats_app", on: "heartbeats", columns: ["appName"])
        try db.create(index: "idx_heartbeats_category", on: "heartbeats", columns: ["category"])
        try db.create(index: "idx_heartbeats_timestamp_app", on: "heartbeats", columns: ["timestamp", "appName"])

        // Time blocks indexes
        try db.create(index: "idx_blocks_start", on: "blocks_5min", columns: ["blockStart"])
        try db.create(index: "idx_blocks_category", on: "blocks_5min", columns: ["category"])

        // Daily stats indexes
        try db.create(index: "idx_daily_date", on: "daily_stats", columns: ["date"])
        try db.create(index: "idx_daily_category", on: "daily_stats", columns: ["category"])

        print("✅ Created database indexes")
    }

    // MARK: - Cleanup

    /// Delete heartbeats older than retention period (90 days per PRD)
    func cleanupOldHeartbeats() throws {
        guard let db = dbQueue else { return }

        let retentionDays = 90
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!

        try db.write { db in
            try Heartbeat
                .filter(Heartbeat.Columns.timestamp < cutoffDate)
                .deleteAll(db)
        }
    }

    /// Get database file size
    func getDatabaseSize() -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: databaseURL.path) else {
            return 0
        }
        return attributes[.size] as? Int64 ?? 0
    }

    /// Formatted database size string
    func getDatabaseSizeFormatted() -> String {
        let bytes = getDatabaseSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
