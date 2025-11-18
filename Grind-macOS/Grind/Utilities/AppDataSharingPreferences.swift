//
//  AppDataSharingPreferences.swift
//  Grind
//
//  Persists which apps should be included when sharing data with clients.
//

import Foundation
import Combine
import AppKit

/// Stores whether an app's data should be shared with clients.
/// Default state is opt-in for every app until explicitly unchecked.
@MainActor
final class AppDataSharingPreferences: ObservableObject {
    static let shared = AppDataSharingPreferences()

    @Published private(set) var excludedBundleIds: Set<String>
    @Published private(set) var excludedAppNames: Set<String>
    @Published private(set) var knownApps: [String: AppSelectionMetadata] = [:] // bundleId -> metadata

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
            let action = isSelected ? "✅ Selected" : "❌ Deselected"
            print("\(action) app: \(appName ?? "Unknown") (\(bundleId ?? "no bundle ID"))")
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
        var changedApps: [String] = []
        for app in apps {
            if applySelectionChange(bundleId: app.bundleIdentifier, appName: app.name, isSelected: isSelected) {
                didChange = true
                changedApps.append(app.name)
            }
        }

        if didChange {
            let action = isSelected ? "✅ Selected" : "❌ Deselected"
            print("\(action) \(changedApps.count) apps: \(changedApps.prefix(5).joined(separator: ", "))\(changedApps.count > 5 ? "..." : "")")
            persistSelections()
            notifySelectionChanged()
        }
    }

    /// Update known apps so that selection snapshots include user-visible names.
    func updateKnownApps(_ apps: [MacApp]) {
        var updated = false
        for app in apps {
            let iconData = app.icon?.scaledPngData(maxDimension: 64)
            let colorHex = AppColorGenerator.colorHex(forBundleIdentifier: app.bundleIdentifier, appName: app.name)
            let metadata = AppSelectionMetadata(appName: app.name, iconData: iconData, accentColorHex: colorHex)

            if knownApps[app.bundleIdentifier] != metadata {
                knownApps[app.bundleIdentifier] = metadata
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
            .compactMap { bundleId, metadata in
                let appName = metadata.appName
                guard isAppSelected(bundleId: bundleId, appName: appName) else {
                    return nil
                }

                return AppSelectionInfo(
                    bundleIdentifier: bundleId,
                    appName: appName,
                    iconPNGData: metadata.iconData,
                    accentColorHex: metadata.accentColorHex
                )
            }
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    /// Snapshot current selection state for use off the main actor.
    func snapshot() -> AppDataSharingSnapshot {
        let selectedApps = selectedAppsList()
        let selectedBundleIds = Set(selectedApps.map { $0.bundleIdentifier })
        let selectedAppNames = Set(selectedApps.compactMap { normalized($0.appName) })

        return AppDataSharingSnapshot(
            selectedBundleIds: selectedBundleIds,
            selectedAppNames: selectedAppNames,
            apps: selectedApps
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
    let selectedBundleIds: Set<String>
    let selectedAppNames: Set<String>
    let apps: [AppSelectionInfo]

    static let empty = AppDataSharingSnapshot(selectedBundleIds: [], selectedAppNames: [], apps: [])

    func isAppSelected(bundleId: String?, appName: String?) -> Bool {
        guard !selectedBundleIds.isEmpty || !selectedAppNames.isEmpty || !apps.isEmpty else {
            return false
        }

        if let bundleId = bundleId, selectedBundleIds.contains(bundleId) {
            return true
        }

        if let normalizedName = normalized(appName), selectedAppNames.contains(normalizedName) {
            return true
        }

        return false
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
    let iconPNGData: Data?
    let accentColorHex: String
}

extension Notification.Name {
    static let appDataSharingSelectionChanged = Notification.Name("AppDataSharingPreferences.selectionChanged")
}

// MARK: - Selection Metadata Helpers

struct AppSelectionMetadata: Equatable {
    let appName: String
    let iconData: Data?
    let accentColorHex: String
}

struct AppColorGenerator {
    /// Fixed color palette for apps (8 distinct colors)
    /// Removed similar colors: 6600FF (similar to 715DF2), 0066FF (similar to 4FACF7),
    /// F7770F (similar to FCAF3C), FF0066 (similar to C62368)
    static let appColors = [
        "001122",  // 0: Dark blue-black
        "715DF2",  // 1: Purple
        "4FACF7",  // 2: Light blue
        "009473",  // 3: Teal green
        "F7CACA",  // 4: Light pink
        "FCAF3C",  // 5: Orange
        "FF6F61",  // 6: Coral red
        "C62368"   // 7: Magenta
    ]

    /// Pre-assigned colors for common apps to avoid conflicts
    /// Maps bundle ID to color index in appColors array
    /// Priority: ensure the 5 key apps (Claude, Code, Typora, Xcode, iTerm2) have unique colors
    private static let commonAppColors: [String: Int] = [
        // PRIORITY: User's 5 key apps - each gets unique color
        "com.anthropic.claudefordesktop": 0,  // #001122 - Dark blue-black
        "com.microsoft.VSCode": 1,            // #715DF2 - Purple
        "abnerworks.Typora": 2,               // #4FACF7 - Light blue
        "com.apple.dt.Xcode": 3,              // #009473 - Teal green
        "com.googlecode.iterm2": 4,           // #F7CACA - Light pink

        // Other development tools
        "com.jetbrains.intellij": 5,          // #FCAF3C - Orange
        "com.sublimetext.4": 6,               // #FF6F61 - Coral red

        // Terminals
        "com.apple.Terminal": 7,              // #C62368 - Magenta

        // Browsers
        "com.apple.Safari": 1,                // #715DF2 - Purple
        "com.google.Chrome": 5,               // #FCAF3C - Orange
        "org.mozilla.firefox": 7,             // #C62368 - Magenta
        "com.brave.Browser": 2,               // #4FACF7 - Light blue

        // Communication
        "com.tinyspeck.slackmacgap": 3,       // #009473 - Teal green
        "com.hnc.Discord": 0,                 // #001122 - Dark blue-black

        // Documentation
        "notion.id": 6,                       // #FF6F61 - Coral red
        "md.obsidian": 3,                     // #009473 - Teal green

        // Design
        "com.figma.Desktop": 4,               // #F7CACA - Light pink
        "com.bohemiancoding.sketch3": 2,      // #4FACF7 - Light blue
    ]

    static func colorHex(forBundleIdentifier bundleId: String, appName: String) -> String {
        let seed = bundleId.isEmpty ? appName : bundleId

        // Check if this is a common app with pre-assigned color
        if let colorIndex = commonAppColors[seed] {
            return "#" + appColors[colorIndex]
        }

        // Otherwise use hash-based assignment
        let index = stableColorIndex(for: seed)
        return "#" + appColors[index]
    }

    /// Generate a stable color index for a given seed string
    /// Uses a combination of multiple hash functions to ensure better distribution
    private static func stableColorIndex(for seed: String) -> Int {
        // Use multiple bytes from the seed to compute index
        // This provides better distribution across the color palette
        var hash: UInt64 = 0

        // FNV-1a hash
        var fnvHash: UInt64 = 14695981039346656037 // FNV offset basis
        for byte in seed.utf8 {
            fnvHash ^= UInt64(byte)
            fnvHash = fnvHash &* 1099511628211 // FNV prime
        }

        // DJB2 hash for additional mixing
        var djb2Hash: UInt64 = 5381
        for byte in seed.utf8 {
            djb2Hash = ((djb2Hash << 5) &+ djb2Hash) &+ UInt64(byte)
        }

        // Combine both hashes for better distribution
        hash = fnvHash ^ (djb2Hash << 32 | djb2Hash >> 32)

        // Use higher-order bits for better distribution with small modulo
        let mixedHash = (hash ^ (hash >> 16)) &* 0x85ebca6b
        let finalHash = (mixedHash ^ (mixedHash >> 13)) &* 0xc2b2ae35

        return Int((finalHash ^ (finalHash >> 16)) % UInt64(appColors.count))
    }
}

extension NSImage {
    /// Produce a square PNG representation scaled to the provided dimension for network transport.
    func scaledPngData(maxDimension: CGFloat) -> Data? {
        let targetSize = NSSize(width: maxDimension, height: maxDimension)
        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: targetSize).fill()

        let aspect = min(targetSize.width / size.width, targetSize.height / size.height)
        let newSize = NSSize(width: size.width * aspect, height: size.height * aspect)
        let drawRect = NSRect(
            x: (targetSize.width - newSize.width) / 2,
            y: (targetSize.height - newSize.height) / 2,
            width: newSize.width,
            height: newSize.height
        )

        draw(in: drawRect, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1.0)
        resizedImage.unlockFocus()

        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}
