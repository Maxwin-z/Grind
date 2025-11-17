//
//  AppDataSharingPreferences.swift
//  Grind
//
//  Persists which apps should be included when sharing data with clients.
//

import Foundation
import Combine

/// Stores whether an app's data should be shared with clients.
/// Default state is opt-in for every app until explicitly unchecked.
@MainActor
final class AppDataSharingPreferences: ObservableObject {
    static let shared = AppDataSharingPreferences()

    @Published private(set) var excludedBundleIds: Set<String>
    @Published private(set) var excludedAppNames: Set<String>
    @Published private(set) var knownApps: [String: String] = [:] // bundleId -> name

    private let defaults = UserDefaults.standard
    private let excludedBundleIdsKey = "AppDataSharingPreferences.excludedBundleIds"
    private let excludedAppNamesKey = "AppDataSharingPreferences.excludedAppNames"

    private init() {
        if let savedBundleIds = defaults.array(forKey: excludedBundleIdsKey) as? [String] {
            excludedBundleIds = Set(savedBundleIds)
        } else {
            excludedBundleIds = []
        }

        if let savedAppNames = defaults.array(forKey: excludedAppNamesKey) as? [String] {
            excludedAppNames = Set(savedAppNames)
        } else {
            excludedAppNames = []
        }
    }

    /// Whether the given app should have its data shared.
    func isAppSelected(bundleId: String?, appName: String?) -> Bool {
        if let bundleId = bundleId, excludedBundleIds.contains(bundleId) {
            return false
        }

        if let normalizedName = normalized(appName), excludedAppNames.contains(normalizedName) {
            return false
        }

        return true
    }

    /// Set whether an app should be included in outbound data.
    func setAppSelected(bundleId: String?, appName: String?, isSelected: Bool) {
        let changed = applySelectionChange(bundleId: bundleId, appName: appName, isSelected: isSelected)
        if changed {
            persistSelections()
            notifySelectionChanged()
        }
    }

    /// Convenience helper for toggling via a MacApp instance.
    func toggleSelection(for app: MacApp) {
        let currentlySelected = isAppSelected(bundleId: app.bundleIdentifier, appName: app.name)
        setAppSelected(bundleId: app.bundleIdentifier, appName: app.name, isSelected: !currentlySelected)
    }

    /// Update selection state for a batch of apps.
    func setApps(_ apps: [MacApp], isSelected: Bool) {
        var didChange = false
        for app in apps {
            if applySelectionChange(bundleId: app.bundleIdentifier, appName: app.name, isSelected: isSelected) {
                didChange = true
            }
        }

        if didChange {
            persistSelections()
            notifySelectionChanged()
        }
    }

    /// Update known apps so that selection snapshots include user-visible names.
    func updateKnownApps(_ apps: [MacApp]) {
        var updated = false
        for app in apps {
            if knownApps[app.bundleIdentifier] != app.name {
                knownApps[app.bundleIdentifier] = app.name
                updated = true
            }
        }

        if updated {
            notifySelectionChanged()
        }
    }

    /// Snapshot of currently selected apps with display names.
    func selectedAppsList() -> [AppSelectionInfo] {
        return knownApps
            .compactMap { bundleId, appName in
                guard isAppSelected(bundleId: bundleId, appName: appName) else {
                    return nil
                }

                return AppSelectionInfo(bundleIdentifier: bundleId, appName: appName)
            }
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    /// Snapshot current selection state for use off the main actor.
    func snapshot() -> AppDataSharingSnapshot {
        AppDataSharingSnapshot(
            excludedBundleIds: excludedBundleIds,
            excludedAppNames: excludedAppNames
        )
    }

    // MARK: - Persistence

    private func persistSelections() {
        defaults.set(Array(excludedBundleIds), forKey: excludedBundleIdsKey)
        defaults.set(Array(excludedAppNames), forKey: excludedAppNamesKey)
    }

    @discardableResult
    private func applySelectionChange(bundleId: String?, appName: String?, isSelected: Bool) -> Bool {
        var didChange = false

        if let bundleId = bundleId {
            if update(set: &excludedBundleIds, value: bundleId, shouldContain: !isSelected) {
                didChange = true
            }
        }

        if let normalizedName = normalized(appName) {
            if update(set: &excludedAppNames, value: normalizedName, shouldContain: !isSelected) {
                didChange = true
            }
        }

        return didChange
    }

    @discardableResult
    private func update(set: inout Set<String>, value: String, shouldContain: Bool) -> Bool {
        if shouldContain {
            if set.contains(value) {
                return false
            }
            set.insert(value)
            return true
        } else {
            return set.remove(value) != nil
        }
    }

    private func normalized(_ appName: String?) -> String? {
        guard let name = appName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }
        return name
    }

    private func notifySelectionChanged() {
        NotificationCenter.default.post(name: .appDataSharingSelectionChanged, object: nil)
    }
}

/// Immutable snapshot of the app sharing preferences for off-main-thread consumers.
struct AppDataSharingSnapshot {
    let excludedBundleIds: Set<String>
    let excludedAppNames: Set<String>

    func isAppSelected(bundleId: String?, appName: String?) -> Bool {
        if let bundleId = bundleId, excludedBundleIds.contains(bundleId) {
            return false
        }

        if let normalizedName = normalized(appName), excludedAppNames.contains(normalizedName) {
            return false
        }

        return true
    }

    private func normalized(_ appName: String?) -> String? {
        guard let name = appName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }
        return name
    }
}

/// Information about a selected application for broadcasting to clients.
struct AppSelectionInfo: Hashable {
    let bundleIdentifier: String
    let appName: String
}

extension Notification.Name {
    static let appDataSharingSelectionChanged = Notification.Name("AppDataSharingPreferences.selectionChanged")
}
