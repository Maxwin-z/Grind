//
//  AppInfo.swift
//  Grind
//
//  Application information snapshot
//

import Foundation
import AppKit

/// Information about a running application
struct AppInfo {
    let name: String
    let bundleId: String
    let windowTitle: String?
    let processId: pid_t
    let icon: NSImage?
    let lastKeyPressed: String?

    init(
        name: String,
        bundleId: String,
        windowTitle: String? = nil,
        processId: pid_t = 0,
        icon: NSImage? = nil,
        lastKeyPressed: String? = nil
    ) {
        self.name = name
        self.bundleId = bundleId
        self.windowTitle = windowTitle
        self.processId = processId
        self.icon = icon
        self.lastKeyPressed = lastKeyPressed
    }

    /// Create from NSRunningApplication
    init?(runningApp: NSRunningApplication) {
        guard let bundleId = runningApp.bundleIdentifier,
              let name = runningApp.localizedName else {
            return nil
        }

        self.name = name
        self.bundleId = bundleId
        self.windowTitle = nil  // Will be populated from window info
        self.processId = runningApp.processIdentifier
        self.icon = runningApp.icon
        self.lastKeyPressed = nil  // Will be populated when monitoring
    }
}

// MARK: - Equatable
extension AppInfo: Equatable {
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        return lhs.bundleId == rhs.bundleId
    }
}

// MARK: - Hashable
extension AppInfo: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleId)
    }
}
