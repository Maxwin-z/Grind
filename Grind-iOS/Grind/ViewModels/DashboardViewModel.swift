//
//  DashboardViewModel.swift
//  Grind
//
//  View model for Dashboard data management
//

import Foundation
import Combine

class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isConnected = false
    @Published var connectionStatus = "Not connected"

    // Historical data (last 7 days)
    @Published var dailyActivityData: [DailyActivityChartData] = []
    @Published var dailyKeystrokeData: [DailyKeystrokeChartData] = []

    // Today's data
    @Published var todayTimeBlocks: [TimeBlock] = []
    @Published var appSelectionMetadata: [String: SelectedAppData] = [:]

    // Realtime data
    @Published var currentKPM: Int = 0
    @Published var currentApp: String = "—"
    @Published var isTyping: Bool = false

    // Current keystroke display
    @Published var currentKey: String = ""
    @Published var currentModifiers: [String] = []
    @Published var keystrokeSequence: UInt64 = 0
    @Published var iterm2Sessions: [ITerm2Session] = []

    // MARK: - Private Properties

    private let networkClient = NetworkClient.shared
    private var cancellables = Set<AnyCancellable>()
    private var latestHistoricalData: HistoricalStatsData?
    private var selectedAppNames: Set<String> = []
    private var selectedBundleIds: Set<String> = []
    private var didReceiveSelectionSnapshot = false

    // KPM calculation
    private var keystrokeTimestamps: [Date] = []
    private let kpmCalculationWindow: TimeInterval = 60.0  // 1 minute window
    private var kpmUpdateTimer: Timer?

    init() {
        setupBindings()
        connectToServer()
        startKPMTimer()
    }

    deinit {
        kpmUpdateTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Bind connection status
        networkClient.$isConnected
            .assign(to: &$isConnected)

        networkClient.$connectionStatus
            .assign(to: &$connectionStatus)

        // Process historical stats
        networkClient.$historicalStats
            .sink { [weak self] historicalData in
                guard let self = self, let historicalData = historicalData else { return }
                self.latestHistoricalData = historicalData
                self.recalculateHistoricalCharts()
            }
            .store(in: &cancellables)

        networkClient.$selectedApps
            .sink { [weak self] apps in
                guard let self = self else { return }
                self.selectedAppNames = Set(apps.map { $0.appName })
                self.selectedBundleIds = Set(apps.map { $0.bundleIdentifier })
                self.appSelectionMetadata = Dictionary(uniqueKeysWithValues: apps.map { ($0.appName, $0) })
                self.didReceiveSelectionSnapshot = true
                self.logAppMetadata(apps)
                self.recalculateHistoricalCharts()
            }
            .store(in: &cancellables)

        // Process time blocks
        networkClient.$timeBlocks
            .compactMap { $0 }
            .sink { [weak self] timeBlocksData in
                self?.processTimeBlocks(timeBlocksData)
            }
            .store(in: &cancellables)

        // Process incremental daily stats updates
        networkClient.$dailyStatsUpdate
            .compactMap { $0 }
            .sink { [weak self] update in
                self?.processDailyStatsUpdate(update)
            }
            .store(in: &cancellables)

        // Process realtime activity
        networkClient.$realtimeActivity
            .compactMap { $0 }
            .sink { [weak self] realtimeData in
                self?.processRealtimeActivity(realtimeData)
            }
            .store(in: &cancellables)

        // Process keystroke events
        networkClient.$latestKeystroke
            .compactMap { $0 }
            .sink { [weak self] keystrokeData in
                self?.processKeystroke(keystrokeData)
            }
            .store(in: &cancellables)

        networkClient.$iterm2Sessions
            .sink { [weak self] sessions in
                self?.processITerm2Sessions(sessions)
            }
            .store(in: &cancellables)
    }

    private func processITerm2Sessions(_ sessions: [ITerm2Session]) {
        guard !sessions.isEmpty else {
            iterm2Sessions = []
            return
        }

        iterm2Sessions = sessions.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }

            if lhs.windowIndex != rhs.windowIndex {
                return lhs.windowIndex < rhs.windowIndex
            }

            if lhs.tabIndex != rhs.tabIndex {
                return lhs.tabIndex < rhs.tabIndex
            }

            return lhs.paneIndex < rhs.paneIndex
        }
    }

    private func connectToServer() {
        // Start Bonjour discovery
        networkClient.startServiceDiscovery()
    }

    // MARK: - Data Processing

    private func recalculateHistoricalCharts() {
        guard let data = latestHistoricalData else { return }
        let filterBundleIds = didReceiveSelectionSnapshot ? selectedBundleIds : nil
        processHistoricalData(data, filterBundleIds: filterBundleIds)
    }

    private func processHistoricalData(_ data: HistoricalStatsData, filterBundleIds: Set<String>?) {
        print("📥 Processing historical data:")
        print("   Breakdown days: \(data.dailyAppBreakdown?.count ?? 0)")
        print("   Filter enabled: \(filterBundleIds != nil)")
        if let filterBundleIds = filterBundleIds {
            print("   Filter bundle IDs (\(filterBundleIds.count)): \(filterBundleIds.sorted().joined(separator: ", "))")
        }
        if let breakdown = data.dailyAppBreakdown?.prefix(3) {
            for (index, dayBreakdown) in breakdown.enumerated() {
                print("   Day \(index + 1) (\(dayBreakdown.date)): \(dayBreakdown.apps.count) apps")
                let appNames = dayBreakdown.apps.prefix(10).map { $0.appName }.joined(separator: ", ")
                print("      Apps: \(appNames)\(dayBreakdown.apps.count > 10 ? "... and \(dayBreakdown.apps.count - 10) more" : "")")
            }
        }

        // Process last 7 days for charts
        let last7Days = getLast7Days()
        let recentStats = data.dailyStats
            .sorted { $0.date < $1.date } // ensure chronological order
            .suffix(7)

        // Build per-day breakdown lookup from payload (if available)
        var perDayActivity: [String: [DailyActivityByApp]] = [:]
        var perDayKeystrokes: [String: [DailyKeystrokeByApp]] = [:]

        if let breakdown = data.dailyAppBreakdown {
            var allAppsInBreakdown = Set<String>()
            var filteredOutApps = Set<String>()

            for dayBreakdown in breakdown {
                let sortedActivityApps = dayBreakdown.apps.sorted { $0.duration > $1.duration }

                // Track all apps before filtering
                for app in sortedActivityApps {
                    allAppsInBreakdown.insert(app.appName)
                    if !shouldIncludeApp(bundleId: app.bundleId, appName: app.appName, filterBundleIds: filterBundleIds) {
                        filteredOutApps.insert(app.appName)
                    }
                }

                let activityApps = sortedActivityApps
                    .filter { shouldIncludeApp(bundleId: $0.bundleId, appName: $0.appName, filterBundleIds: filterBundleIds) }
                    .map { metric in
                        DailyActivityByApp(appName: metric.appName, duration: metric.duration)
                    }
                let sortedKeystrokeApps = dayBreakdown.apps.sorted { $0.keystrokes > $1.keystrokes }
                let keystrokeApps = sortedKeystrokeApps
                    .filter { shouldIncludeApp(bundleId: $0.bundleId, appName: $0.appName, filterBundleIds: filterBundleIds) }
                    .map { metric in
                        DailyKeystrokeByApp(appName: metric.appName, keystrokes: metric.keystrokes)
                    }

                if !activityApps.isEmpty {
                    perDayActivity[dayBreakdown.date] = activityApps
                }
                if !keystrokeApps.isEmpty {
                    perDayKeystrokes[dayBreakdown.date] = keystrokeApps
                }
            }

            // Log filtering results
            if filterBundleIds != nil && !filteredOutApps.isEmpty {
                print("⚠️  Apps filtered out (\(filteredOutApps.count)):")
                for appName in filteredOutApps.sorted() {
                    print("   ❌ '\(appName)' - bundle ID not in selected apps list")
                }
                print("   All apps in breakdown: \(allAppsInBreakdown.sorted().joined(separator: ", "))")
            }
        }

        // Fallback to totals if breakdown missing so the charts never go empty
        for dayStats in recentStats {
            let date = dayStats.date
            if filterBundleIds == nil {
                if perDayActivity[date]?.isEmpty ?? true {
                    perDayActivity[date] = [
                        DailyActivityByApp(appName: "Total", duration: dayStats.totalSeconds)
                    ]
                }
                if perDayKeystrokes[date]?.isEmpty ?? true {
                    perDayKeystrokes[date] = [
                        DailyKeystrokeByApp(appName: "Total", keystrokes: dayStats.totalKeystrokes)
                    ]
                }
            }
        }

        // Convert to chart data
        dailyActivityData = last7Days.map { dateStr in
            let apps = perDayActivity[dateStr] ?? []
            return DailyActivityChartData(date: dateStr, appActivities: apps)
        }

        dailyKeystrokeData = last7Days.map { dateStr in
            let apps = perDayKeystrokes[dateStr] ?? []
            return DailyKeystrokeChartData(date: dateStr, appKeystrokes: apps)
        }

        // Log final app counts
        let allActivityApps = Set(dailyActivityData.flatMap { $0.appActivities.map(\.appName) })
        let allKeystrokeApps = Set(dailyKeystrokeData.flatMap { $0.appKeystrokes.map(\.appName) })
        let allApps = allActivityApps.union(allKeystrokeApps).sorted()
        print("✅ Processed chart data:")
        print("   Total unique apps in activity chart: \(allActivityApps.count)")
        print("   Total unique apps in keystroke chart: \(allKeystrokeApps.count)")
        print("   Combined unique apps: \(allApps.count)")
        print("   App list: \(allApps.joined(separator: ", "))")

        logChartTables()
    }

    private func processRealtimeActivity(_ data: RealtimeActivityData) {
        currentApp = data.activeApp.appName
        isTyping = data.isTyping
    }

    private func processDailyStatsUpdate(_ update: DailyStatsUpdateData) {
        guard var historical = latestHistoricalData else {
            return
        }


        var updatedStats = historical.dailyStats.filter { $0.date != update.dailyStats.date }
        updatedStats.append(update.dailyStats)
        updatedStats.sort { $0.date < $1.date }

        var updatedBreakdown = historical.dailyAppBreakdown ?? []
        updatedBreakdown.removeAll { $0.date == update.dailyStats.date }
        if let breakdown = update.dailyAppBreakdown {
            updatedBreakdown.append(breakdown)
            updatedBreakdown.sort { $0.date < $1.date }
        }

        historical = HistoricalStatsData(
            dailyStats: updatedStats,
            topApps: historical.topApps,
            dailyAppBreakdown: updatedBreakdown
        )

        latestHistoricalData = historical
        recalculateHistoricalCharts()
    }

    private func processKeystroke(_ data: KeystrokeData) {
        currentKey = data.key
        currentModifiers = data.modifiers
        keystrokeSequence &+= 1

        // Record keystroke timestamp for KPM calculation
        let now = Date()
        keystrokeTimestamps.append(now)

        // Remove timestamps older than 1 minute
        let cutoffTime = now.addingTimeInterval(-kpmCalculationWindow)
        keystrokeTimestamps.removeAll { $0 < cutoffTime }

        // Update KPM immediately
        updateKPM()
    }

    private func processTimeBlocks(_ data: TimeBlocksData) {

        // Convert TimeBlockData to TimeBlock for the view
        todayTimeBlocks = data.blocks.map { block in
            TimeBlock(
                blockStart: block.blockStart,
                hasActivity: block.duration > 0,
                appName: block.appName,
                duration: block.duration,
                keystrokes: block.keystrokes
            )
        }

        let activeBlocks = todayTimeBlocks.filter { $0.hasActivity }.count
    }

    // MARK: - Helper Functions

    private func getLast7Days() -> [String] {
        let calendar = Calendar.current
        let today = Date()

        return (0..<7).compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }.reversed()
    }

    func refreshData() {
        // Reconnect to fetch latest data
        networkClient.disconnect()
        networkClient.startServiceDiscovery()
        didReceiveSelectionSnapshot = false
        selectedAppNames = []
        selectedBundleIds = []
    }

    // MARK: - KPM Calculation

    private func startKPMTimer() {
        // Update KPM every second to keep it fresh
        // Run on main thread to avoid issues
        DispatchQueue.main.async { [weak self] in
            self?.kpmUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.updateKPM()
            }
            // Add to common run loop mode to ensure it runs during UI updates
            if let timer = self?.kpmUpdateTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    private func updateKPM() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let now = Date()
            let cutoffTime = now.addingTimeInterval(-self.kpmCalculationWindow)

            // Remove old timestamps
            self.keystrokeTimestamps.removeAll { $0 < cutoffTime }

            // Calculate KPM based on keystrokes in the last minute
            self.currentKPM = self.keystrokeTimestamps.count

            // If no recent keystrokes, set to 0
            if self.keystrokeTimestamps.isEmpty {
                self.currentKPM = 0
            }
        }
    }

    private func shouldIncludeApp(bundleId: String?, appName: String, filterBundleIds: Set<String>?) -> Bool {
        guard let filterBundleIds = filterBundleIds else { return true }

        // Prefer bundle ID matching (most reliable)
        if let bundleId = bundleId, !bundleId.isEmpty {
            return filterBundleIds.contains(bundleId)
        }

        // Fallback to app name matching (case-insensitive) for apps without bundle ID
        return selectedAppNames.contains { $0.caseInsensitiveCompare(appName) == .orderedSame }
    }

    private func logChartTables() {
        logActivityTable()
        logKeystrokeTable()
    }

    private func logAppMetadata(_ apps: [SelectedAppData]) {
        guard !apps.isEmpty else { return }
        for app in apps.sorted(by: { $0.appName < $1.appName }) {
            let hasIcon = app.iconPNGData == nil ? "no" : "yes"
        }
    }

    private func logActivityTable() {
        guard !dailyActivityData.isEmpty else { return }
        let apps = Set(dailyActivityData.flatMap { $0.appActivities.map(\.appName) }).sorted()

        for day in dailyActivityData {
            let values = apps.map { appName in
                day.appActivities.first { $0.appName == appName }?.duration ?? 0
            }
        }
    }

    private func logKeystrokeTable() {
        guard !dailyKeystrokeData.isEmpty else { return }
        let apps = Set(dailyKeystrokeData.flatMap { $0.appKeystrokes.map(\.appName) }).sorted()

        for day in dailyKeystrokeData {
            let values = apps.map { appName in
                day.appKeystrokes.first { $0.appName == appName }?.keystrokes ?? 0
            }
        }
    }

    private func tableHeader(for apps: [String]) -> String {
        guard !apps.isEmpty else { return "date" }
        return "date, " + apps.joined(separator: ", ")
    }

    private func tableRow(for date: String, values: [Int]) -> String {
        guard !values.isEmpty else { return formattedDumpDate(from: date) }
        let joinedValues = values.map { "\($0)" }.joined(separator: ", ")
        return "\(formattedDumpDate(from: date)), \(joinedValues)"
    }

    private func formattedDumpDate(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        formatter.dateFormat = "MMdd"
        return formatter.string(from: date)
    }
}

// MARK: - Chart Data Models

struct DailyActivityChartData: Identifiable {
    let id = UUID()
    let date: String
    let appActivities: [DailyActivityByApp]
}

struct DailyActivityByApp: Identifiable {
    let id = UUID()
    let appName: String
    let duration: Int  // seconds
}

struct DailyKeystrokeChartData: Identifiable {
    let id = UUID()
    let date: String
    let appKeystrokes: [DailyKeystrokeByApp]
}

struct DailyKeystrokeByApp: Identifiable {
    let id = UUID()
    let appName: String
    let keystrokes: Int
}

struct TimeBlock: Identifiable {
    let id = UUID()
    let blockStart: Date
    let hasActivity: Bool
    let appName: String?
    let duration: Int
    let keystrokes: Int
}
