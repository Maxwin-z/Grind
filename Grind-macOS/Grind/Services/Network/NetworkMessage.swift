//
//  NetworkMessage.swift
//  Grind
//
//  Network message protocol for client-server communication
//

import Foundation

/// Base protocol for all network messages
protocol NetworkMessage: Codable {
    var type: MessageType { get }
    var timestamp: Date { get }
}

/// Message type enumeration
enum MessageType: String, Codable {
    case welcome
    case historicalStats
    case timeBlocks
    case realtimeActivity
    case keystroke
    case mouseEvent
    case iterm2Sessions
    case heartbeat
    case selectedApps
    case error
}

// MARK: - Server Messages

/// Welcome message sent when client connects
struct WelcomeMessage: NetworkMessage {
    let type: MessageType = .welcome
    let timestamp: Date
    let serverVersion: String
    let deviceName: String

    init() {
        self.timestamp = Date()
        self.serverVersion = "1.0.0"
        self.deviceName = Host.current().localizedName ?? "Unknown Mac"
    }
}

/// Historical statistics message
struct HistoricalStatsMessage: NetworkMessage {
    let type: MessageType = .historicalStats
    let timestamp: Date
    let dailyStats: [DailyStatsData]
    let topApps: [AppStatsData]
    let dailyAppBreakdown: [DailyAppBreakdownData]

    init(dailyStats: [DailyStatsData], topApps: [AppStatsData], dailyAppBreakdown: [DailyAppBreakdownData]) {
        self.timestamp = Date()
        self.dailyStats = dailyStats
        self.topApps = topApps
        self.dailyAppBreakdown = dailyAppBreakdown
    }
}

struct DailyStatsData: Codable {
    let date: String // YYYY-MM-DD format
    let totalSeconds: Int
    let totalKeystrokes: Int
    let totalMouseMovements: Int
    let totalMouseClicks: Int
    let appCount: Int
}

struct AppStatsData: Codable {
    let bundleIdentifier: String
    let appName: String
    let iconPath: String?
    let totalSeconds: Int
    let keystrokes: Int
    let mouseMovements: Int
    let mouseClicks: Int
    let lastActive: Date?
    let colorHex: String?
}

struct DailyAppBreakdownData: Codable {
    let date: String
    let apps: [DailyAppMetricsData]
}

struct DailyAppMetricsData: Codable {
    let appName: String
    let duration: Int
    let keystrokes: Int
    let category: String
    let colorHex: String?
}

/// Time blocks message (5-minute blocks for today)
struct TimeBlocksMessage: NetworkMessage {
    let type: MessageType = .timeBlocks
    let timestamp: Date
    let date: String // YYYY-MM-DD format
    let blocks: [TimeBlockData]

    init(date: String, blocks: [TimeBlockData]) {
        self.timestamp = Date()
        self.date = date
        self.blocks = blocks
    }
}

struct TimeBlockData: Codable {
    let blockStart: Date
    let appName: String?
    let duration: Int // seconds of activity in this block
    let keystrokes: Int
    let mouseMovements: Int
    let mouseClicks: Int
    let colorHex: String?
}

/// Real-time activity update
struct RealtimeActivityMessage: NetworkMessage {
    let type: MessageType = .realtimeActivity
    let timestamp: Date
    let activeApp: ActiveAppData
    let isTyping: Bool
    let idleSeconds: Double
    let keystrokesSinceLastUpdate: Int
    let mouseMovementsSinceLastUpdate: Int
    let mouseClicksSinceLastUpdate: Int
}

struct ActiveAppData: Codable {
    let bundleIdentifier: String
    let appName: String
    let windowTitle: String?
    let projectName: String?
}

/// Individual keystroke event
struct KeystrokeMessage: NetworkMessage {
    let type: MessageType = .keystroke
    let timestamp: Date
    let key: String
    let keyCode: UInt16
    let modifiers: [String]
    let appBundleIdentifier: String
}

/// Mouse event
struct MouseEventMessage: NetworkMessage {
    let type: MessageType = .mouseEvent
    let timestamp: Date
    let eventType: MouseEventType
    let x: Double?
    let y: Double?
    let button: Int?
    let appBundleIdentifier: String
}

enum MouseEventType: String, Codable {
    case movement
    case leftClick
    case rightClick
    case otherClick
    case scroll
}

/// iTerm2 sessions information
struct ITerm2SessionsMessage: NetworkMessage {
    let type: MessageType = .iterm2Sessions
    let timestamp: Date
    let sessions: [ITerm2SessionData]
}

struct ITerm2SessionData: Codable {
    let sessionId: String
    let name: String
    let currentDirectory: String?
    let currentCommand: String?
    let isActive: Bool
    let windowIndex: Int
    let tabIndex: Int
    let paneIndex: Int
}

/// Heartbeat message (periodic keep-alive and activity summary)
struct HeartbeatMessage: NetworkMessage {
    let type: MessageType = .heartbeat
    let timestamp: Date
    let activeApp: ActiveAppData?
    let isActive: Bool // Is user active (not idle)
    let keystrokesLastMinute: Int
    let mouseEventsLastMinute: Int
}

/// Selected apps state message
struct SelectedAppsMessage: NetworkMessage {
    let type: MessageType = .selectedApps
    let timestamp: Date
    let apps: [SelectedAppData]

    init(apps: [SelectedAppData]) {
        self.timestamp = Date()
        self.apps = apps
    }
}

struct SelectedAppData: Codable {
    let bundleIdentifier: String
    let appName: String
    let accentColorHex: String
    let iconPNGData: Data?
}

/// Error message
struct ErrorMessage: NetworkMessage {
    let type: MessageType = .error
    let timestamp: Date
    let errorCode: String
    let message: String

    init(code: String, message: String) {
        self.timestamp = Date()
        self.errorCode = code
        self.message = message
    }
}

// MARK: - Message Encoding/Decoding

struct MessageEncoder {
    static func encode<T: NetworkMessage>(_ message: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        // Encode the message directly (flat structure)
        let json = try encoder.encode(message)

        // Add length prefix (4 bytes) for frame delimiting
        // Use big-endian (network byte order) for cross-platform compatibility
        var lengthData = Data()
        var length = UInt32(json.count).bigEndian
        withUnsafeBytes(of: &length) { lengthData.append(contentsOf: $0) }

        return lengthData + json
    }
}

struct MessageDecoder {
    static func decodeType(from data: Data) throws -> MessageType {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct TypeWrapper: Decodable {
            let type: MessageType
        }

        let wrapper = try decoder.decode(TypeWrapper.self, from: data)
        return wrapper.type
    }
}
