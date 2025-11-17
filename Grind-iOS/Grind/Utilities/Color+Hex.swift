//
//  Color+Hex.swift
//  Grind
//
//  Lightweight helpers for constructing SwiftUI Colors from hex strings.
//

import SwiftUI

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
}
