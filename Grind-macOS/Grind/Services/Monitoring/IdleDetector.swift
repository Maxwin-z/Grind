//
//  IdleDetector.swift
//  Grind
//
//  Detects user idle time using system events
//  Implements PRD FR-002 idle detection algorithm
//

import Foundation
import CoreGraphics

/// Idle detection service following PRD FR-002 specifications
class IdleDetector {
    static let shared = IdleDetector()

    private init() {}

    // MARK: - Idle Time Detection

    /// Get seconds since last keyboard activity
    func getKeyboardIdleTime() -> TimeInterval {
        return CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .keyDown
        )
    }

    /// Get seconds since last mouse activity
    func getMouseIdleTime() -> TimeInterval {
        return CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .mouseMoved
        )
    }

    /// Get overall idle time (minimum of keyboard and mouse)
    /// Per PRD FR-002: Returns most recent activity
    func getIdleTime() -> TimeInterval {
        let keyboardIdle = getKeyboardIdleTime()
        let mouseIdle = getMouseIdleTime()

        // Return minimum (most recent activity)
        return min(keyboardIdle, mouseIdle)
    }

    // MARK: - Activity Level Classification

    /// Get current activity level per PRD FR-002 thresholds
    func getActivityLevel() -> ActivityLevel {
        let idleTime = getIdleTime()

        switch idleTime {
        case ..<10:
            return .typing      // Active keyboard input (<10s)
        case ..<30:
            return .active      // Recent mouse/keyboard activity (<30s)
        case ..<120:
            return .reading     // Mouse movement only (30-120s)
        default:
            return .away        // No activity (>120s)
        }
    }

    /// Check if user is currently active
    /// Active = idle time < 30 seconds
    func isActive() -> Bool {
        return getIdleTime() < 30
    }

    /// Check if user is typing
    /// Typing = idle time < 10 seconds
    func isTyping() -> Bool {
        return getIdleTime() < 10
    }

    /// Check if user is away/idle
    /// Away = idle time > 120 seconds
    func isAway() -> Bool {
        return getIdleTime() > 120
    }

    // MARK: - Activity State Description

    /// Get human-readable activity state
    func getActivityDescription() -> String {
        let level = getActivityLevel()
        let idleTime = getIdleTime()

        switch level {
        case .typing:
            return "Typing"
        case .active:
            return "Active (\(Int(idleTime))s idle)"
        case .reading:
            return "Reading (\(Int(idleTime))s idle)"
        case .away:
            let minutes = Int(idleTime / 60)
            return "Away (\(minutes)m idle)"
        }
    }

    // MARK: - Session Detection

    /// Check if current activity continues previous session
    /// Per PRD FR-003: Max 120 second gap for continuous session
    func isContinuousSession(since lastHeartbeat: Date) -> Bool {
        let gap = Date().timeIntervalSince(lastHeartbeat)
        return gap <= 120
    }

    /// Get time since last activity (for session tracking)
    func timeSinceLastActivity() -> TimeInterval {
        return getIdleTime()
    }
}

// MARK: - Idle Time Formatting

extension IdleDetector {
    /// Format idle time as human-readable string
    func formatIdleTime(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else {
            let minutes = Int(seconds / 60)
            let remainingSeconds = Int(seconds) % 60
            if remainingSeconds > 0 {
                return "\(minutes)m \(remainingSeconds)s"
            } else {
                return "\(minutes)m"
            }
        }
    }
}
