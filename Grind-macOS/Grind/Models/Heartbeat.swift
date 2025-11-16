//
//  Heartbeat.swift
//  Grind
//
//  Raw activity record - the fundamental unit of tracking
//  See PRD FR-008 for schema details
//

import Foundation
import GRDB

/// A heartbeat represents a single point-in-time activity snapshot
/// Generated every 2 seconds when user is active
struct Heartbeat: Codable {
    var id: String
    var timestamp: Date
    var appName: String
    var bundleId: String
    var windowTitle: String?
    var projectName: String?
    var filePath: String?
    var language: String?
    var category: String
    var isTyping: Bool
    var idleSeconds: Double
    var keystrokeCount: Int
    var mouseMovementCount: Int
    var mouseClickCount: Int

    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        appName: String,
        bundleId: String,
        windowTitle: String? = nil,
        projectName: String? = nil,
        filePath: String? = nil,
        language: String? = nil,
        category: String = "Other",
        isTyping: Bool = false,
        idleSeconds: Double = 0,
        keystrokeCount: Int = 0,
        mouseMovementCount: Int = 0,
        mouseClickCount: Int = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appName = appName
        self.bundleId = bundleId
        self.windowTitle = windowTitle
        self.projectName = projectName
        self.filePath = filePath
        self.language = language
        self.category = category
        self.isTyping = isTyping
        self.idleSeconds = idleSeconds
        self.keystrokeCount = keystrokeCount
        self.mouseMovementCount = mouseMovementCount
        self.mouseClickCount = mouseClickCount
    }
}

// MARK: - GRDB Support
extension Heartbeat: FetchableRecord, PersistableRecord {
    static let databaseTableName = "heartbeats"

    enum Columns {
        static let id = Column("id")
        static let timestamp = Column("timestamp")
        static let appName = Column("appName")
        static let bundleId = Column("bundleId")
        static let windowTitle = Column("windowTitle")
        static let projectName = Column("projectName")
        static let filePath = Column("filePath")
        static let language = Column("language")
        static let category = Column("category")
        static let isTyping = Column("isTyping")
        static let idleSeconds = Column("idleSeconds")
        static let keystrokeCount = Column("keystrokeCount")
        static let mouseMovementCount = Column("mouseMovementCount")
        static let mouseClickCount = Column("mouseClickCount")
    }
}

// MARK: - Computed Properties
extension Heartbeat {
    /// Whether this heartbeat represents active work (not passive/idle)
    var isActive: Bool {
        return idleSeconds < 30
    }

    /// Activity level classification per PRD FR-002
    var activityLevel: ActivityLevel {
        switch idleSeconds {
        case ..<10:
            return .typing
        case ..<30:
            return .active
        case ..<120:
            return .reading
        default:
            return .away
        }
    }
}

/// Activity level classification from PRD FR-002
enum ActivityLevel: String, Codable {
    case typing     // Active keyboard input (<10s)
    case active     // Recent mouse/keyboard activity (<30s)
    case reading    // Mouse movement only (30-120s)
    case away       // No activity (>120s)
}
