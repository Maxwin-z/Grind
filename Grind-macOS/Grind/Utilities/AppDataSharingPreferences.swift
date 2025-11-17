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
    static func colorHex(forBundleIdentifier bundleId: String, appName: String) -> String {
        let seed = bundleId.isEmpty ? appName : bundleId
        let hash = stableHash(for: seed)

        let hue = Double(hash % 360) / 360.0
        let saturation = 0.55 + Double((hash >> 8) % 30) / 100.0
        let brightness = 0.65 + Double((hash >> 16) % 25) / 100.0

        let rgb = hsbToRGB(hue: hue, saturation: min(max(saturation, 0.45), 0.85), brightness: min(max(brightness, 0.55), 0.95))
        return String(format: "#%02X%02X%02X", Int(rgb.r * 255), Int(rgb.g * 255), Int(rgb.b * 255))
    }

    private static func stableHash(for string: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603 // FNV offset basis
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }

    private static func hsbToRGB(hue: Double, saturation: Double, brightness: Double) -> (r: Double, g: Double, b: Double) {
        let c = brightness * saturation
        let x = c * (1 - abs((hue * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c

        let (r1, g1, b1): (Double, Double, Double)
        switch hue * 6 {
        case 0..<1:
            (r1, g1, b1) = (c, x, 0)
        case 1..<2:
            (r1, g1, b1) = (x, c, 0)
        case 2..<3:
            (r1, g1, b1) = (0, c, x)
        case 3..<4:
            (r1, g1, b1) = (0, x, c)
        case 4..<5:
            (r1, g1, b1) = (x, 0, c)
        default:
            (r1, g1, b1) = (c, 0, x)
        }

        return (r1 + m, g1 + m, b1 + m)
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
