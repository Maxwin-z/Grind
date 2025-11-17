//
//  DailyStats.swift
//  Grind
//
//  Daily summary statistics for efficient dashboard queries
//  See PRD FR-008 for schema details
//

import Foundation
import GRDB

/// Daily aggregated statistics per app/category
/// Enables fast dashboard queries without scanning all heartbeats
struct DailyStats: Codable {
    var date: String                // YYYY-MM-DD format
    var appName: String
    var category: String
    var totalDuration: Int          // Total active seconds
    var typingDuration: Int         // Seconds spent typing
    var keystrokeCount: Int         // Total keystrokes
    var mouseMovementCount: Int     // Total mouse movements
    var mouseClickCount: Int        // Total mouse clicks
    var sessionsCount: Int          // Number of separate sessions
    var firstActive: Date?          // First activity timestamp
    var lastActive: Date?           // Last activity timestamp

    init(
        date: String,
        appName: String,
        category: String = "Other",
        totalDuration: Int = 0,
        typingDuration: Int = 0,
        keystrokeCount: Int = 0,
        mouseMovementCount: Int = 0,
        mouseClickCount: Int = 0,
        sessionsCount: Int = 0,
        firstActive: Date? = nil,
        lastActive: Date? = nil
    ) {
        self.date = date
        self.appName = appName
        self.category = category
        self.totalDuration = totalDuration
        self.typingDuration = typingDuration
        self.keystrokeCount = keystrokeCount
        self.mouseMovementCount = mouseMovementCount
        self.mouseClickCount = mouseClickCount
        self.sessionsCount = sessionsCount
        self.firstActive = firstActive
        self.lastActive = lastActive
    }
}

// MARK: - GRDB Support
extension DailyStats: FetchableRecord, PersistableRecord {
    static let databaseTableName = "daily_stats"

    enum Columns {
        static let date = Column("date")
        static let appName = Column("appName")
        static let category = Column("category")
        static let totalDuration = Column("totalDuration")
        static let typingDuration = Column("typingDuration")
        static let keystrokeCount = Column("keystrokeCount")
        static let mouseMovementCount = Column("mouseMovementCount")
        static let mouseClickCount = Column("mouseClickCount")
        static let sessionsCount = Column("sessionsCount")
        static let firstActive = Column("firstActive")
        static let lastActive = Column("lastActive")
    }

    // Composite primary key
    static let persistenceConflictPolicy = PersistenceConflictPolicy(
        insert: .replace,
        update: .replace
    )
}

// MARK: - Helper Functions
extension DailyStats {
    /// Date formatter for daily stats (YYYY-MM-DD)
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Create date string from Date
    static func dateString(from date: Date) -> String {
        return dateFormatter.string(from: date)
    }

    /// Get Date from date string
    var dateValue: Date? {
        return Self.dateFormatter.date(from: date)
    }

    /// Formatted total duration (e.g., "4h 32m")
    var totalDurationFormatted: String {
        return formatDuration(totalDuration)
    }

    /// Formatted typing duration (e.g., "2h 15m")
    var typingDurationFormatted: String {
        return formatDuration(typingDuration)
    }

    /// Average keystrokes per minute during typing
    var averageKeystrokesPerMinute: Double {
        guard typingDuration > 0 else { return 0 }
        let typingMinutes = Double(typingDuration) / 60.0
        return Double(keystrokeCount) / typingMinutes
    }

    /// Percentage of time spent typing vs. total active time
    var typingPercentage: Double {
        guard totalDuration > 0 else { return 0 }
        return (Double(typingDuration) / Double(totalDuration)) * 100
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
