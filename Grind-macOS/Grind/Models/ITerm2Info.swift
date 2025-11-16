//
//  ITerm2Info.swift
//  Grind
//
//  Created by Maxwin on 2025/11/16.
//

import Foundation

struct CursorPosition: Codable {
    let x: Int
    let y: Int
}

struct Keystroke: Codable {
    let key: String
    let modifiers: Int
    let timestamp: Double
}

struct ITerm2Session: Codable, Identifiable {
    let sessionId: String
    let job: String?
    let tty: String?
    let path: String?
    let user: String?
    let hostname: String?
    let screenLines: [String]
    let isActive: Bool
    let error: String?
    let cursorPosition: CursorPosition?
    let recentKeystrokes: [Keystroke]?

    var id: String { sessionId }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case job
        case tty
        case path
        case user
        case hostname
        case screenLines = "screen_lines"
        case isActive = "is_active"
        case error
        case cursorPosition = "cursor_position"
        case recentKeystrokes = "recent_keystrokes"
    }

    var displayName: String {
        if let error = error {
            return "Error: \(error)"
        }
        return job ?? "Unknown"
    }

    var displayPath: String {
        path ?? ""
    }

    var displayHost: String {
        if let user = user, !user.isEmpty, let hostname = hostname {
            return "\(user)@\(hostname)"
        } else if let hostname = hostname {
            return hostname
        }
        return ""
    }

    var lastScreenLines: [String] {
        Array(screenLines.suffix(10))
    }
}

struct ITerm2Tab: Codable, Identifiable {
    let tabId: String
    let isCurrent: Bool
    let sessions: [ITerm2Session]

    var id: String { tabId }

    enum CodingKeys: String, CodingKey {
        case tabId = "tab_id"
        case isCurrent = "is_current"
        case sessions
    }

    var activeSession: ITerm2Session? {
        sessions.first { $0.isActive }
    }
}

struct ITerm2Window: Codable, Identifiable {
    let windowId: String
    let isCurrent: Bool
    let tabs: [ITerm2Tab]

    var id: String { windowId }

    enum CodingKeys: String, CodingKey {
        case windowId = "window_id"
        case isCurrent = "is_current"
        case tabs
    }

    var currentTab: ITerm2Tab? {
        tabs.first { $0.isCurrent }
    }
}

struct ITerm2Info: Codable {
    let windows: [ITerm2Window]
    let activeSessionId: String?

    enum CodingKeys: String, CodingKey {
        case windows
        case activeSessionId = "active_session_id"
    }

    var currentWindow: ITerm2Window? {
        windows.first { $0.isCurrent }
    }

    var activeSession: ITerm2Session? {
        guard let sessionId = activeSessionId else { return nil }

        for window in windows {
            for tab in window.tabs {
                for session in tab.sessions {
                    if session.sessionId == sessionId {
                        return session
                    }
                }
            }
        }
        return nil
    }

    var allSessions: [ITerm2Session] {
        windows.flatMap { window in
            window.tabs.flatMap { tab in
                tab.sessions
            }
        }
    }
}
