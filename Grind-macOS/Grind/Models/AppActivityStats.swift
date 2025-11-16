//
//  AppActivityStats.swift
//  Grind
//
//  Aggregated activity statistics per application
//

import Foundation

/// Activity statistics for a specific application
struct AppActivityStats: Identifiable {
    let id: String  // bundleId
    let appName: String
    let bundleId: String
    let totalActiveTime: TimeInterval  // Total active time in seconds
    let totalKeystrokes: Int
    let totalMouseMovements: Int
    let totalMouseClicks: Int
    let sessionCount: Int
    let lastActiveTime: Date?
    let category: String

    /// Keystrokes per minute
    var keystrokesPerMinute: Double {
        guard totalActiveTime > 0 else { return 0 }
        return Double(totalKeystrokes) / (totalActiveTime / 60.0)
    }

    /// Mouse movements per minute
    var mouseMovementsPerMinute: Double {
        guard totalActiveTime > 0 else { return 0 }
        return Double(totalMouseMovements) / (totalActiveTime / 60.0)
    }

    /// Mouse clicks per minute
    var mouseClicksPerMinute: Double {
        guard totalActiveTime > 0 else { return 0 }
        return Double(totalMouseClicks) / (totalActiveTime / 60.0)
    }

    /// Total activity events (keystrokes + mouse movements + clicks)
    var totalActivityEvents: Int {
        return totalKeystrokes + totalMouseMovements + totalMouseClicks
    }

    /// Activity events per minute
    var activityEventsPerMinute: Double {
        guard totalActiveTime > 0 else { return 0 }
        return Double(totalActivityEvents) / (totalActiveTime / 60.0)
    }

    /// Formatted active time string
    var formattedActiveTime: String {
        let hours = Int(totalActiveTime) / 3600
        let minutes = (Int(totalActiveTime) % 3600) / 60
        let seconds = Int(totalActiveTime) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    /// Activity level classification
    var activityLevel: ActivityIntensity {
        let eventsPerMin = activityEventsPerMinute
        switch eventsPerMin {
        case ..<10:
            return .low
        case 10..<50:
            return .medium
        case 50..<100:
            return .high
        default:
            return .veryHigh
        }
    }
}

/// Activity intensity classification
enum ActivityIntensity: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case veryHigh = "Very High"

    var color: String {
        switch self {
        case .low:
            return "gray"
        case .medium:
            return "blue"
        case .high:
            return "orange"
        case .veryHigh:
            return "red"
        }
    }
}

/// Activity type breakdown
struct ActivityTypeBreakdown {
    let keystrokes: Int
    let mouseMovements: Int
    let mouseClicks: Int

    var keystrokePercentage: Double {
        let total = Double(keystrokes + mouseMovements + mouseClicks)
        guard total > 0 else { return 0 }
        return Double(keystrokes) / total * 100
    }

    var mouseMovementPercentage: Double {
        let total = Double(keystrokes + mouseMovements + mouseClicks)
        guard total > 0 else { return 0 }
        return Double(mouseMovements) / total * 100
    }

    var mouseClickPercentage: Double {
        let total = Double(keystrokes + mouseMovements + mouseClicks)
        guard total > 0 else { return 0 }
        return Double(mouseClicks) / total * 100
    }
}
