//
//  PermissionManager.swift
//  Grind
//
//  Manages macOS permissions (Accessibility, Screen Recording, etc.)
//  Implements PRD FR-018
//

import Foundation
import ApplicationServices
import AppKit

/// Manager for handling macOS permissions
class PermissionManager {
    static let shared = PermissionManager()

    private init() {}

    // MARK: - Accessibility Permission

    /// Check if Accessibility permission is granted
    func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Request Accessibility permission
    /// Opens System Preferences if not granted
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Get Accessibility permission status with explanation
    func getAccessibilityStatus() -> PermissionStatus {
        let granted = hasAccessibilityPermission()

        return PermissionStatus(
            name: "Accessibility",
            isGranted: granted,
            isRequired: true,
            explanation: """
            Grind needs Accessibility permission to:
            • Monitor active applications
            • Track keyboard/mouse activity
            • Detect when you're actively working vs. idle
            • Count keystrokes (for productivity metrics)

            Your privacy: We count keystrokes only, never record what you type.
            """,
            fallbackBehavior: granted ? nil : """
            Without Accessibility permission:
            • Basic app tracking will work
            • Idle detection will be less accurate
            • Keystroke counting will be unavailable
            """
        )
    }

    // MARK: - Screen Recording Permission (for Phase 2)

    /// Check if Screen Recording permission is granted
    /// Note: This is for future terminal tracking features
    func hasScreenRecordingPermission() -> Bool {
        // CGWindowListCopyWindowInfo will return limited info if permission denied
        // This is a simplified check
        if let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] {
            // If we can see window names, permission is likely granted
            return windows.contains { window in
                window[kCGWindowName as String] != nil
            }
        }
        return false
    }

    /// Get Screen Recording permission status
    func getScreenRecordingStatus() -> PermissionStatus {
        let granted = hasScreenRecordingPermission()

        return PermissionStatus(
            name: "Screen Recording",
            isGranted: granted,
            isRequired: false,
            explanation: """
            Screen Recording permission enables:
            • Enhanced terminal content tracking
            • Detailed window information
            • Better project detection

            This is optional and only needed for advanced features.
            """,
            fallbackBehavior: granted ? nil : """
            Without Screen Recording permission:
            • Basic tracking still works normally
            • Terminal tracking uses Accessibility API fallback
            • Reduced terminal content detail
            """
        )
    }

    // MARK: - All Permissions

    /// Get status of all permissions
    func getAllPermissionStatuses() -> [PermissionStatus] {
        return [
            getAccessibilityStatus(),
            getScreenRecordingStatus()
        ]
    }

    /// Check if all required permissions are granted
    func hasRequiredPermissions() -> Bool {
        return hasAccessibilityPermission()
    }

    /// Check if all permissions (required + optional) are granted
    func hasAllPermissions() -> Bool {
        return hasAccessibilityPermission() && hasScreenRecordingPermission()
    }
}

// MARK: - Permission Status

struct PermissionStatus {
    let name: String
    let isGranted: Bool
    let isRequired: Bool
    let explanation: String
    let fallbackBehavior: String?

    var status: String {
        return isGranted ? "✅ Granted" : "❌ Not Granted"
    }

    var displayText: String {
        var text = """
        \(name) Permission: \(status)
        \(isRequired ? "Required" : "Optional")

        \(explanation)
        """

        if let fallback = fallbackBehavior {
            text += "\n\n\(fallback)"
        }

        return text
    }
}
