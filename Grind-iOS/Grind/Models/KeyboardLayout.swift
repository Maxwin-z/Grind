//
//  KeyboardLayout.swift
//  Grind
//
//  75% keyboard layout model for visualization
//

import Foundation
import SwiftUI

// MARK: - Key Model

struct KeyboardKey: Identifiable, Equatable {
    let id = UUID()
    let label: String          // Display label (e.g., "A", "Esc", "⌘")
    let keyCode: String        // Internal key code for matching
    let width: CGFloat         // Relative width (1.0 = standard key)
    let keyType: KeyType

    enum KeyType {
        case character         // Regular letter/number keys
        case modifier          // Shift, Ctrl, Alt, Cmd, Fn
        case function          // F1-F12
        case navigation        // Arrow keys, Home, End, PgUp, PgDn
        case special           // Esc, Tab, Enter, Space, Delete, etc.
    }

    static func == (lhs: KeyboardKey, rhs: KeyboardKey) -> Bool {
        return lhs.keyCode == rhs.keyCode
    }
}

// MARK: - 75% Keyboard Layout

struct KeyboardLayout75 {
    // Row heights (relative)
    static let rowHeight: CGFloat = 1.0
    static let keySpacing: CGFloat = 0.08

    // Layout: 75% keyboard (84 keys)
    static let layout: [[KeyboardKey]] = [
        // Row 1: Number row (with Esc)
        [
            KeyboardKey(label: "Esc", keyCode: "Escape", width: 1.0, keyType: .special),
            KeyboardKey(label: "`", keyCode: "`", width: 1.0, keyType: .character),
            KeyboardKey(label: "1", keyCode: "1", width: 1.0, keyType: .character),
            KeyboardKey(label: "2", keyCode: "2", width: 1.0, keyType: .character),
            KeyboardKey(label: "3", keyCode: "3", width: 1.0, keyType: .character),
            KeyboardKey(label: "4", keyCode: "4", width: 1.0, keyType: .character),
            KeyboardKey(label: "5", keyCode: "5", width: 1.0, keyType: .character),
            KeyboardKey(label: "6", keyCode: "6", width: 1.0, keyType: .character),
            KeyboardKey(label: "7", keyCode: "7", width: 1.0, keyType: .character),
            KeyboardKey(label: "8", keyCode: "8", width: 1.0, keyType: .character),
            KeyboardKey(label: "9", keyCode: "9", width: 1.0, keyType: .character),
            KeyboardKey(label: "0", keyCode: "0", width: 1.0, keyType: .character),
            KeyboardKey(label: "-", keyCode: "-", width: 1.0, keyType: .character),
            KeyboardKey(label: "=", keyCode: "=", width: 1.0, keyType: .character),
            KeyboardKey(label: "⌫", keyCode: "Delete", width: 2.0, keyType: .special),
        ],

        // Row 2: QWERTY row
        [
            KeyboardKey(label: "Tab", keyCode: "Tab", width: 1.5, keyType: .special),
            KeyboardKey(label: "Q", keyCode: "Q", width: 1.0, keyType: .character),
            KeyboardKey(label: "W", keyCode: "W", width: 1.0, keyType: .character),
            KeyboardKey(label: "E", keyCode: "E", width: 1.0, keyType: .character),
            KeyboardKey(label: "R", keyCode: "R", width: 1.0, keyType: .character),
            KeyboardKey(label: "T", keyCode: "T", width: 1.0, keyType: .character),
            KeyboardKey(label: "Y", keyCode: "Y", width: 1.0, keyType: .character),
            KeyboardKey(label: "U", keyCode: "U", width: 1.0, keyType: .character),
            KeyboardKey(label: "I", keyCode: "I", width: 1.0, keyType: .character),
            KeyboardKey(label: "O", keyCode: "O", width: 1.0, keyType: .character),
            KeyboardKey(label: "P", keyCode: "P", width: 1.0, keyType: .character),
            KeyboardKey(label: "[", keyCode: "[", width: 1.0, keyType: .character),
            KeyboardKey(label: "]", keyCode: "]", width: 1.0, keyType: .character),
            KeyboardKey(label: "\\", keyCode: "\\", width: 1.5, keyType: .character),
            KeyboardKey(label: "PgU", keyCode: "Page Up", width: 1.0, keyType: .navigation),
        ],

        // Row 3: ASDF row
        [
            KeyboardKey(label: "Caps", keyCode: "Caps Lock", width: 1.75, keyType: .modifier),
            KeyboardKey(label: "A", keyCode: "A", width: 1.0, keyType: .character),
            KeyboardKey(label: "S", keyCode: "S", width: 1.0, keyType: .character),
            KeyboardKey(label: "D", keyCode: "D", width: 1.0, keyType: .character),
            KeyboardKey(label: "F", keyCode: "F", width: 1.0, keyType: .character),
            KeyboardKey(label: "G", keyCode: "G", width: 1.0, keyType: .character),
            KeyboardKey(label: "H", keyCode: "H", width: 1.0, keyType: .character),
            KeyboardKey(label: "J", keyCode: "J", width: 1.0, keyType: .character),
            KeyboardKey(label: "K", keyCode: "K", width: 1.0, keyType: .character),
            KeyboardKey(label: "L", keyCode: "L", width: 1.0, keyType: .character),
            KeyboardKey(label: ";", keyCode: ";", width: 1.0, keyType: .character),
            KeyboardKey(label: "'", keyCode: "'", width: 1.0, keyType: .character),
            KeyboardKey(label: "↵", keyCode: "Return", width: 2.25, keyType: .special),
            KeyboardKey(label: "PgD", keyCode: "Page Down", width: 1.0, keyType: .navigation),
        ],

        // Row 4: ZXCV row
        [
            KeyboardKey(label: "⇧", keyCode: "Shift", width: 2.25, keyType: .modifier),
            KeyboardKey(label: "Z", keyCode: "Z", width: 1.0, keyType: .character),
            KeyboardKey(label: "X", keyCode: "X", width: 1.0, keyType: .character),
            KeyboardKey(label: "C", keyCode: "C", width: 1.0, keyType: .character),
            KeyboardKey(label: "V", keyCode: "V", width: 1.0, keyType: .character),
            KeyboardKey(label: "B", keyCode: "B", width: 1.0, keyType: .character),
            KeyboardKey(label: "N", keyCode: "N", width: 1.0, keyType: .character),
            KeyboardKey(label: "M", keyCode: "M", width: 1.0, keyType: .character),
            KeyboardKey(label: ",", keyCode: ",", width: 1.0, keyType: .character),
            KeyboardKey(label: ".", keyCode: ".", width: 1.0, keyType: .character),
            KeyboardKey(label: "/", keyCode: "/", width: 1.0, keyType: .character),
            KeyboardKey(label: "⇧", keyCode: "RightShift", width: 1.75, keyType: .modifier),
            KeyboardKey(label: "↑", keyCode: "Up", width: 1.0, keyType: .navigation),
            KeyboardKey(label: "End", keyCode: "End", width: 1.0, keyType: .navigation),
        ],

        // Row 5: Bottom row
        [
            KeyboardKey(label: "Ctrl", keyCode: "Control", width: 1.25, keyType: .modifier),
            KeyboardKey(label: "⌥", keyCode: "Option", width: 1.25, keyType: .modifier),
            KeyboardKey(label: "⌘", keyCode: "Command", width: 1.25, keyType: .modifier),
            KeyboardKey(label: "", keyCode: "Space", width: 6.25, keyType: .special),
            KeyboardKey(label: "⌘", keyCode: "RightCommand", width: 1.25, keyType: .modifier),
            KeyboardKey(label: "Fn", keyCode: "Fn", width: 1.25, keyType: .modifier),
            KeyboardKey(label: "←", keyCode: "Left", width: 1.0, keyType: .navigation),
            KeyboardKey(label: "↓", keyCode: "Down", width: 1.0, keyType: .navigation),
            KeyboardKey(label: "→", keyCode: "Right", width: 1.0, keyType: .navigation),
        ],
    ]

    // Helper: Find key by keyCode
    static func findKey(byCode code: String) -> KeyboardKey? {
        for row in layout {
            if let key = row.first(where: { $0.keyCode == code }) {
                return key
            }
        }
        return nil
    }

    // Helper: Normalize key code for matching
    static func normalizeKeyCode(_ code: String) -> String {
        // Handle case-insensitive matching for letters
        let upper = code.uppercased()

        // Map common variations
        switch upper {
        case "LEFTSHIFT", "RIGHTSHIFT":
            return "Shift"
        case "LEFTCOMMAND", "RIGHTCOMMAND":
            return "Command"
        case "LEFTOPTION", "RIGHTOPTION":
            return "Option"
        case "LEFTCONTROL", "RIGHTCONTROL":
            return "Control"
        default:
            return code
        }
    }
}
