//
//  AppColorProvider.swift
//  Grind
//
//  Centralizes color/icon lookups for app-specific visuals.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AppColorProvider {
    let appMetadata: [String: SelectedAppData]

    func color(for appName: String) -> Color {
        if let metadata = metadata(for: appName) {
            return Color(hex: metadata.accentColorHex, fallback: fallbackColor(for: appName)).boostedForCharts()
        }
        return fallbackColor(for: appName).boostedForCharts()
    }

    func gradient(for appName: String) -> LinearGradient {
        let color = color(for: appName)
        return LinearGradient(
            colors: [color.opacity(0.9), color.opacity(0.55)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    #if canImport(UIKit)
    func icon(for appName: String) -> UIImage? {
        guard let data = metadata(for: appName)?.iconPNGData else {
            return nil
        }
        return UIImage(data: data)
    }
    #endif

    private func metadata(for appName: String) -> SelectedAppData? {
        if let direct = appMetadata[appName] {
            return direct
        }
        return appMetadata.first { $0.key.caseInsensitiveCompare(appName) == .orderedSame }?.value
    }

    private func fallbackColor(for appName: String) -> Color {
        let hash = abs(appName.hashValue)
        return Self.fallbackPalette[hash % Self.fallbackPalette.count]
    }

    private static let fallbackPalette: [Color] = [
        Color(red: 0.95, green: 0.35, blue: 0.2),
        Color(red: 0.95, green: 0.55, blue: 0.15),
        Color(red: 0.2, green: 0.6, blue: 0.95),
        Color(red: 0.3, green: 0.75, blue: 0.4),
        Color(red: 0.7, green: 0.4, blue: 0.9),
        Color(red: 1.0, green: 0.2, blue: 0.5),
        Color(red: 0.2, green: 0.85, blue: 0.7),
        Color(red: 0.98, green: 0.6, blue: 0.2),
        Color(red: 0.4, green: 0.5, blue: 0.95),
        Color(red: 0.25, green: 0.9, blue: 0.5)
    ]
}
