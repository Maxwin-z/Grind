//
//  KeystrokeCounter.swift
//  Grind
//
//  Global keystroke counting service
//  Implements PRD FR-004 keystroke tracking
//

import Foundation
import CoreGraphics
import ApplicationServices
import os.log

/// Notification posted when a key is pressed
extension Notification.Name {
    static let keyPressed = Notification.Name("KeystrokeCounter.keyPressed")
}

/// Global keystroke counter using event tap
/// Requires Accessibility permission
class KeystrokeCounter {
    static let shared = KeystrokeCounter()

    private let logger = Logger(subsystem: "me.maxwin.Grind", category: "KeystrokeCounter")

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private(set) var currentCount: Int = 0
    private var lastResetTime: Date = Date()
    private(set) var lastKeyPressed: String = ""
    private(set) var lastKeyTimestamp: Date = Date()

    // Callback for keystroke count updates
    var onKeystrokeCountUpdate: ((Int) -> Void)?

    private init() {}

    // MARK: - Start/Stop Monitoring

    /// Start monitoring keystrokes
    /// Requires Accessibility permission
    func startMonitoring() {
        guard eventTap == nil else {
            print("⚠️  Keystroke counter already running")
            return
        }

        // Check for accessibility permission
        guard AXIsProcessTrusted() else {
            print("❌ Accessibility permission required for keystroke tracking")
            return
        }

        // Create event tap for keyboard events
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,  // Read-only, per PRD privacy requirements
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if type == .keyDown {
                    let counter = Unmanaged<KeystrokeCounter>.fromOpaque(refcon!).takeUnretainedValue()
                    counter.incrementCount(event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("❌ Failed to create event tap for keystroke tracking")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("✅ Keystroke counter started")
    }

    /// Stop monitoring keystrokes
    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            eventTap = nil
            runLoopSource = nil
            print("⏹️  Keystroke counter stopped")
        }
    }

    // MARK: - Count Management

    /// Increment keystroke count and capture key character
    private func incrementCount(event: CGEvent) {
        currentCount += 1

        // Extract the key character
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        lastKeyPressed = extractKeyString(from: event)
        lastKeyTimestamp = Date()

        // Extract modifier keys
        let modifiers = extractModifiers(from: event)

        logger.info("🔑 Key captured: '\(self.lastKeyPressed)' (code: \(keyCode)) with modifiers: \(modifiers) at \(self.lastKeyTimestamp.timeIntervalSince1970)")

        // Get current app bundle ID
        let appBundleId = AppMonitor.shared.currentApp?.bundleId ?? "unknown"

        // Post notification for real-time updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.logger.info("📤 Posting notification for key: '\(self.lastKeyPressed)'")
            NotificationCenter.default.post(
                name: .keyPressed,
                object: nil,
                userInfo: [
                    "key": self.lastKeyPressed,
                    "keyCode": keyCode,
                    "modifiers": modifiers,
                    "timestamp": self.lastKeyTimestamp,
                    "appBundleId": appBundleId
                ]
            )

            // Broadcast to network clients
            NetworkService.shared.broadcastKeystroke(
                key: self.lastKeyPressed,
                keyCode: UInt16(keyCode),
                modifiers: modifiers,
                appBundleId: appBundleId
            )
        }

        onKeystrokeCountUpdate?(currentCount)
    }

    /// Extract modifier keys from event
    private func extractModifiers(from event: CGEvent) -> [String] {
        let flags = event.flags
        var modifiers: [String] = []

        if flags.contains(.maskCommand) {
            modifiers.append("Command")
        }
        if flags.contains(.maskShift) {
            modifiers.append("Shift")
        }
        if flags.contains(.maskAlternate) {
            modifiers.append("Option")
        }
        if flags.contains(.maskControl) {
            modifiers.append("Control")
        }
        if flags.contains(.maskSecondaryFn) {
            modifiers.append("Fn")
        }

        return modifiers
    }

    /// Extract a human-readable string from the key event
    private func extractKeyString(from event: CGEvent) -> String {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Get the Unicode string for the key
        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: nil)

        var chars = [UniChar](repeating: 0, count: length)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)

        if length > 0 {
            let string = String(utf16CodeUnits: chars, count: length)

            // Handle special keys
            if string.unicodeScalars.allSatisfy({ !CharacterSet.alphanumerics.contains($0) && !CharacterSet.punctuationCharacters.contains($0) && !CharacterSet.symbols.contains($0) }) {
                return specialKeyName(for: keyCode) ?? "Special"
            }

            return string
        }

        // Fallback to key code mapping for special keys
        return specialKeyName(for: keyCode) ?? "Key \(keyCode)"
    }

    /// Map key codes to special key names
    private func specialKeyName(for keyCode: Int64) -> String? {
        switch keyCode {
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Escape"
        case 123: return "Left"
        case 124: return "Right"
        case 125: return "Down"
        case 126: return "Up"
        case 117: return "Forward Delete"
        case 115: return "Home"
        case 119: return "End"
        case 116: return "Page Up"
        case 121: return "Page Down"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return nil
        }
    }

    /// Get current count and reset
    func getCountAndReset() -> Int {
        let count = currentCount
        currentCount = 0
        lastResetTime = Date()
        return count
    }

    /// Reset count to zero
    func resetCount() {
        currentCount = 0
        lastResetTime = Date()
    }

    /// Get count for last period without resetting
    func getCurrentCount() -> Int {
        return currentCount
    }

    // MARK: - Statistics

    /// Get keystrokes per minute based on time since last reset
    func getKeystrokesPerMinute() -> Double {
        let timeSinceReset = Date().timeIntervalSince(lastResetTime)
        guard timeSinceReset > 0 else { return 0 }

        let minutes = timeSinceReset / 60.0
        return Double(currentCount) / minutes
    }

    /// Get time since last reset
    func getTimeSinceReset() -> TimeInterval {
        return Date().timeIntervalSince(lastResetTime)
    }
}

// MARK: - Permission Checking

extension KeystrokeCounter {
    /// Check if Accessibility permission is granted
    static func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Request Accessibility permission
    /// Opens System Preferences if not granted
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
