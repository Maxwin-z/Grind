//
//  ActivityMonitor.swift
//  Grind
//
//  Main activity monitoring service
//  Coordinates all monitoring components and runs the main polling loop
//  Implements PRD FR-001 polling every 2 seconds
//

import Foundation
import Combine

/// Main activity monitoring coordinator
/// Runs the 2-second polling loop per PRD FR-001
class ActivityMonitor {
    static let shared = ActivityMonitor()

    private var timer: Timer?
    private let pollInterval: TimeInterval = 2.0  // Per PRD FR-001
    private var permissionRetryTimer: Timer?

    private let appMonitor = AppMonitor.shared
    private let idleDetector = IdleDetector.shared
    private let keystrokeCounter = KeystrokeCounter.shared
    private let mouseCounter = MouseMovementCounter.shared
    private let heartbeatService = HeartbeatService.shared
    private let timeBlockAggregator = TimeBlockAggregator.shared
    private let permissionManager = PermissionManager.shared
    private let networkService = NetworkService.shared

    private(set) var isMonitoring = false
    private var inputMonitoringActive = false
    private var lastNetworkBroadcastTime = Date()
    private var keystrokesSinceLastBroadcast = 0
    private var mouseMovementsSinceLastBroadcast = 0
    private var mouseClicksSinceLastBroadcast = 0

    // Statistics
    private(set) var totalHeartbeats = 0
    private(set) var monitoringStartTime: Date?

    // Callbacks
    var onHeartbeatRecorded: ((Heartbeat) -> Void)?
    var onActivityUpdate: (() -> Void)?

    private init() {
        setupAppMonitor()
    }

    // MARK: - Setup

    private func setupAppMonitor() {
        // Listen for app changes
        appMonitor.onAppChanged = { [weak self] newApp, oldApp in
            print("🔄 App changed: \(oldApp?.name ?? "None") → \(newApp.name)")
            self?.onActivityUpdate?()

            // Handle iTerm2 monitoring
            ITerm2Service.shared.handleAppChange(bundleId: newApp.bundleId)
        }

        // Set up keystroke counter callback for network tracking
        keystrokeCounter.onKeystrokeCountUpdate = { [weak self] count in
            self?.keystrokesSinceLastBroadcast += 1
        }

        // Set up mouse counter callback for network tracking
        mouseCounter.onMouseActivityUpdate = { [weak self] movements, clicks in
            guard let self = self else { return }
            self.mouseMovementsSinceLastBroadcast += 1
            // Clicks are tracked in the increment method
        }
    }

    // MARK: - Start/Stop Monitoring

    /// Start the activity monitoring loop
    func startMonitoring() {
        guard !isMonitoring else {
            print("⚠️  Activity monitoring already running")
            return
        }

        startInputMonitoringIfNeeded()

        // Initialize current app
        appMonitor.updateCurrentApp()

        // Start timer
        timer = Timer.scheduledTimer(
            withTimeInterval: pollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkActivity()
        }

        // Also fire immediately
        timer?.fire()

        isMonitoring = true
        monitoringStartTime = Date()

        print("✅ Activity monitoring started (polling every \(pollInterval)s)")
    }

    /// Stop the activity monitoring loop
    func stopMonitoring() {
        guard isMonitoring else { return }

        // Stop timer
        timer?.invalidate()
        timer = nil
        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil
        inputMonitoringActive = false

        // Stop counters
        keystrokeCounter.stopMonitoring()
        mouseCounter.stopMonitoring()

        // Close current session
        heartbeatService.closeSession()

        isMonitoring = false

        print("⏹️  Activity monitoring stopped")
        print("📊 Total heartbeats recorded: \(totalHeartbeats)")
    }

    // MARK: - Input Monitoring

    private func startInputMonitoringIfNeeded() {
        guard permissionManager.hasAccessibilityPermission() else {
            schedulePermissionRetry()
            return
        }

        guard !inputMonitoringActive else { return }

        keystrokeCounter.startMonitoring()
        mouseCounter.startMonitoring()
        inputMonitoringActive = true

        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil

        print("✅ Input monitoring enabled")
    }

    private func schedulePermissionRetry() {
        guard permissionRetryTimer == nil else { return }

        permissionRetryTimer = Timer.scheduledTimer(
            withTimeInterval: 5,
            repeats: true
        ) { [weak self] _ in
            self?.startInputMonitoringIfNeeded()
        }

        print("⏳ Waiting for Accessibility permission to enable input monitoring")
    }

    // MARK: - Activity Check Loop

    /// Main activity check loop (called every 2 seconds)
    /// Implements the core tracking logic from PRD FR-001, FR-002, FR-003
    private func checkActivity() {
        // 1. Update current app
        appMonitor.updateCurrentApp()

        // 2. Check idle time
        let idleTime = idleDetector.getIdleTime()

        // 3. If away (>120s), close session and skip
        if idleTime > 120 {
            if heartbeatService.isContinuousSession() {
                heartbeatService.closeSession()
                print("💤 User away - session closed")
            }
            return
        }

        // 4. If active (<30s), record heartbeat
        if idleTime < 30 {
            if let heartbeat = heartbeatService.recordActivity() {
                totalHeartbeats += 1
                onHeartbeatRecorded?(heartbeat)

                // Aggregate to time block
                timeBlockAggregator.aggregateHeartbeat(heartbeat)

                // Log activity
                let activityLevel = idleDetector.getActivityLevel()
                print("💓 Heartbeat #\(totalHeartbeats): \(heartbeat.appName) [\(activityLevel)]")
            }
        }

        // 5. Broadcast real-time activity to network (every 2 seconds)
        broadcastRealtimeActivity(idleTime: idleTime)

        // 6. Notify about activity update
        onActivityUpdate?()
    }

    // MARK: - Network Broadcasting

    private func broadcastRealtimeActivity(idleTime: TimeInterval) {
        guard let currentApp = appMonitor.currentApp else { return }

        let isTyping = idleTime < 10
        let keystrokes = keystrokesSinceLastBroadcast
        let movements = mouseMovementsSinceLastBroadcast
        let clicks = mouseClicksSinceLastBroadcast

        networkService.broadcastRealtimeActivity(
            activeApp: currentApp,
            isTyping: isTyping,
            idleSeconds: idleTime,
            keystrokes: keystrokes,
            mouseMovements: movements,
            mouseClicks: clicks
        )

        // Reset counters
        keystrokesSinceLastBroadcast = 0
        mouseMovementsSinceLastBroadcast = 0
        mouseClicksSinceLastBroadcast = 0
        lastNetworkBroadcastTime = Date()
    }

    // MARK: - Status

    /// Get current monitoring status
    func getStatus() -> MonitoringStatus {
        guard isMonitoring else {
            return MonitoringStatus(
                isMonitoring: false,
                currentApp: nil,
                activityLevel: .away,
                idleTime: 0,
                totalHeartbeats: totalHeartbeats,
                uptime: 0
            )
        }

        let uptime = monitoringStartTime.map { Date().timeIntervalSince($0) } ?? 0

        return MonitoringStatus(
            isMonitoring: true,
            currentApp: appMonitor.currentApp,
            activityLevel: idleDetector.getActivityLevel(),
            idleTime: idleDetector.getIdleTime(),
            totalHeartbeats: totalHeartbeats,
            uptime: uptime
        )
    }

    /// Get statistics summary
    func getStatistics() -> String {
        let status = getStatus()
        var stats = """
        Activity Monitor Statistics
        ===========================
        Status: \(status.isMonitoring ? "Running" : "Stopped")
        Total Heartbeats: \(status.totalHeartbeats)
        """

        if status.isMonitoring {
            stats += """

            Current App: \(status.currentApp?.name ?? "None")
            Activity Level: \(status.activityLevel)
            Idle Time: \(Int(status.idleTime))s
            Uptime: \(Int(status.uptime / 60))m
            """
        }

        return stats
    }
}

// MARK: - Monitoring Status

struct MonitoringStatus {
    let isMonitoring: Bool
    let currentApp: AppInfo?
    let activityLevel: ActivityLevel
    let idleTime: TimeInterval
    let totalHeartbeats: Int
    let uptime: TimeInterval
}
