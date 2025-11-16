//
//  HeartbeatService.swift
//  Grind
//
//  Core heartbeat generation and saving service
//  Implements PRD FR-003 heartbeat algorithm
//

import Foundation

/// Service for generating and saving heartbeats
/// Implements the WakaTime-style heartbeat algorithm from PRD FR-003
class HeartbeatService {
    static let shared = HeartbeatService()

    private let appMonitor = AppMonitor.shared
    private let idleDetector = IdleDetector.shared
    private let keystrokeCounter = KeystrokeCounter.shared
    private let mouseCounter = MouseMovementCounter.shared
    private let heartbeatRepo = HeartbeatRepository()
    private let categoryRepo = AppCategoryRepository()

    private var lastHeartbeatTime: Date?

    private init() {}

    // MARK: - Heartbeat Generation

    /// Generate a heartbeat for current activity
    /// Returns nil if user is away/idle (>120s)
    func generateHeartbeat() -> Heartbeat? {
        // Get current app
        guard let currentApp = appMonitor.getCurrentApp() else {
            return nil
        }

        // Check idle time
        let idleTime = idleDetector.getIdleTime()

        // Don't generate heartbeat if away (>120s per PRD FR-002)
        guard idleTime < 120 else {
            return nil
        }

        // Get category
        let category = appMonitor.getCategoryFor(bundleId: currentApp.bundleId)

        // Get project name from window title
        let projectName = appMonitor.extractProjectName(from: currentApp.windowTitle)

        // Get keystroke count since last heartbeat
        let keystrokeCount = keystrokeCounter.getCurrentCount()

        // Get mouse activity counts
        let mouseCounts = mouseCounter.getCurrentCounts()

        // Determine if typing
        let isTyping = idleTime < 10

        // Create heartbeat
        let heartbeat = Heartbeat(
            timestamp: Date(),
            appName: currentApp.name,
            bundleId: currentApp.bundleId,
            windowTitle: currentApp.windowTitle,
            projectName: projectName,
            category: category,
            isTyping: isTyping,
            idleSeconds: idleTime,
            keystrokeCount: keystrokeCount,
            mouseMovementCount: mouseCounts.movements,
            mouseClickCount: mouseCounts.clicks
        )

        return heartbeat
    }

    /// Save heartbeat to database
    func saveHeartbeat(_ heartbeat: Heartbeat) throws {
        try heartbeatRepo.save(heartbeat)
        lastHeartbeatTime = heartbeat.timestamp

        // Reset counters after saving
        keystrokeCounter.resetCount()
        mouseCounter.resetCounts()
    }

    /// Generate and save heartbeat if active
    @discardableResult
    func recordActivity() -> Heartbeat? {
        guard let heartbeat = generateHeartbeat() else {
            return nil
        }

        do {
            try saveHeartbeat(heartbeat)
            return heartbeat
        } catch {
            print("❌ Error saving heartbeat: \(error)")
            return nil
        }
    }

    // MARK: - Session Management

    /// Check if current activity continues the previous session
    /// Per PRD FR-003: Max 120 second gap
    func isContinuousSession() -> Bool {
        guard let lastTime = lastHeartbeatTime else {
            return false
        }

        let gap = Date().timeIntervalSince(lastTime)
        return gap <= 120
    }

    /// Close current session (on idle or app quit)
    func closeSession() {
        lastHeartbeatTime = nil
        print("Session closed")
    }

    /// Get time since last heartbeat
    func timeSinceLastHeartbeat() -> TimeInterval? {
        guard let lastTime = lastHeartbeatTime else {
            return nil
        }
        return Date().timeIntervalSince(lastTime)
    }

    // MARK: - Statistics

    /// Get today's total active time
    func getTodayActiveTime() -> TimeInterval {
        do {
            return try heartbeatRepo.getTodayActiveTime()
        } catch {
            print("❌ Error getting today's active time: \(error)")
            return 0
        }
    }

    /// Get today's keystroke count
    func getTodayKeystrokeCount() -> Int {
        do {
            return try heartbeatRepo.getTodayKeystrokeCount()
        } catch {
            print("❌ Error getting today's keystroke count: \(error)")
            return 0
        }
    }
}
