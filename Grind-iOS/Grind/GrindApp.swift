//
//  GrindApp.swift
//  Grind
//
//  Created by Maxwin on 2025/11/17.
//

import SwiftUI
import UIKit

@main
struct GrindApp: App {
    init() {
        // Keep screen always on (prevent auto-lock)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
