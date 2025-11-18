//
//  ContentView.swift
//  Grind
//
//  Created by Maxwin on 2025/11/16.
//

import SwiftUI
import Combine
import AppKit

final class StatusBarMenuController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var isActive = false
    private let appSelectionWindow = AppSelectionWindow()

    func activate() {
        guard !isActive else { return }
        isActive = true
        setupStatusItem()
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.stack.fill.badge.person.crop", accessibilityDescription: "Grind")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let selectAppsItem = NSMenuItem(title: "选择App", action: #selector(showSelectionWindow), keyEquivalent: "")
        selectAppsItem.target = self
        menu.addItem(selectAppsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    @objc private func showSelectionWindow() {
        appSelectionWindow.showWindow()
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    deinit {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}

final class AppSelectionWindow: NSObject, NSWindowDelegate {
    private var windowController: NSWindowController?

    func showWindow() {
        if windowController == nil {
            let hostingController = NSHostingController(rootView: AppSelectionView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "选择 App"
            window.setContentSize(NSSize(width: 420, height: 600))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.center()
            window.delegate = self
            windowController = NSWindowController(window: window)
        }

        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        windowController = nil
    }
}

struct AppSelectionView: View {
    @StateObject private var appService = AppService()
    @StateObject private var dataSharingPreferences = AppDataSharingPreferences.shared
    @State private var searchText = ""
    @State private var hasAccessibilityPermission = PermissionManager.shared.hasAccessibilityPermission()

    private let permissionManager = PermissionManager.shared

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

        return apps.sorted { lhs, rhs in
            let lhsIsGrind = lhs.bundleIdentifier == "me.maxwin.Grind"
            let rhsIsGrind = rhs.bundleIdentifier == "me.maxwin.Grind"

            if lhsIsGrind != rhsIsGrind {
                return lhsIsGrind
            }

            if lhs.isRunning != rhs.isRunning {
                return lhs.isRunning
            }

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

                    HStack(spacing: 10) {
                        Button(action: selectAllFilteredApps) {
                            Label("Select All", systemImage: "checkmark.circle")
                                .font(.caption)
                        }
                        Button(action: deselectAllFilteredApps) {
                            Label("Deselect All", systemImage: "xmark.circle")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 420, minHeight: 560)
        .task {
            refreshPermissionStatus()
            await appService.fetchApplications()
            dataSharingPreferences.updateKnownApps(appService.applications)
        }
        .onReceive(appService.$applications) { apps in
            dataSharingPreferences.updateKnownApps(apps)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionStatus()
        }
    }

    private func refreshPermissionStatus() {
        hasAccessibilityPermission = permissionManager.hasAccessibilityPermission()
    }

    private func requestAccessibilityPermission() {
        permissionManager.requestAccessibilityPermission()
    }

    private func selectAllFilteredApps() {
        dataSharingPreferences.setApps(filteredApps, isSelected: true)
    }

    private func deselectAllFilteredApps() {
        dataSharingPreferences.setApps(filteredApps, isSelected: false)
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

#Preview {
    AppSelectionView()
}
