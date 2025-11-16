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

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.acceptLocalOnly = true // Only accept connections from local network
            parameters.includePeerToPeer = true

            listener = try NWListener(using: parameters, on: port)

            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleListenerStateChange(state)
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleNewConnection(connection)
                }
            }

            listener?.start(queue: queue)
            logger.info("Network server started on port \(self.port)")

        } catch {
            logger.error("Failed to start server: \(error.localizedDescription)")
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
        case .ready:
            isRunning = true
            logger.info("Server is ready to accept connections")

        case .failed(let error):
            logger.error("Server failed: \(error.localizedDescription)")
            isRunning = false
            stopServer()

        case .cancelled:
            isRunning = false
            logger.info("Server cancelled")

        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        logger.info("New connection from \(connection.endpoint)")

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleConnectionStateChange(connection, state: state)
            }
        }

        connection.start(queue: queue)
        connections.append(connection)

        Task { @MainActor in
            connectedClients = connections.count
        }

        // Send welcome message
        sendWelcomeMessage(to: connection)

        // Send historical stats
        sendHistoricalStats(to: connection)
    }

    private func handleConnectionStateChange(_ connection: NWConnection, state: NWConnection.State) {
        switch state {
        case .ready:
            logger.info("Connection ready: \(connection.endpoint)")

        case .failed(let error):
            logger.error("Connection failed: \(error.localizedDescription)")
            removeConnection(connection)

        case .cancelled:
            logger.info("Connection cancelled: \(connection.endpoint)")
            removeConnection(connection)

        default:
            break
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
        sendMessage(message, to: connection)
    }

    private func sendHistoricalStats(to connection: NWConnection) {
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

                // Fetch daily stats for last 30 days
                var dailyStats: [DailyStatsData] = []

                for dayOffset in 0..<30 {
                    let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
                    let dateString = dateFormatter.string(from: date)

                    let stats = try await db.read { db in
                        try DailyStats
                            .filter(Column("date") == dateString)
                            .fetchAll(db)
                    }

                    let totalDuration = stats.reduce(0) { $0 + $1.totalDuration }
                    let totalKeystrokes = stats.reduce(0) { $0 + $1.keystrokeCount }

                    dailyStats.append(DailyStatsData(
                        date: dateString,
                        totalSeconds: totalDuration,
                        totalKeystrokes: totalKeystrokes,
                        totalMouseMovements: 0, // Not tracked in DailyStats yet
                        totalMouseClicks: 0,    // Not tracked in DailyStats yet
                        appCount: stats.count
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

                let topApps = topAppsStats.map { stats in
                    AppStatsData(
                        bundleIdentifier: "unknown", // Not stored in DailyStats
                        appName: stats.appName,
                        iconPath: nil,
                        totalSeconds: stats.totalDuration,
                        keystrokes: stats.keystrokeCount,
                        mouseMovements: 0,  // Not tracked yet
                        mouseClicks: 0,     // Not tracked yet
                        lastActive: stats.lastActive
                    )
                }

                let message = HistoricalStatsMessage(dailyStats: dailyStats, topApps: topApps)
                sendMessage(message, to: connection)

            } catch {
                logger.error("Failed to fetch historical stats: \(error.localizedDescription)")
            }
        }
    }

    func sendMessage<T: NetworkMessage>(_ message: T, to connection: NWConnection? = nil) {
        do {
            let data = try MessageEncoder.encode(message)

            if let connection = connection {
                // Send to specific connection
                sendData(data, to: connection)
            } else {
                // Broadcast to all connections
                connections.forEach { conn in
                    sendData(data, to: conn)
                }
            }
        } catch {
            logger.error("Failed to encode message: \(error.localizedDescription)")
        }
    }

    private func sendData(_ data: Data, to connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                self.logger.error("Send error: \(error.localizedDescription)")
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
        let message = ITerm2SessionsMessage(
            timestamp: Date(),
            sessions: sessions
        )

        sendMessage(message)
    }

    /// Broadcast heartbeat
    func broadcastHeartbeat(activeApp: AppInfo?, isActive: Bool, keystrokesLastMinute: Int, mouseEventsLastMinute: Int) {
        let activeAppData: ActiveAppData? = activeApp.map {
            let projectName = AppMonitor.shared.extractProjectName(from: $0.windowTitle)
            return ActiveAppData(
                bundleIdentifier: $0.bundleId,
                appName: $0.name,
                windowTitle: $0.windowTitle,
                projectName: projectName
            )
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
}
