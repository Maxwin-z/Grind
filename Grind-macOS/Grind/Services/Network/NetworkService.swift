//
//  NetworkService.swift
//  Grind
//
//  Network service for streaming activity data to connected clients
//

import Foundation
import Network
import Logging
import Combine
import GRDB

/// Network service that broadcasts activity data to connected clients
@MainActor
class NetworkService: ObservableObject {
    static let shared = NetworkService()

    private let logger = Logger(label: "NetworkService")
    private let port: NWEndpoint.Port = 9527
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "me.maxwin.Grind.network")
    private let dataSharingPreferences = AppDataSharingPreferences.shared

    @Published var isRunning = false
    @Published var connectedClients = 0
    @Published var serverPort: UInt16 = 9527

    private init() {}

    // MARK: - Server Lifecycle

    /// Start the network server
    func startServer() {
        guard listener == nil else {
            logger.warning("Server already running")
            return
        }

        logger.info("🚀 Starting network server...")
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.acceptLocalOnly = true // Only accept connections from local network
            parameters.includePeerToPeer = true

            // Add Bonjour service advertisement
            let txtRecord = NWTXTRecord(["version": "1.0"])
            parameters.requiredInterfaceType = .wifi
            parameters.serviceClass = .responsiveData

            // Advertise as "_grind._tcp" service
            logger.info("   Advertising Bonjour service '_grind._tcp' as 'Grind'")
            let listener = try NWListener(using: parameters, on: port)
            listener.service = NWListener.Service(name: "Grind", type: "_grind._tcp", txtRecord: txtRecord)

            self.listener = listener

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleListenerStateChange(state)
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleNewConnection(connection)
                }
            }

            logger.info("   Starting listener on port \(self.port)...")
            listener.start(queue: queue)
            logger.info("✅ Network server started on port \(self.port)")

        } catch {
            logger.error("❌ Failed to start server: \(error.localizedDescription)")
        }
    }

    /// Stop the network server
    func stopServer() {
        listener?.cancel()
        listener = nil

        connections.forEach { $0.cancel() }
        connections.removeAll()

        Task { @MainActor in
            isRunning = false
            connectedClients = 0
        }

        logger.info("Network server stopped")
    }

    // MARK: - Connection Management

    private func handleListenerStateChange(_ state: NWListener.State) {
        switch state {
        case .setup:
            logger.info("🔧 Server setting up...")

        case .waiting(let error):
            logger.warning("⏳ Server waiting: \(error.localizedDescription)")

        case .ready:
            isRunning = true
            logger.info("✅ Server is ready to accept connections")
            logger.info("   Listening on port: \(self.serverPort)")
            logger.info("   Bonjour service: _grind._tcp")

        case .failed(let error):
            logger.error("❌ Server failed: \(error.localizedDescription)")
            isRunning = false
            stopServer()

        case .cancelled:
            isRunning = false
            logger.info("⚠️ Server cancelled")

        @unknown default:
            logger.warning("Unknown listener state")
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        logger.info("🔔 New connection from \(connection.endpoint)")

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleConnectionStateChange(connection, state: state)
            }
        }

        logger.info("   Starting connection...")
        connection.start(queue: queue)
        connections.append(connection)

        Task { @MainActor in
            connectedClients = connections.count
            logger.info("   Total connected clients: \(connectedClients)")
        }

        // Send welcome message
        logger.info("   Preparing to send initial data...")
        sendWelcomeMessage(to: connection)

        // Send historical stats
        sendHistoricalStats(to: connection)

        // Send today's time blocks
        sendTodayTimeBlocks(to: connection)
    }

    private func handleConnectionStateChange(_ connection: NWConnection, state: NWConnection.State) {
        switch state {
        case .ready:
            logger.info("✅ Connection ready: \(connection.endpoint)")

        case .preparing:
            logger.info("🔄 Connection preparing: \(connection.endpoint)")

        case .waiting(let error):
            logger.warning("⏳ Connection waiting: \(connection.endpoint) - \(error.localizedDescription)")

        case .failed(let error):
            logger.error("❌ Connection failed: \(connection.endpoint) - \(error.localizedDescription)")
            removeConnection(connection)

        case .cancelled:
            logger.info("⚠️ Connection cancelled: \(connection.endpoint)")
            removeConnection(connection)

        @unknown default:
            logger.warning("Unknown connection state for: \(connection.endpoint)")
        }
    }

    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll { $0 === connection }

        Task { @MainActor in
            connectedClients = connections.count
        }
    }

    // MARK: - Message Sending

    private func sendWelcomeMessage(to connection: NWConnection) {
        let message = WelcomeMessage()
        logger.info("📤 Sending welcome message to \(connection.endpoint)")
        sendMessage(message, to: connection)
    }

    private func sendHistoricalStats(to connection: NWConnection) {
        let selectionSnapshot = dataSharingPreferences.snapshot()

        Task {
            do {
                guard let db = DatabaseManager.shared.getDatabase() else {
                    logger.error("Database not initialized")
                    return
                }

                let calendar = Calendar.current
                let now = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"

                // Ensure we have aggregated stats for recent history
                let maxHistoricalDays = 30
                do {
                    try ensureDailyStatsCoverage(days: maxHistoricalDays, referenceDate: now, calendar: calendar)
                } catch {
                    logger.error("Failed to ensure daily stats coverage: \(error.localizedDescription)")
                }

                // Fetch daily stats for last 30 days
                var dailyStats: [DailyStatsData] = []
                var dailyAppBreakdown: [DailyAppBreakdownData] = []

                for dayOffset in stride(from: maxHistoricalDays - 1, through: 0, by: -1) {
                    let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
                    let dateString = dateFormatter.string(from: date)

                    let stats = try await db.read { db in
                        try DailyStats
                            .filter(Column("date") == dateString)
                            .fetchAll(db)
                    }

                    let filteredStats = stats.filter { selectionSnapshot.isAppSelected(bundleId: nil, appName: $0.appName) }

                    let totalDuration = filteredStats.reduce(0) { $0 + $1.totalDuration }
                    let totalKeystrokes = filteredStats.reduce(0) { $0 + $1.keystrokeCount }
                    let totalMouseMovements = filteredStats.reduce(0) { $0 + $1.mouseMovementCount }
                    let totalMouseClicks = filteredStats.reduce(0) { $0 + $1.mouseClickCount }

                    dailyStats.append(DailyStatsData(
                        date: dateString,
                        totalSeconds: totalDuration,
                        totalKeystrokes: totalKeystrokes,
                        totalMouseMovements: totalMouseMovements,
                        totalMouseClicks: totalMouseClicks,
                        appCount: filteredStats.count
                    ))

                    let appMetrics = filteredStats.map { stat in
                        DailyAppMetricsData(
                            appName: stat.appName,
                            duration: stat.totalDuration,
                            keystrokes: stat.keystrokeCount,
                            category: stat.category
                        )
                    }
                    .sorted { $0.duration > $1.duration }

                    dailyAppBreakdown.append(DailyAppBreakdownData(
                        date: dateString,
                        apps: appMetrics
                    ))
                }

                // Fetch top apps (last 7 days)
                let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
                let sevenDaysAgoString = dateFormatter.string(from: sevenDaysAgo)

                let topAppsStats = try await db.read { db in
                    try DailyStats
                        .filter(Column("date") >= sevenDaysAgoString)
                        .order(Column("totalDuration").desc)
                        .limit(20)
                        .fetchAll(db)
                }

                let filteredTopAppsStats = topAppsStats.filter {
                    selectionSnapshot.isAppSelected(bundleId: nil, appName: $0.appName)
                }

                let topApps = filteredTopAppsStats.map { stats in
                    AppStatsData(
                        bundleIdentifier: "unknown", // Not stored in DailyStats
                        appName: stats.appName,
                        iconPath: nil,
                        totalSeconds: stats.totalDuration,
                        keystrokes: stats.keystrokeCount,
                        mouseMovements: stats.mouseMovementCount,
                        mouseClicks: stats.mouseClickCount,
                        lastActive: stats.lastActive
                    )
                }

                let message = HistoricalStatsMessage(
                    dailyStats: dailyStats,
                    topApps: topApps,
                    dailyAppBreakdown: dailyAppBreakdown
                )
                logger.info("📤 Sending historical stats: \(dailyStats.count) days, \(topApps.count) apps")
                for (index, stat) in dailyStats.prefix(5).enumerated() {
                    logger.info("   Day \(index): \(stat.date) - \(stat.totalSeconds)s, \(stat.totalKeystrokes) keys")
                }
                sendMessage(message, to: connection)

            } catch {
                logger.error("Failed to fetch historical stats: \(error.localizedDescription)")
            }
        }
    }

    private func sendTodayTimeBlocks(to connection: NWConnection) {
        let selectionSnapshot = dataSharingPreferences.snapshot()

        Task {
            do {
                let repository = TimeBlockRepository()
                let blocks = try repository.getTodayBlocks()

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let today = dateFormatter.string(from: Date())

                let filteredBlocks = blocks.filter {
                    selectionSnapshot.isAppSelected(bundleId: nil, appName: $0.appName)
                }

                let blockData = filteredBlocks.map { block in
                    TimeBlockData(
                        blockStart: block.blockStart,
                        appName: block.appName,
                        duration: block.activeDuration,
                        keystrokes: block.keystrokeCount,
                        mouseMovements: 0, // Not available in TimeBlock model
                        mouseClicks: 0
                    )
                }

                let message = TimeBlocksMessage(date: today, blocks: blockData)
                logger.info("📤 Sending time blocks for \(today): \(filteredBlocks.count) blocks")
                let activeBlocks = blockData.filter { $0.duration > 0 }
                logger.info("   - \(activeBlocks.count) blocks with activity")
                for (index, block) in activeBlocks.prefix(5).enumerated() {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    let timeStr = formatter.string(from: block.blockStart)
                    logger.info("   Block \(index): \(timeStr) - \(block.appName ?? "Unknown") - \(block.duration)s")
                }
                sendMessage(message, to: connection)

            } catch {
                logger.error("Failed to fetch today's time blocks: \(error.localizedDescription)")
            }
        }
    }

    func sendMessage<T: NetworkMessage>(_ message: T, to connection: NWConnection? = nil) {
        do {
            let data = try MessageEncoder.encode(message)
            logger.info("📦 Encoded message type: \(message.type), size: \(data.count) bytes")

            if let connection = connection {
                // Send to specific connection
                logger.info("   → Sending to specific connection: \(connection.endpoint)")
                sendData(data, to: connection)
            } else {
                // Broadcast to all connections
                logger.info("   → Broadcasting to \(connections.count) connections")
                connections.forEach { conn in
                    sendData(data, to: conn)
                }
            }
        } catch {
            logger.error("Failed to encode message: \(error.localizedDescription)")
        }
    }

    private func ensureDailyStatsCoverage(days: Int, referenceDate: Date, calendar: Calendar) throws {
        let aggregator = TimeBlockAggregator.shared

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: referenceDate) else { continue }
            try aggregator.ensureDailyStats(for: date)
        }
    }

    private func sendData(_ data: Data, to connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                self.logger.error("❌ Send error to \(connection.endpoint): \(error.localizedDescription)")
            } else {
                self.logger.info("✅ Successfully sent \(data.count) bytes to \(connection.endpoint)")
            }
        })
    }

    // MARK: - Public Broadcasting Methods

    /// Broadcast real-time activity update
    func broadcastRealtimeActivity(
        activeApp: AppInfo,
        isTyping: Bool,
        idleSeconds: Double,
        keystrokes: Int,
        mouseMovements: Int,
        mouseClicks: Int
    ) {
        guard shouldShareApp(bundleId: activeApp.bundleId, appName: activeApp.name) else {
            return
        }

        // Extract project name from window title
        let projectName = AppMonitor.shared.extractProjectName(from: activeApp.windowTitle)

        let message = RealtimeActivityMessage(
            timestamp: Date(),
            activeApp: ActiveAppData(
                bundleIdentifier: activeApp.bundleId,
                appName: activeApp.name,
                windowTitle: activeApp.windowTitle,
                projectName: projectName
            ),
            isTyping: isTyping,
            idleSeconds: idleSeconds,
            keystrokesSinceLastUpdate: keystrokes,
            mouseMovementsSinceLastUpdate: mouseMovements,
            mouseClicksSinceLastUpdate: mouseClicks
        )

        sendMessage(message)
    }

    /// Broadcast keystroke event
    func broadcastKeystroke(key: String, keyCode: UInt16, modifiers: [String], appBundleId: String) {
        guard shouldShareApp(bundleId: appBundleId, appName: nil) else {
            return
        }

        let message = KeystrokeMessage(
            timestamp: Date(),
            key: key,
            keyCode: keyCode,
            modifiers: modifiers,
            appBundleIdentifier: appBundleId
        )

        sendMessage(message)
    }

    /// Broadcast mouse event
    func broadcastMouseEvent(
        eventType: MouseEventType,
        x: Double? = nil,
        y: Double? = nil,
        button: Int? = nil,
        appBundleId: String
    ) {
        guard shouldShareApp(bundleId: appBundleId, appName: nil) else {
            return
        }

        let message = MouseEventMessage(
            timestamp: Date(),
            eventType: eventType,
            x: x,
            y: y,
            button: button,
            appBundleIdentifier: appBundleId
        )

        sendMessage(message)
    }

    /// Broadcast iTerm2 sessions
    func broadcastITerm2Sessions(_ sessions: [ITerm2SessionData]) {
        guard shouldShareApp(bundleId: "com.googlecode.iterm2", appName: "iTerm2") else {
            return
        }

        let message = ITerm2SessionsMessage(
            timestamp: Date(),
            sessions: sessions
        )

        sendMessage(message)
    }

    /// Broadcast heartbeat
    func broadcastHeartbeat(activeApp: AppInfo?, isActive: Bool, keystrokesLastMinute: Int, mouseEventsLastMinute: Int) {
        let activeAppData: ActiveAppData?
        if let activeApp,
           shouldShareApp(bundleId: activeApp.bundleId, appName: activeApp.name) {
            let projectName = AppMonitor.shared.extractProjectName(from: activeApp.windowTitle)
            activeAppData = ActiveAppData(
                bundleIdentifier: activeApp.bundleId,
                appName: activeApp.name,
                windowTitle: activeApp.windowTitle,
                projectName: projectName
            )
        } else {
            activeAppData = nil
        }

        let message = HeartbeatMessage(
            timestamp: Date(),
            activeApp: activeAppData,
            isActive: isActive,
            keystrokesLastMinute: keystrokesLastMinute,
            mouseEventsLastMinute: mouseEventsLastMinute
        )

        sendMessage(message)
    }

    private func shouldShareApp(bundleId: String?, appName: String?) -> Bool {
        dataSharingPreferences.isAppSelected(bundleId: bundleId, appName: appName)
    }
}
