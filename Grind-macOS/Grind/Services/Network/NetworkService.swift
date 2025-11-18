//
//  NetworkService.swift
//  Grind
//
//  Network service for streaming activity data to connected clients
//

import Foundation
import Network
import Combine
import GRDB

/// Network service that broadcasts activity data to connected clients
@MainActor
class NetworkService: ObservableObject {
    static let shared = NetworkService()

    private let port: NWEndpoint.Port = 9527
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "me.maxwin.Grind.network")
    private let dataSharingPreferences = AppDataSharingPreferences.shared
    private var selectionObserver: NSObjectProtocol?
    private var timeBlocksObserver: NSObjectProtocol?

    @Published var isRunning = false
    @Published var connectedClients = 0
    @Published var serverPort: UInt16 = 9527

    private init() {
        selectionObserver = NotificationCenter.default.addObserver(
            forName: .appDataSharingSelectionChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sendSelectedAppsList()
            self?.sendHistoricalStatsToAllConnections()
            self?.sendTodayTimeBlocksToAllConnections()
        }

        timeBlocksObserver = NotificationCenter.default.addObserver(
            forName: .timeBlocksDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let dates = notification.userInfo?["dates"] as? [Date] ?? [Date()]
            self.handleTimeBlocksUpdated(dates: dates)
        }
    }

    deinit {
        if let observer = selectionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = timeBlocksObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Server Lifecycle

    /// Start the network server
    func startServer() {
        guard listener == nil else {
            return
        }

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

            listener.start(queue: queue)

        } catch {
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

    }

    // MARK: - Connection Management

    private func handleListenerStateChange(_ state: NWListener.State) {
        switch state {
        case .setup:
            break

        case .waiting:
            break

        case .ready:
            isRunning = true

        case .failed:
            isRunning = false
            stopServer()

        case .cancelled:
            isRunning = false

        @unknown default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
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

        // Send today's time blocks
        sendTodayTimeBlocks(to: connection)

        // Send selected apps list
        sendSelectedAppsList(to: connection)
    }

    private func handleConnectionStateChange(_ connection: NWConnection, state: NWConnection.State) {
        switch state {
        case .ready, .preparing:
            break

        case .waiting:
            break

        case .failed:
            removeConnection(connection)

        case .cancelled:
            removeConnection(connection)

        @unknown default:
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
        let selectionSnapshot = dataSharingPreferences.snapshot()

        Task {
            do {
                guard let db = DatabaseManager.shared.getDatabase() else {
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
                }

        // Fetch daily stats for last 30 days
        var dailyStats: [DailyStatsData] = []
        var dailyAppBreakdown: [DailyAppBreakdownData] = []

        for dayOffset in stride(from: maxHistoricalDays - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let payload = try await self.buildDailyStatsPayload(
                for: date,
                dateFormatter: dateFormatter,
                selectionSnapshot: selectionSnapshot,
                db: db
            )
            dailyStats.append(payload.stats)
            dailyAppBreakdown.append(payload.breakdown)
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
                    let bundleId = self.getBundleId(forAppName: stats.appName) ?? "unknown"
                    return AppStatsData(
                        bundleIdentifier: bundleId,
                        appName: stats.appName,
                        iconPath: nil,
                        totalSeconds: stats.totalDuration,
                        keystrokes: stats.keystrokeCount,
                        mouseMovements: stats.mouseMovementCount,
                        mouseClicks: stats.mouseClickCount,
                        lastActive: stats.lastActive,
                        colorHex: self.getColorHex(bundleId: bundleId == "unknown" ? nil : bundleId, appName: stats.appName)
                    )
                }

                let message = HistoricalStatsMessage(
                    dailyStats: dailyStats,
                    topApps: topApps,
                    dailyAppBreakdown: dailyAppBreakdown
                )

                // Log breakdown details
                print("📤 Sending historical stats to client:")
                print("   Days of data: \(dailyAppBreakdown.count)")
                for (index, dayBreakdown) in dailyAppBreakdown.prefix(3).enumerated() {
                    print("   Day \(index + 1) (\(dayBreakdown.date)): \(dayBreakdown.apps.count) apps")
                    let appNames = dayBreakdown.apps.prefix(10).map { $0.appName }.joined(separator: ", ")
                    print("      Apps: \(appNames)\(dayBreakdown.apps.count > 10 ? "... and \(dayBreakdown.apps.count - 10) more" : "")")
                }
                if dailyAppBreakdown.count > 3 {
                    print("   ... and \(dailyAppBreakdown.count - 3) more days")
                }

                sendMessage(message, to: connection)

            } catch {
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
                        mouseClicks: 0,
                        colorHex: self.getColorHex(bundleId: nil, appName: block.appName)
                    )
                }

                let message = TimeBlocksMessage(date: today, blocks: blockData)
                sendMessage(message, to: connection)

            } catch {
            }
        }
    }

    private func sendDailyStatsUpdate(for date: Date = Date(), to connection: NWConnection? = nil) {
        let selectionSnapshot = dataSharingPreferences.snapshot()

        Task {
            do {
                try TimeBlockAggregator.shared.aggregateToDailyStatsSync(for: date)

                guard let db = DatabaseManager.shared.getDatabase() else {
                    return
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"

                let payload = try await self.buildDailyStatsPayload(
                    for: date,
                    dateFormatter: dateFormatter,
                    selectionSnapshot: selectionSnapshot,
                    db: db
                )

                let message = DailyStatsUpdateMessage(
                    dailyStats: payload.stats,
                    dailyAppBreakdown: payload.breakdown
                )
                sendMessage(message, to: connection)

            } catch {
            }
        }
    }

    private func sendSelectedAppsList(to connection: NWConnection? = nil) {
        let selectedApps = dataSharingPreferences.selectedAppsList()
        let appData = selectedApps.map {
            SelectedAppData(
                bundleIdentifier: $0.bundleIdentifier,
                appName: $0.appName,
                accentColorHex: $0.accentColorHex,
                iconPNGData: $0.iconPNGData
            )
        }

        let target = connection != nil ? "specific client" : "\(connections.count) client(s)"
        print("📤 Sending selected apps list to \(target):")
        print("   Total apps: \(appData.count)")
        if appData.count > 0 {
            let appNames = appData.prefix(10).map { $0.appName }.joined(separator: ", ")
            print("   Apps: \(appNames)\(appData.count > 10 ? "... and \(appData.count - 10) more" : "")")
        }

        let message = SelectedAppsMessage(apps: appData)
        sendMessage(message, to: connection)
    }

    private func sendHistoricalStatsToAllConnections() {
        connections.forEach { connection in
            sendHistoricalStats(to: connection)
        }
    }

    private func sendTodayTimeBlocksToAllConnections() {
        connections.forEach { connection in
            sendTodayTimeBlocks(to: connection)
        }
    }

    private func handleTimeBlocksUpdated(dates: [Date]) {
        guard !dates.isEmpty else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var shouldRefreshTimeline = false

        dates.forEach { date in
            if calendar.isDate(date, inSameDayAs: today) {
                shouldRefreshTimeline = true
            }
            sendDailyStatsUpdate(for: date)
        }

        if shouldRefreshTimeline {
            sendTodayTimeBlocksToAllConnections()
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
        }
    }

    private func ensureDailyStatsCoverage(days: Int, referenceDate: Date, calendar: Calendar) throws {
        let aggregator = TimeBlockAggregator.shared

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: referenceDate) else { continue }
            try aggregator.ensureDailyStats(for: date)
        }
    }

    private func buildDailyStatsPayload(
        for date: Date,
        dateFormatter: DateFormatter,
        selectionSnapshot: AppDataSharingSnapshot,
        db: DatabaseWriter
    ) async throws -> (stats: DailyStatsData, breakdown: DailyAppBreakdownData) {
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

        let dailyStats = DailyStatsData(
            date: dateString,
            totalSeconds: totalDuration,
            totalKeystrokes: totalKeystrokes,
            totalMouseMovements: totalMouseMovements,
            totalMouseClicks: totalMouseClicks,
            appCount: filteredStats.count
        )

        let appMetrics = filteredStats.map { stat in
            let bundleId = self.getBundleId(forAppName: stat.appName)
            return DailyAppMetricsData(
                appName: stat.appName,
                bundleId: bundleId,
                duration: stat.totalDuration,
                keystrokes: stat.keystrokeCount,
                category: stat.category,
                colorHex: self.getColorHex(bundleId: bundleId, appName: stat.appName)
            )
        }
        .sorted { $0.duration > $1.duration }

        let breakdown = DailyAppBreakdownData(
            date: dateString,
            apps: appMetrics
        )

        return (dailyStats, breakdown)
    }

    private func sendData(_ data: Data, to connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
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

    /// Get color hex for an app (from app_categories or generate)
    private func getBundleId(forAppName appName: String) -> String? {
        let selectedApps = dataSharingPreferences.selectedAppsList()
        return selectedApps.first(where: { $0.appName == appName })?.bundleIdentifier
    }

    private func getColorHex(bundleId: String?, appName: String) -> String? {
        // Try to get from app_categories first
        if let bundleId = bundleId, !bundleId.isEmpty {
            let repository = AppCategoryRepository()
            if let category = try? repository.getCategory(forBundleId: bundleId) {
                return "#" + category.color
            }
        }

        // Fallback to generator
        return AppColorGenerator.colorHex(forBundleIdentifier: bundleId ?? "", appName: appName)
    }
}
