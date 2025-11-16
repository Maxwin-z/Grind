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
    init() {
        // Start activity monitoring when app launches
        ActivityMonitor.shared.startMonitoring()

        // Start network service for remote client connections
        Task { @MainActor in
            NetworkService.shared.startServer()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Set window to float on top
                    if let window = NSApplication.shared.windows.first {
                        window.level = .floating
                        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                    }
                }
        }
    }
}
