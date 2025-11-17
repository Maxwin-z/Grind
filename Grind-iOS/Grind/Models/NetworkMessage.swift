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
    case timeBlocks
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

    // Custom decoding to handle flat message structure from macOS
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(NetworkMessageType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)

        // Decode the entire container as the payload based on type
        switch type {
        case .welcome:
            let data = try WelcomeData(from: decoder)
            payload = .welcome(data)
        case .historicalStats:
            let data = try HistoricalStatsData(from: decoder)
            payload = .historicalStats(data)
        case .timeBlocks:
            let data = try TimeBlocksData(from: decoder)
            payload = .timeBlocks(data)
        case .realtimeActivity:
            let data = try RealtimeActivityData(from: decoder)
            payload = .realtimeActivity(data)
        case .heartbeat:
            let data = try HeartbeatData(from: decoder)
            payload = .heartbeat(data)
        case .keystroke:
            let data = try KeystrokeData(from: decoder)
            payload = .keystroke(data)
        case .mouseEvent:
            let data = try MouseEventData(from: decoder)
            payload = .mouseEvent(data)
        case .iterm2Sessions:
            let data = try ITerm2SessionsData(from: decoder)
            payload = .iterm2Sessions(data)
        case .error:
            let data = try ErrorData(from: decoder)
            payload = .error(data)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, timestamp
    }
}

// MARK: - Payload Data

enum PayloadData: Codable {
    case welcome(WelcomeData)
    case historicalStats(HistoricalStatsData)
    case timeBlocks(TimeBlocksData)
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
        } else if let timeBlocks = try? container.decode(TimeBlocksData.self) {
            self = .timeBlocks(timeBlocks)
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
        case .timeBlocks(let data):
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

struct TimeBlocksData: Codable {
    let date: String
    let blocks: [TimeBlockData]
}

struct TimeBlockData: Codable, Identifiable {
    var id: Date { blockStart }
    let blockStart: Date
    let appName: String?
    let duration: Int
    let keystrokes: Int
    let mouseMovements: Int
    let mouseClicks: Int
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
    let bundleIdentifier: String
    let appName: String
    let windowTitle: String?
    let projectName: String?
}

struct HeartbeatData: Codable {
    let activeApp: ActiveAppData?
    let isActive: Bool
    let keystrokesLastMinute: Int
    let mouseEventsLastMinute: Int
}

struct KeystrokeData: Codable {
    let key: String
    let keyCode: UInt16
    let modifiers: [String]
    let appBundleIdentifier: String
}

struct MouseEventData: Codable {
    let eventType: String
    let x: Double?
    let y: Double?
    let button: Int?
    let appBundleIdentifier: String
}

struct ITerm2SessionsData: Codable {
    let sessions: [ITerm2Session]
}

struct ITerm2Session: Codable {
    let sessionId: String
    let name: String
    let currentDirectory: String?
    let currentCommand: String?
    let isActive: Bool
    let windowIndex: Int
    let tabIndex: Int
    let paneIndex: Int
}

struct ErrorData: Codable {
    let message: String
}
