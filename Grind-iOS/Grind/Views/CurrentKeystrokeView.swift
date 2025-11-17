//
//  CurrentKeystrokeView.swift
//  Grind
//
//  Real-time keystroke display with modifier icons
//

import SwiftUI

struct CurrentKeystrokeView: View {
    let key: String
    let modifiers: [String]

    var body: some View {
        HStack(spacing: 8) {
            // Display modifiers with icons
            ForEach(modifiers, id: \.self) { modifier in
                ModifierKeyView(modifier: modifier)
            }

            // Display the main key
            if !key.isEmpty {
                KeyView(key: key)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ModifierKeyView: View {
    let modifier: String

    var body: some View {
        HStack(spacing: 4) {
            if let icon = modifierIcon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(modifierSymbol)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
        .cornerRadius(6)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private var modifierIcon: String? {
        switch modifier {
        case "Command":
            return "command"
        case "Shift":
            return "shift"
        case "Option":
            return "option"
        case "Control":
            return "control"
        case "Fn":
            return nil  // No SF Symbol for Fn
        default:
            return nil
        }
    }

    private var modifierSymbol: String {
        switch modifier {
        case "Command":
            return "⌘"
        case "Shift":
            return "⇧"
        case "Option":
            return "⌥"
        case "Control":
            return "⌃"
        case "Fn":
            return "fn"
        default:
            return modifier
        }
    }
}

struct KeyView: View {
    let key: String

    var body: some View {
        HStack(spacing: 4) {
            if let icon = specialKeyIcon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(displayKey)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
        .cornerRadius(6)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private var specialKeyIcon: String? {
        switch key {
        case "Return":
            return "return"
        case "Tab":
            return "arrow.right.to.line"
        case "Space":
            return "space"
        case "Delete":
            return "delete.left"
        case "Escape":
            return "escape"
        case "Left":
            return "arrow.left"
        case "Right":
            return "arrow.right"
        case "Up":
            return "arrow.up"
        case "Down":
            return "arrow.down"
        case "Forward Delete":
            return "delete.forward"
        case "Home":
            return "arrow.up.to.line"
        case "End":
            return "arrow.down.to.line"
        case "Page Up":
            return "arrow.up.doc"
        case "Page Down":
            return "arrow.down.doc"
        default:
            if key.hasPrefix("F") && key.count <= 3 {
                // F1-F12 keys
                return nil
            }
            return nil
        }
    }

    private var displayKey: String {
        switch key {
        case "Return":
            return "↵"
        case "Tab":
            return "⇥"
        case "Space":
            return "␣"
        case "Delete":
            return "⌫"
        case "Escape":
            return "⎋"
        case "Left":
            return "←"
        case "Right":
            return "→"
        case "Up":
            return "↑"
        case "Down":
            return "↓"
        case "Forward Delete":
            return "⌦"
        case "Home":
            return "↖"
        case "End":
            return "↘"
        case "Page Up":
            return "⇞"
        case "Page Down":
            return "⇟"
        default:
            return key
        }
    }
}

#if DEBUG
struct CurrentKeystrokeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Simple key
            CurrentKeystrokeView(key: "A", modifiers: [])

            // Command + C
            CurrentKeystrokeView(key: "C", modifiers: ["Command"])

            // Shift + Command + S
            CurrentKeystrokeView(key: "S", modifiers: ["Shift", "Command"])

            // Control + Option + Delete
            CurrentKeystrokeView(key: "Delete", modifiers: ["Control", "Option"])

            // Special key with modifiers
            CurrentKeystrokeView(key: "Return", modifiers: ["Shift"])

            // Arrow key
            CurrentKeystrokeView(key: "Left", modifiers: ["Option"])
        }
        .padding()
    }
}
#endif
