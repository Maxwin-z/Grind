//
//  TimeBlock.swift
//  Grind
//
//  5-minute aggregated time blocks for visualization
//  See PRD FR-009 for aggregation logic
//

import Foundation
import GRDB

/// A 5-minute time block - the smallest unit for timeline visualization
/// Aggregated from heartbeats for efficient querying
struct TimeBlock: Codable {
    var blockStart: Date
    var appName: String
    var category: String
    var activeDuration: Int         // seconds of active time
    var typingDuration: Int         // seconds of typing time
    var keystrokeCount: Int
    var mouseMovementCount: Int     // mouse movements in this block
    var mouseClickCount: Int        // mouse clicks in this block
    var projectName: String?

    init(
        blockStart: Date,
        appName: String,
        category: String = "Other",
        activeDuration: Int = 0,
        typingDuration: Int = 0,
        keystrokeCount: Int = 0,
        mouseMovementCount: Int = 0,
        mouseClickCount: Int = 0,
        projectName: String? = nil
    ) {
        self.blockStart = blockStart
        self.appName = appName
        self.category = category
        self.activeDuration = activeDuration
        self.typingDuration = typingDuration
        self.keystrokeCount = keystrokeCount
        self.mouseMovementCount = mouseMovementCount
        self.mouseClickCount = mouseClickCount
        self.projectName = projectName
    }
}

// MARK: - GRDB Support
extension TimeBlock: FetchableRecord, PersistableRecord {
    static let databaseTableName = "blocks_5min"

    enum Columns {
        static let blockStart = Column("blockStart")
        static let appName = Column("appName")
        static let category = Column("category")
        static let activeDuration = Column("activeDuration")
        static let typingDuration = Column("typingDuration")
        static let keystrokeCount = Column("keystrokeCount")
        static let mouseMovementCount = Column("mouseMovementCount")
        static let mouseClickCount = Column("mouseClickCount")
        static let projectName = Column("projectName")
    }

    // Composite primary key
    static let persistenceConflictPolicy = PersistenceConflictPolicy(
        insert: .replace,
        update: .replace
    )
}

// MARK: - Helper Functions
extension TimeBlock {
    /// Round timestamp to 5-minute boundary (per PRD FR-009)
    static func roundTo5Minutes(_ date: Date) -> Date {
        let timestamp = date.timeIntervalSince1970
        let rounded = floor(timestamp / 300) * 300
        return Date(timeIntervalSince1970: rounded)
    }

    /// Get the 5-minute block start time for a given date
    static func blockStartTime(for date: Date) -> Date {
        return roundTo5Minutes(date)
    }

    /// Formatted time range for display (e.g., "14:05-14:10")
    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: blockStart)
        let end = formatter.string(from: blockStart.addingTimeInterval(300))
        return "\(start)-\(end)"
    }

    /// Duration as formatted string (e.g., "4m 30s")
    var durationString: String {
        let minutes = activeDuration / 60
        let seconds = activeDuration % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}
