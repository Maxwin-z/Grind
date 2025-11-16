//
//  AppMonitor.swift
//  Grind
//
//  Monitors active application and window information
//  Implements PRD FR-001 application monitoring
//

import Foundation
import AppKit
import CoreGraphics

/// Monitors the active foreground application
/// Polls every 2 seconds per PRD FR-001
class AppMonitor {
    static let shared = AppMonitor()

    private(set) var currentApp: AppInfo?
    private let categoryRepository = AppCategoryRepository()

    // Callbacks
    var onAppChanged: ((AppInfo, AppInfo?) -> Void)?  // (newApp, oldApp)

    private init() {}

    // MARK: - Application Detection

    /// Get currently active application
    func getCurrentApp() -> AppInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        var appInfo = AppInfo(runningApp: app)

        // Get the last key pressed from KeystrokeCounter
        let lastKey = KeystrokeCounter.shared.lastKeyPressed.isEmpty ? nil : KeystrokeCounter.shared.lastKeyPressed

        // Try to get window title
        if let windowTitle = getActiveWindowTitle(for: app.processIdentifier) {
            appInfo = AppInfo(
                name: appInfo?.name ?? "Unknown",
                bundleId: appInfo?.bundleId ?? "unknown",
                windowTitle: windowTitle,
                processId: app.processIdentifier,
                icon: app.icon,
                lastKeyPressed: lastKey
            )
        } else {
            // Update with last key pressed even if no window title
            appInfo = AppInfo(
                name: appInfo?.name ?? "Unknown",
                bundleId: appInfo?.bundleId ?? "unknown",
                windowTitle: appInfo?.windowTitle,
                processId: app.processIdentifier,
                icon: app.icon,
                lastKeyPressed: lastKey
            )
        }

        return appInfo
    }

    /// Get window title for active window of process
    private func getActiveWindowTitle(for processId: pid_t) -> String? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for window in windows {
            guard let windowPid = window[kCGWindowOwnerPID as String] as? pid_t,
                  windowPid == processId,
                  let windowTitle = window[kCGWindowName as String] as? String,
                  !windowTitle.isEmpty else {
                continue
            }

            return windowTitle
        }

        return nil
    }

    /// Update current app and notify if changed
    @discardableResult
    func updateCurrentApp() -> AppInfo? {
        let newApp = getCurrentApp()

        // Check if app changed
        if let new = newApp, new != currentApp {
            let old = currentApp
            currentApp = new
            onAppChanged?(new, old)
        }

        return newApp
    }

    // MARK: - App Classification

    /// Get category for current app
    func getCategoryForCurrentApp() -> String {
        guard let app = currentApp else { return "Other" }
        return getCategoryFor(bundleId: app.bundleId)
    }

    /// Get category for bundle ID
    func getCategoryFor(bundleId: String) -> String {
        do {
            let category = try categoryRepository.getCategory(forBundleId: bundleId)
            return category.category
        } catch {
            print("⚠️  Error getting category for \(bundleId): \(error)")
            return "Other"
        }
    }

    /// Check if current app is a code editor
    func isCurrentAppCodeEditor() -> Bool {
        guard let app = currentApp else { return false }
        return isCodeEditor(bundleId: app.bundleId)
    }

    /// Check if bundle ID is a code editor
    func isCodeEditor(bundleId: String) -> Bool {
        do {
            let category = try categoryRepository.getCategory(forBundleId: bundleId)
            return category.isCodeEditor
        } catch {
            return false
        }
    }

    /// Check if current app is a terminal
    func isCurrentAppTerminal() -> Bool {
        guard let app = currentApp else { return false }
        return isTerminal(bundleId: app.bundleId)
    }

    /// Check if bundle ID is a terminal
    func isTerminal(bundleId: String) -> Bool {
        do {
            let category = try categoryRepository.getCategory(forBundleId: bundleId)
            return category.isTerminal
        } catch {
            return false
        }
    }

    // MARK: - Project Detection

    /// Extract project name from window title
    /// Implements basic project detection from PRD FR-014
    func extractProjectName(from windowTitle: String?) -> String? {
        guard let title = windowTitle else { return nil }

        // Pattern 1: "filename.ext - ProjectName - AppName"
        if let match = title.range(of: #" - ([^-]+) - "#, options: .regularExpression) {
            let projectName = String(title[match]).trimmingCharacters(in: .whitespaces)
            return projectName.replacingOccurrences(of: " - ", with: "")
        }

        // Pattern 2: "~/Code/project-name/path"
        if title.contains("~/") || title.hasPrefix("/Users/") {
            let components = title.components(separatedBy: "/")
            // Look for directory after "Code", "Projects", or "Development"
            for (index, component) in components.enumerated() {
                if ["Code", "Projects", "Development", "Workspace"].contains(component),
                   index + 1 < components.count {
                    return components[index + 1]
                }
            }
        }

        // Pattern 3: Git branch indication "[branch] path"
        if let match = title.range(of: #"\[[\w-]+\] [~/].*?/([\w-]+)"#, options: .regularExpression) {
            let matched = String(title[match])
            let pathComponents = matched.components(separatedBy: "/")
            if let projectName = pathComponents.last?.trimmingCharacters(in: .whitespaces) {
                return projectName
            }
        }

        return nil
    }
}

// MARK: - Running Applications

extension AppMonitor {
    /// Get list of all running applications
    func getAllRunningApps() -> [AppInfo] {
        return NSWorkspace.shared.runningApplications.compactMap { app in
            AppInfo(runningApp: app)
        }
    }

    /// Get running apps by category
    func getRunningApps(byCategory category: String) -> [AppInfo] {
        return getAllRunningApps().filter { app in
            getCategoryFor(bundleId: app.bundleId) == category
        }
    }
}
