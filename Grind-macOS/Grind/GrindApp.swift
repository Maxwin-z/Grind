//
//  GrindApp.swift
//  Grind
//
//  Created by Maxwin on 2025/11/16.
//

import SwiftUI
import AppKit

@main
struct GrindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBarController = StatusBarMenuController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ActivityMonitor.shared.startMonitoring()

        Task { @MainActor in
            NetworkService.shared.startServer()
        }

        statusBarController.activate()
    }
}
