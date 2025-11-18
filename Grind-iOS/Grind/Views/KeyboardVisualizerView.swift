//
//  KeyboardVisualizerView.swift
//  Grind
//
//  75% keyboard visualization with real-time key press animation
//

import SwiftUI

struct KeyboardVisualizerView: View {
    static let preferredHeight: CGFloat = 200

    let currentKey: String
    let currentModifiers: [String]
    let keystrokeSequence: UInt64

    @State private var pressedKeys: Set<String> = []
    @State private var animatingKeys: [String: Double] = [:]  // keyCode -> opacity
    @State private var cleanupTasks: [String: DispatchWorkItem] = [:]

    private let baseKeySize: CGFloat = 28  // Base size for 1.0 width key
    private let cornerRadius: CGFloat = 4
    private let shadowRadius: CGFloat = 2
    private let keyHighlightDuration: TimeInterval = 3.0

    var body: some View {
        let _ = print("🎨 KeyboardVisualizer body re-render - currentKey: '\(currentKey)', modifiers: \(currentModifiers)")
        VStack(spacing: KeyboardLayout75.keySpacing * baseKeySize) {
            ForEach(Array(KeyboardLayout75.layout.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: KeyboardLayout75.keySpacing * baseKeySize) {
                    ForEach(row) { key in
                        KeyCapView(
                            key: key,
                            isPressed: pressedKeys.contains(key.keyCode),
                            opacity: animatingKeys[key.keyCode] ?? 0.0,
                            baseSize: baseKeySize,
                            cornerRadius: cornerRadius,
                            shadowRadius: shadowRadius
                        )
                    }
                }
            }
        }
        .padding(16)
        .onChange(of: keystrokeSequence) { oldValue, newValue in
            print("🔄 onChange(keystrokeSequence) triggered: \(newValue)")
            handleKeyPress(key: currentKey, modifiers: currentModifiers)
        }
        .onAppear {
            print("👀 KeyboardVisualizer onAppear - initial key: '\(currentKey)', modifiers: \(currentModifiers)")
            if !currentKey.isEmpty || !currentModifiers.isEmpty {
                handleKeyPress(key: currentKey, modifiers: currentModifiers)
            }
        }
        .onDisappear {
            cancelAllCleanupTasks()
        }
    }

    // MARK: - Key Press Handling

    private func handleKeyPress(key: String, modifiers: [String]) {
        print("🎹 KeyboardVisualizer handleKeyPress - key: '\(key)', modifiers: \(modifiers)")

        // Clear previous state
        pressedKeys.removeAll()

        guard !key.isEmpty || !modifiers.isEmpty else {
            print("   ⚠️ No key or modifiers to animate, skipping.")
            return
        }

        var keysToAnimate: [String] = []

        // Add modifiers
        for modifier in modifiers {
            let normalizedModifier = normalizeModifier(modifier)
            print("   🔧 Normalized modifier '\(modifier)' -> '\(normalizedModifier)'")

            // Check if this key exists in layout
            let found = KeyboardLayout75.layout.flatMap { $0 }.first { $0.keyCode == normalizedModifier }
            print("      Key found in layout: \(found != nil) (keyCode: '\(normalizedModifier)')")

            keysToAnimate.append(normalizedModifier)
        }

        // Add main key (if not empty and not "Special")
        if !key.isEmpty && key != "Special" {
            let normalizedKey = normalizeKey(key)
            print("   🔧 Normalized key '\(key)' -> '\(normalizedKey)'")

            // Check if this key exists in layout
            let found = KeyboardLayout75.layout.flatMap { $0 }.first { $0.keyCode == normalizedKey }
            print("      Key found in layout: \(found != nil) (keyCode: '\(normalizedKey)')")

            keysToAnimate.append(normalizedKey)
        }

        print("   ✅ Keys to animate: \(keysToAnimate)")
        print("   📊 Current animatingKeys state: \(animatingKeys)")

        // Trigger animation for all keys
        for keyCode in keysToAnimate {
            pressedKeys.insert(keyCode)
            animateKeyPress(keyCode: keyCode)
        }

        print("   📊 After animation animatingKeys state: \(animatingKeys)")
    }

    private func animateKeyPress(keyCode: String) {
        print("   🎬 Animating key: '\(keyCode)'")
        animatingKeys[keyCode] = 1.0
        print("      Highlight opacity set to \(animatingKeys[keyCode] ?? 0)")

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: keyHighlightDuration)) {
                animatingKeys[keyCode] = 0.0
                print("      Target opacity: 0.0 over \(keyHighlightDuration)s")
            }
        }

        scheduleCleanup(for: keyCode)
    }

    // MARK: - Key Normalization

    private func normalizeModifier(_ modifier: String) -> String {
        switch modifier {
        case "Command":
            return "Command"
        case "Shift":
            return "Shift"
        case "Option":
            return "Option"
        case "Control":
            return "Control"
        case "Fn":
            return "Fn"
        default:
            return modifier
        }
    }

    private func normalizeKey(_ key: String) -> String {
        // Normalize key to match KeyboardLayout keyCode
        // Handle uppercase letters
        if key.count == 1 && key.first?.isLetter == true {
            return key.uppercased()
        }

        // Handle special keys
        switch key {
        case "Return":
            return "Return"
        case "Tab":
            return "Tab"
        case "Space":
            return "Space"
        case "Delete":
            return "Delete"
        case "Escape":
            return "Escape"
        case "Left":
            return "Left"
        case "Right":
            return "Right"
        case "Up":
            return "Up"
        case "Down":
            return "Down"
        case "Forward Delete":
            return "Forward Delete"
        case "Home":
            return "Home"
        case "End":
            return "End"
        case "Page Up":
            return "Page Up"
        case "Page Down":
            return "Page Down"
        case "Caps Lock":
            return "Caps Lock"
        default:
            // For F-keys and other special keys
            if key.hasPrefix("F") && key.count <= 3 {
                return key
            }
            return key
        }
    }

    // MARK: - Animation Cleanup

    private func scheduleCleanup(for keyCode: String) {
        cleanupTasks[keyCode]?.cancel()

        let workItem = DispatchWorkItem {
            pressedKeys.remove(keyCode)
            animatingKeys.removeValue(forKey: keyCode)
            cleanupTasks.removeValue(forKey: keyCode)
            print("      Animation complete for '\(keyCode)'")
        }

        cleanupTasks[keyCode] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + keyHighlightDuration, execute: workItem)
    }

    private func cancelAllCleanupTasks() {
        cleanupTasks.values.forEach { $0.cancel() }
        cleanupTasks.removeAll()
    }
}

// MARK: - Key Cap View

struct KeyCapView: View {
    let key: KeyboardKey
    let isPressed: Bool
    let opacity: Double
    let baseSize: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat

    private var keyWidth: CGFloat {
        return key.width * baseSize
    }

    private var keyHeight: CGFloat {
        return baseSize
    }

    var body: some View {
        ZStack {
            // Base key background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(baseColor)
                .frame(width: keyWidth, height: keyHeight)
                .shadow(color: Color.black.opacity(0.15), radius: shadowRadius, x: 0, y: 1)

            // Highlight overlay (animated)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(highlightColor)
                .frame(width: keyWidth, height: keyHeight)
                .opacity(opacity)

            // Key label
            Text(key.label)
                .font(labelFont)
                .foregroundColor(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: keyWidth, height: keyHeight)
    }

    // MARK: - Styling

    private var baseColor: Color {
        switch key.keyType {
        case .character:
            return Color(.systemGray5)
        case .modifier:
            return Color(.systemGray4)
        case .function:
            return Color(.systemGray6)
        case .navigation:
            return Color(.systemGray4)
        case .special:
            return Color(.systemGray4)
        }
    }

    private var highlightColor: Color {
        switch key.keyType {
        case .character:
            return Color.blue.opacity(0.6)
        case .modifier:
            return Color.orange.opacity(0.6)
        case .function:
            return Color.purple.opacity(0.6)
        case .navigation:
            return Color.green.opacity(0.6)
        case .special:
            return Color.cyan.opacity(0.6)
        }
    }

    private var labelColor: Color {
        return Color.primary.opacity(0.8)
    }

    private var labelFont: Font {
        // Adjust font size based on key width
        if key.width >= 2.0 {
            return .system(size: 11, weight: .medium, design: .rounded)
        } else if key.label.count > 3 {
            return .system(size: 9, weight: .medium, design: .rounded)
        } else {
            return .system(size: 12, weight: .semibold, design: .rounded)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct KeyboardVisualizerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // Test 1: Simple key press
            KeyboardVisualizerView(
                currentKey: "A",
                currentModifiers: [],
                keystrokeSequence: 1
            )

            // Test 2: Modifier + key
            KeyboardVisualizerView(
                currentKey: "C",
                currentModifiers: ["Command"],
                keystrokeSequence: 2
            )

            // Test 3: Multiple modifiers
            KeyboardVisualizerView(
                currentKey: "S",
                currentModifiers: ["Shift", "Command"],
                keystrokeSequence: 3
            )
        }
        .padding()
        .background(Color(.systemBackground))
    }
}
#endif
