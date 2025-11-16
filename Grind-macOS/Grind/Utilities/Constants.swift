//
//  Constants.swift
//  Grind
//
//  App-wide constants
//

import Foundation

enum Constants {
    // MARK: - Timing

    /// Poll interval for activity monitoring (2 seconds per PRD FR-001)
    static let pollInterval: TimeInterval = 2.0

    /// Idle threshold for active state (30 seconds per PRD FR-002)
    static let activeThreshold: TimeInterval = 30

    /// Idle threshold for away state (120 seconds per PRD FR-002)
    static let awayThreshold: TimeInterval = 120

    /// Maximum gap for continuous session (120 seconds per PRD FR-003)
    static let maxSessionGap: TimeInterval = 120

    /// Time block size (5 minutes per PRD FR-009)
    static let timeBlockSize: TimeInterval = 300

    // MARK: - Database

    /// Heartbeat retention period (90 days per PRD)
    static let heartbeatRetentionDays = 90

    /// Database flush interval (30 seconds)
    static let databaseFlushInterval: TimeInterval = 30

    // MARK: - UI

    /// Menu bar update interval
    static let menuBarUpdateInterval: TimeInterval = 5.0

    /// Dashboard refresh interval
    static let dashboardRefreshInterval: TimeInterval = 5.0

    // MARK: - App Info

    static let appName = "Grind"
    static let bundleIdentifier = "me.maxwin.Grind"
    static let appSupportDirectoryName = "Grind"

    // MARK: - Permissions

    static let requiredPermissions = [
        "Accessibility",  // For keystroke counting and idle detection
    ]

    static let optionalPermissions = [
        "Screen Recording"  // For enhanced terminal tracking (Phase 2)
    ]
}
