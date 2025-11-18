//
//  MouseMovementCounter.swift
//  Grind
//
//  Global mouse movement and click tracking service
//  Complements keystroke tracking for comprehensive activity monitoring
//

import Foundation
import CoreGraphics
import ApplicationServices

/// Global mouse movement and click counter using event tap
/// Requires Accessibility permission
class MouseMovementCounter {
    static let shared = MouseMovementCounter()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private(set) var movementCount: Int = 0
    private(set) var clickCount: Int = 0
    private var lastResetTime: Date = Date()

    // Callback for mouse activity updates
    var onMouseActivityUpdate: ((Int, Int) -> Void)?  // (movements, clicks)

    private init() {}

    // MARK: - Start/Stop Monitoring

    /// Start monitoring mouse activity
    /// Requires Accessibility permission
    func startMonitoring() {
        guard eventTap == nil else {
            return
        }

        // Check for accessibility permission
        guard AXIsProcessTrusted() else {
            return
        }

        // Create event mask for mouse events
        let eventMask = (
            CGEventMask(1 << CGEventType.mouseMoved.rawValue) |
            CGEventMask(1 << CGEventType.leftMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.rightMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.leftMouseDragged.rawValue) |
            CGEventMask(1 << CGEventType.rightMouseDragged.rawValue) |
            CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        )

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,  // Read-only, privacy-focused
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let counter = Unmanaged<MouseMovementCounter>.fromOpaque(refcon!).takeUnretainedValue()

                switch type {
                case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
                    counter.incrementMovement(event: event)
                case .scrollWheel:
                    counter.incrementMovement(event: event, isScroll: true)
                case .leftMouseDown:
                    counter.incrementClick(event: event, button: 0)
                case .rightMouseDown:
                    counter.incrementClick(event: event, button: 1)
                default:
                    break
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Stop monitoring mouse activity
    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            eventTap = nil
            runLoopSource = nil
        }
    }

    // MARK: - Count Management

    /// Increment movement count
    private func incrementMovement(event: CGEvent, isScroll: Bool = false) {
        movementCount += 1
        onMouseActivityUpdate?(movementCount, clickCount)

        // Get mouse position
        let location = event.location
        let appBundleId = AppMonitor.shared.currentApp?.bundleId ?? "unknown"

        // Broadcast to network (throttle to avoid overwhelming network)
        // Only broadcast every 10th movement to reduce network traffic
        if movementCount % 10 == 0 {
            DispatchQueue.main.async {
                NetworkService.shared.broadcastMouseEvent(
                    eventType: isScroll ? .scroll : .movement,
                    x: location.x,
                    y: location.y,
                    appBundleId: appBundleId
                )
            }
        }
    }

    /// Increment click count
    private func incrementClick(event: CGEvent, button: Int) {
        clickCount += 1
        onMouseActivityUpdate?(movementCount, clickCount)

        // Get click position
        let location = event.location
        let appBundleId = AppMonitor.shared.currentApp?.bundleId ?? "unknown"

        // Broadcast to network
        DispatchQueue.main.async {
            let eventType: MouseEventType = button == 0 ? .leftClick : .rightClick
            NetworkService.shared.broadcastMouseEvent(
                eventType: eventType,
                x: location.x,
                y: location.y,
                button: button,
                appBundleId: appBundleId
            )
        }
    }

    /// Get current counts and reset
    func getCountsAndReset() -> (movements: Int, clicks: Int) {
        let counts = (movements: movementCount, clicks: clickCount)
        movementCount = 0
        clickCount = 0
        lastResetTime = Date()
        return counts
    }

    /// Reset counts to zero
    func resetCounts() {
        movementCount = 0
        clickCount = 0
        lastResetTime = Date()
    }

    /// Get current counts without resetting
    func getCurrentCounts() -> (movements: Int, clicks: Int) {
        return (movements: movementCount, clicks: clickCount)
    }

    // MARK: - Statistics

    /// Get mouse activity per minute based on time since last reset
    func getActivityPerMinute() -> Double {
        let timeSinceReset = Date().timeIntervalSince(lastResetTime)
        guard timeSinceReset > 0 else { return 0 }

        let minutes = timeSinceReset / 60.0
        let totalActivity = Double(movementCount + clickCount)
        return totalActivity / minutes
    }

    /// Get time since last reset
    func getTimeSinceReset() -> TimeInterval {
        return Date().timeIntervalSince(lastResetTime)
    }
}

// MARK: - Permission Checking

extension MouseMovementCounter {
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
