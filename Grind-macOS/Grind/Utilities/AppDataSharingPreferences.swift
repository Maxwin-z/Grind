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
        if let bundleId = bundleId {
            update(set: &excludedBundleIds, value: bundleId, shouldContain: !isSelected)
        }

        if let normalizedName = normalized(appName) {
            update(set: &excludedAppNames, value: normalizedName, shouldContain: !isSelected)
        }

        persistSelections()
    }

    /// Convenience helper for toggling via a MacApp instance.
    func toggleSelection(for app: MacApp) {
        let currentlySelected = isAppSelected(bundleId: app.bundleIdentifier, appName: app.name)
        setAppSelected(bundleId: app.bundleIdentifier, appName: app.name, isSelected: !currentlySelected)
    }

    /// Update selection state for a batch of apps.
    func setApps(_ apps: [MacApp], isSelected: Bool) {
        apps.forEach { app in
            setAppSelected(bundleId: app.bundleIdentifier, appName: app.name, isSelected: isSelected)
        }
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

    private func update(set: inout Set<String>, value: String, shouldContain: Bool) {
        if shouldContain {
            set.insert(value)
        } else {
            set.remove(value)
        }
    }

    private func normalized(_ appName: String?) -> String? {
        guard let name = appName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }
        return name
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
