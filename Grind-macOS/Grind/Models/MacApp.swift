//
//  MacApp.swift
//  Grind
//
//  Created by Maxwin on 2025/11/16.
//

import Foundation
import AppKit

struct MacApp: Identifiable, Hashable {
    let id: UUID = UUID()
    let name: String
    let bundleIdentifier: String
    let path: URL
    let icon: NSImage?
    let version: String?
    let isRunning: Bool

    init(name: String, bundleIdentifier: String, path: URL, icon: NSImage?, version: String?, isRunning: Bool = false) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.icon = icon
        self.version = version
        self.isRunning = isRunning
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: MacApp, rhs: MacApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}
