//
//  NetworkMessage.swift
//  Grind
//
//  Network message models matching macOS NetworkMessage protocol
//

import Foundation

// MARK: - Network Message Types

enum NetworkMessageType: String, Codable {
    case welcome
    case historicalStats
    case realtimeActivity
    case heartbeat
    case keystroke
    case mouseEvent
    case iterm2Sessions
    case error
}

// MARK: - Main Message Wrapper

struct NetworkMessage: Codable {
    let type: NetworkMessageType
    let timestamp: Date
    let payload: PayloadData
}

// MARK: - Payload Data

enum PayloadData: Codable {
    case welcome(WelcomeData)
    case historicalStats(HistoricalStatsData)
    case realtimeActivity(RealtimeActivityData)
    case heartbeat(HeartbeatData)
    case keystroke(KeystrokeData)
    case mouseEvent(MouseEventData)
    case iterm2Sessions(ITerm2SessionsData)
    case error(ErrorData)

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try to decode as different payload types
        if let welcome = try? container.decode(WelcomeData.self) {
            self = .welcome(welcome)
        } else if let historical = try? container.decode(HistoricalStatsData.self) {
            self = .historicalStats(historical)
        } else if let realtime = try? container.decode(RealtimeActivityData.self) {
            self = .realtimeActivity(realtime)
        } else if let heartbeat = try? container.decode(HeartbeatData.self) {
            self = .heartbeat(heartbeat)
        } else if let keystroke = try? container.decode(KeystrokeData.self) {
            self = .keystroke(keystroke)
        } else if let mouse = try? container.decode(MouseEventData.self) {
            self = .mouseEvent(mouse)
        } else if let iterm2 = try? container.decode(ITerm2SessionsData.self) {
            self = .iterm2Sessions(iterm2)
        } else if let error = try? container.decode(ErrorData.self) {
            self = .error(error)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown payload type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .welcome(let data):
            try container.encode(data)
        case .historicalStats(let data):
            try container.encode(data)
        case .realtimeActivity(let data):
            try container.encode(data)
        case .heartbeat(let data):
            try container.encode(data)
        case .keystroke(let data):
            try container.encode(data)
        case .mouseEvent(let data):
            try container.encode(data)
        case .iterm2Sessions(let data):
            try container.encode(data)
        case .error(let data):
            try container.encode(data)
        }
    }
}

// MARK: - Payload Models

struct WelcomeData: Codable {
    let serverVersion: String
    let deviceName: String
}

struct HistoricalStatsData: Codable {
    let dailyStats: [DailyStatsData]
    let topApps: [AppStatsData]
}

struct DailyStatsData: Codable, Identifiable {
    var id: String { date }
    let date: String
    let totalSeconds: Int
    let totalKeystrokes: Int
    let totalMouseMovements: Int
    let totalMouseClicks: Int
    let appCount: Int
}

struct AppStatsData: Codable, Identifiable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let appName: String
    let iconPath: String?
    let totalSeconds: Int
    let keystrokes: Int
    let mouseMovements: Int
    let mouseClicks: Int
    let lastActive: Date?
}

struct RealtimeActivityData: Codable {
    let activeApp: ActiveAppData
    let isTyping: Bool
    let idleSeconds: Double
    let keystrokesSinceLastUpdate: Int
    let mouseMovementsSinceLastUpdate: Int
    let mouseClicksSinceLastUpdate: Int
}

struct ActiveAppData: Codable {
    let bundleId: String
    let appName: String
    let windowTitle: String?
    let projectName: String?
}

struct HeartbeatData: Codable {
    let totalKeystrokesLastMinute: Int
    let totalMouseMovementsLastMinute: Int
    let totalMouseClicksLastMinute: Int
    let activeTimeLastMinute: Int
}

struct KeystrokeData: Codable {
    let timestamp: Date
    let appName: String
}

struct MouseEventData: Codable {
    let timestamp: Date
    let appName: String
    let eventType: String // "movement" or "click"
}

struct ITerm2SessionsData: Codable {
    let sessions: [ITerm2Session]
}

struct ITerm2Session: Codable {
    let sessionId: String
    let tabTitle: String
    let workingDirectory: String
}

struct ErrorData: Codable {
    let message: String
}
