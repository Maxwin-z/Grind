//
//  GrindApp.swift
//  Grind
//
//  Created by Maxwin on 2025/11/16.
//

import AppKit
import SwiftUI

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
      // Initialize AppService and fetch applications to populate known apps
      let appService = AppService()
      await appService.fetchApplications()
      AppDataSharingPreferences.shared.updateKnownApps(appService.applications)

      NetworkService.shared.startServer()
    }

    statusBarController.activate()
  }
}
