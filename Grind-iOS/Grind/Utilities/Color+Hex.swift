//
//  Color+Hex.swift
//  Grind
//
//  Lightweight helpers for constructing SwiftUI Colors from hex strings.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    init(hex: String, fallback: Color = .accentColor) {
        let sanitized = Color.sanitize(hex: hex)
        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
            self = fallback
            return
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self = Color(red: red, green: green, blue: blue)
    }

    private static func sanitize(hex: String) -> String {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    func boostedForCharts() -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }

        let boostedSaturation = min(1.0, saturation * 1.25 + 0.1)
        let boostedBrightness = min(1.0, max(brightness, 0.35) * 1.05)
        let boostedColor = UIColor(
            hue: hue,
            saturation: boostedSaturation,
            brightness: boostedBrightness,
            alpha: alpha
        )
        return Color(uiColor: boostedColor)
        #else
        return self
        #endif
    }
}
