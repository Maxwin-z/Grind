//
//  ContentView.swift
//  Grind
//
//  Created by Maxwin on 2025/11/16.
//

import SwiftUI
import Combine
import AppKit
import os.log

struct ContentView: View {
    @StateObject private var appService = AppService()
    @StateObject private var dataSharingPreferences = AppDataSharingPreferences.shared
    @State private var searchText = ""
    @State private var activeApp: AppInfo?
    @State private var appActivityStats: [AppActivityStats] = []
    @State private var hasAccessibilityPermission = PermissionManager.shared.hasAccessibilityPermission()
    @State private var lastKeyPressed: String = ""
    @State private var lastKeyTimestamp: Date = Date()

    private let appMonitor = AppMonitor.shared
    private let permissionManager = PermissionManager.shared
    private let heartbeatRepo = HeartbeatRepository()
    private let iterm2Service = ITerm2Service.shared
    private let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    private let logger = Logger(subsystem: "me.maxwin.Grind", category: "ContentView")

    var filteredApps: [MacApp] {
        let apps: [MacApp]
        if searchText.isEmpty {
            apps = appService.applications
        } else {
            apps = appService.applications.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort with Grind.app always at the top
        return apps.sorted { lhs, rhs in
            let lhsIsGrind = lhs.bundleIdentifier == "me.maxwin.Grind"
            let rhsIsGrind = rhs.bundleIdentifier == "me.maxwin.Grind"

            if lhsIsGrind != rhsIsGrind {
                return lhsIsGrind
            }

            // Then by running status
            if lhs.isRunning != rhs.isRunning {
                return lhs.isRunning
            }

            // Finally by name
            return lhs.name < rhs.name
        }
    }

    var runningApps: [MacApp] {
        filteredApps.filter { $0.isRunning }
    }

    var otherApps: [MacApp] {
        filteredApps.filter { !$0.isRunning }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                if !hasAccessibilityPermission {
                    PermissionBanner(
                        title: "Accessibility Access Needed",
                        message: "Grant access so Grind can count keystrokes and mouse activity for each app.",
                        primaryButtonTitle: "Open Settings",
                        primaryAction: requestAccessibilityPermission,
                        secondaryButtonTitle: "Check Again",
                        secondaryAction: refreshPermissionStatus
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }

                // Search bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("Search applications...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                .cornerRadius(4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                // Application list
                if appService.isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .controlSize(.small)
                        Text("Loading applications...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredApps.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "No applications found" : "No results for \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.square")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("Check the apps whose activity data should be sent to Grind clients.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)

                        List {
                            if !runningApps.isEmpty {
                                Section {
                                    ForEach(runningApps) { app in
                                        AppRowView(app: app, dataSharingPreferences: dataSharingPreferences)
                                            .listRowBackground(Color.clear)
                                            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                                    }
                                } header: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 6))
                                        Text("Running Apps (\(runningApps.count))")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.leading, 12)
                                }
                            }

                            if !otherApps.isEmpty {
                                Section {
                                    ForEach(otherApps) { app in
                                        AppRowView(app: app, dataSharingPreferences: dataSharingPreferences)
                                            .listRowBackground(Color.clear)
                                            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                                    }
                                } header: {
                                    Text("All Apps (\(otherApps.count))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.leading, 12)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Applications (\(filteredApps.count))")
            .task {
                refreshPermissionStatus()
                await appService.fetchApplications()
                updateActiveApp()
                updateActivityStats()
            }
            .onReceive(timer) { _ in
                updateActiveApp()
                updateActivityStats()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                refreshPermissionStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: .keyPressed)) { notification in
                // Update last key pressed immediately for real-time display
                if let key = notification.userInfo?["key"] as? String,
                   let timestamp = notification.userInfo?["timestamp"] as? Date {
                    logger.info("📥 Notification received for key: '\(key)'")
                    lastKeyPressed = key
                    lastKeyTimestamp = timestamp
                    logger.info("🔄 UI updated with new key: '\(key)'")
                }
            }
        } detail: {
            if let app = activeApp, app.bundleId != "me.maxwin.Grind" {
                // Show iTerm2DetailView if the active app is iTerm2
                if app.bundleId.lowercased().contains("iterm") {
                    ITerm2DetailView(app: app)
                } else {
                    ActiveAppDetailView(app: app, allAppStats: appActivityStats, lastKeyPressed: lastKeyPressed)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "app.badge")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No active application")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func refreshPermissionStatus() {
        hasAccessibilityPermission = permissionManager.hasAccessibilityPermission()
    }

    private func requestAccessibilityPermission() {
        permissionManager.requestAccessibilityPermission()
    }

    private func updateActiveApp() {
        let newApp = appMonitor.getCurrentApp()
        if let key = newApp?.lastKeyPressed {
            logger.info("✅ Active app updated with key: '\(key)'")
        }

        // Notify iTerm2 service about app change for automatic monitoring
        if let bundleId = newApp?.bundleId {
            iterm2Service.handleAppChange(bundleId: bundleId)
        }

        activeApp = newApp
    }

    private func updateActivityStats() {
        do {
            appActivityStats = try heartbeatRepo.getAllAppActivityStats()
        } catch {
            print("Error fetching activity stats: \(error)")
        }
    }
}

struct AppRowView: View {
    let app: MacApp
    @ObservedObject var dataSharingPreferences: AppDataSharingPreferences

    private var selectionBinding: Binding<Bool> {
        Binding(
            get: { dataSharingPreferences.isAppSelected(bundleId: app.bundleIdentifier, appName: app.name) },
            set: { isSelected in
                dataSharingPreferences.setAppSelected(
                    bundleId: app.bundleIdentifier,
                    appName: app.name,
                    isSelected: isSelected
                )
            }
        )
    }

    var body: some View {
        Toggle(isOn: selectionBinding) {
            HStack(spacing: 8) {
                // App icon with running indicator
                ZStack(alignment: .bottomTrailing) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "app")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                    }

                    if app.isRunning {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )
                            .offset(x: 2, y: 2)
                    }
                }

                // App info
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 12))
                        .lineLimit(1)

                    HStack(spacing: 3) {
                        if let version = app.version {
                            Text("v\(version)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Text(app.bundleIdentifier)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 2)
        }
        .toggleStyle(.checkbox)
    }
}

struct ActiveAppDetailView: View {
    let app: AppInfo
    let allAppStats: [AppActivityStats]
    let lastKeyPressed: String

    var currentAppStats: AppActivityStats? {
        allAppStats.first { $0.bundleId == app.bundleId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Header
                VStack(spacing: 12) {
                    // App Icon
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .shadow(radius: 4)
                    } else {
                        Image(systemName: "app")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                    }

                    // App Name
                    Text(app.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    // Bundle Identifier
                    Text(app.bundleId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)

                    // Window Title
                    if let windowTitle = app.windowTitle, !windowTitle.isEmpty {
                        VStack(spacing: 4) {
                            Text("Current Window")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Text(windowTitle)
                                .font(.callout)
                                .multilineTextAlignment(.center)
                                .textSelection(.enabled)
                                .padding(.horizontal, 16)
                        }
                    }

                    // Last Key Pressed
                    if !lastKeyPressed.isEmpty {
                        VStack(spacing: 4) {
                            Text("Last Key Pressed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            HStack(spacing: 8) {
                                Image(systemName: "keyboard")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                Text(lastKeyPressed)
                                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 16)

                Divider()

                // Activity Statistics
                if let stats = currentAppStats {
                    VStack(spacing: 20) {
                        // Summary Stats
                        Text("Today's Activity")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Time and Sessions
                        HStack(spacing: 20) {
                            StatCard(
                                title: "Active Time",
                                value: stats.formattedActiveTime,
                                icon: "clock.fill",
                                color: .blue
                            )

                            StatCard(
                                title: "Sessions",
                                value: "\(stats.sessionCount)",
                                icon: "arrow.triangle.branch",
                                color: .green
                            )
                        }

                        // Activity Breakdown
                        Text("Activity Breakdown")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        VStack(spacing: 12) {
                            ActivityMetricRow(
                                icon: "keyboard.fill",
                                label: "Keystrokes",
                                count: stats.totalKeystrokes,
                                rate: String(format: "%.1f/min", stats.keystrokesPerMinute),
                                color: .purple
                            )

                            ActivityMetricRow(
                                icon: "arrow.up.and.down.and.arrow.left.and.right",
                                label: "Mouse Moves",
                                count: stats.totalMouseMovements,
                                rate: String(format: "%.1f/min", stats.mouseMovementsPerMinute),
                                color: .orange
                            )

                            ActivityMetricRow(
                                icon: "cursorarrow.click.2",
                                label: "Mouse Clicks",
                                count: stats.totalMouseClicks,
                                rate: String(format: "%.1f/min", stats.mouseClicksPerMinute),
                                color: .red
                            )
                        }

                        // Activity Intensity
                        VStack(spacing: 8) {
                            HStack {
                                Text("Activity Intensity")
                                    .font(.headline)
                                Spacer()
                                Text(stats.activityLevel.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(intensityColor(for: stats.activityLevel).opacity(0.2))
                                    .foregroundColor(intensityColor(for: stats.activityLevel))
                                    .cornerRadius(4)
                            }

                            Text("\(Int(stats.activityEventsPerMinute)) events/min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 8)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No activity recorded yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Activity will appear here once you start using this app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.vertical, 40)
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func intensityColor(for level: ActivityIntensity) -> Color {
        switch level {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .veryHigh: return .red
        }
    }
}

struct PermissionBanner: View {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let primaryAction: () -> Void
    let secondaryButtonTitle: String
    let secondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(title)
                    .font(.headline)
            }

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Button(primaryButtonTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)

                Button(secondaryButtonTitle, action: secondaryAction)
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(8)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ActivityMetricRow: View {
    let icon: String
    let label: String
    let count: Int
    let rate: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .frame(alignment: .leading)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 14, weight: .semibold))
                Text(rate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

#Preview {
    ContentView()
}
