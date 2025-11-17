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

    // Realtime data
    @Published var currentKPM: Int = 0
    @Published var currentApp: String = "—"
    @Published var isTyping: Bool = false

    // MARK: - Private Properties

    private let networkClient = NetworkClient.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
        connectToServer()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Bind connection status
        networkClient.$isConnected
            .assign(to: &$isConnected)

        networkClient.$connectionStatus
            .assign(to: &$connectionStatus)

        // Bind KPM
        networkClient.$currentKPM
            .assign(to: &$currentKPM)

        // Process historical stats
        networkClient.$historicalStats
            .compactMap { $0 }
            .sink { [weak self] historicalData in
                self?.processHistoricalData(historicalData)
            }
            .store(in: &cancellables)

        // Process time blocks
        networkClient.$timeBlocks
            .compactMap { $0 }
            .sink { [weak self] timeBlocksData in
                self?.processTimeBlocks(timeBlocksData)
            }
            .store(in: &cancellables)

        // Process realtime activity
        networkClient.$realtimeActivity
            .compactMap { $0 }
            .sink { [weak self] realtimeData in
                self?.processRealtimeActivity(realtimeData)
            }
            .store(in: &cancellables)
    }

    private func connectToServer() {
        // Start Bonjour discovery
        networkClient.startServiceDiscovery()
    }

    // MARK: - Data Processing

    private func processHistoricalData(_ data: HistoricalStatsData) {
        print("📊 Processing historical data...")
        print("   - Received \(data.dailyStats.count) daily stats")
        print("   - Received \(data.topApps.count) top apps")

        // Process last 7 days for charts
        let last7Days = getLast7Days()
        let recentStats = data.dailyStats
            .sorted { $0.date < $1.date } // ensure chronological order
            .suffix(7)

        // Build per-day breakdown lookup from payload (if available)
        var perDayActivity: [String: [DailyActivityByApp]] = [:]
        var perDayKeystrokes: [String: [DailyKeystrokeByApp]] = [:]

        if let breakdown = data.dailyAppBreakdown {
            for dayBreakdown in breakdown {
                let sortedActivityApps = dayBreakdown.apps.sorted { $0.duration > $1.duration }
                let activityApps = sortedActivityApps.map { metric in
                    DailyActivityByApp(appName: metric.appName, duration: metric.duration)
                }
                let sortedKeystrokeApps = dayBreakdown.apps.sorted { $0.keystrokes > $1.keystrokes }
                let keystrokeApps = sortedKeystrokeApps.map { metric in
                    DailyKeystrokeByApp(appName: metric.appName, keystrokes: metric.keystrokes)
                }

                if !activityApps.isEmpty {
                    perDayActivity[dayBreakdown.date] = activityApps
                }
                if !keystrokeApps.isEmpty {
                    perDayKeystrokes[dayBreakdown.date] = keystrokeApps
                }
            }
        }

        // Fallback to totals if breakdown missing so the charts never go empty
        for dayStats in recentStats {
            let date = dayStats.date
            print("   - Day \(date): \(dayStats.totalSeconds)s, \(dayStats.totalKeystrokes) keys")
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

        // Convert to chart data
        dailyActivityData = last7Days.map { dateStr in
            let apps = perDayActivity[dateStr] ?? []
            return DailyActivityChartData(date: dateStr, appActivities: apps)
        }

        dailyKeystrokeData = last7Days.map { dateStr in
            let apps = perDayKeystrokes[dateStr] ?? []
            return DailyKeystrokeChartData(date: dateStr, appKeystrokes: apps)
        }

        print("✅ Processed \(dailyActivityData.count) days of activity data")
        print("✅ Activity data has \(dailyActivityData.filter { !$0.appActivities.isEmpty }.count) days with data")
        print("✅ Keystroke data has \(dailyKeystrokeData.filter { !$0.appKeystrokes.isEmpty }.count) days with data")
    }

    private func processRealtimeActivity(_ data: RealtimeActivityData) {
        currentApp = data.activeApp.appName
        isTyping = data.isTyping
    }

    private func processTimeBlocks(_ data: TimeBlocksData) {
        print("📅 Processing time blocks for \(data.date)...")
        print("   - Received \(data.blocks.count) time blocks")

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
        print("✅ Processed \(todayTimeBlocks.count) time blocks (\(activeBlocks) with activity)")
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
