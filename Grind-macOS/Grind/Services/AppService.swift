//
//  AppService.swift
//  Grind
//
//  Created by Maxwin on 2025/11/16.
//

import Foundation
import AppKit
import Combine

@MainActor
class AppService: ObservableObject {
    @Published var applications: [MacApp] = []
    @Published var isLoading: Bool = false

    func fetchApplications() async {
        isLoading = true
        defer { isLoading = false }

        var apps: [MacApp] = []

        // Get running applications
        let runningApps = NSWorkspace.shared.runningApplications
        let runningBundleIdentifiers = Set(runningApps.compactMap { $0.bundleIdentifier })

        // Common application directories
        let applicationPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications").path
        ]

        for path in applicationPaths {
            let appURLs = getApplicationURLs(from: path)
            for url in appURLs {
                if let app = createMacApp(from: url, runningBundleIds: runningBundleIdentifiers) {
                    apps.append(app)
                }
            }
        }

        // Remove duplicates and sort: running apps first, then by name
        let uniqueApps = Array(Set(apps)).sorted { lhs, rhs in
            if lhs.isRunning != rhs.isRunning {
                return lhs.isRunning
            }
            return lhs.name < rhs.name
        }
        applications = uniqueApps
    }

    private func getApplicationURLs(from path: String) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var appURLs: [URL] = []

        for case let fileURL as URL in enumerator {
            // Check if it's an application
            if fileURL.pathExtension == "app" {
                appURLs.append(fileURL)
                // Skip contents of .app bundles
                enumerator.skipDescendants()
            }
        }

        return appURLs
    }

    private func createMacApp(from url: URL, runningBundleIds: Set<String>) -> MacApp? {
        guard let bundle = Bundle(url: url) else { return nil }

        let name = bundle.infoDictionary?["CFBundleName"] as? String
            ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
            ?? url.deletingPathExtension().lastPathComponent

        let bundleIdentifier = bundle.bundleIdentifier ?? url.path
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String

        // Check if app is currently running
        let isRunning = bundle.bundleIdentifier != nil && runningBundleIds.contains(bundle.bundleIdentifier!)

        // Get app icon
        var icon: NSImage?
        if let iconName = bundle.infoDictionary?["CFBundleIconFile"] as? String {
            icon = bundle.image(forResource: iconName)
        }

        // Fallback to workspace icon
        if icon == nil {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        }

        return MacApp(
            name: name,
            bundleIdentifier: bundleIdentifier,
            path: url,
            icon: icon,
            version: version,
            isRunning: isRunning
        )
    }
}
