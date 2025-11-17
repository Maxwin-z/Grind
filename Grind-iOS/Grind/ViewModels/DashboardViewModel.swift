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
    @Published var todayTimeBlocks: [TimeBlockData] = []

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
        // Process last 7 days for activity chart
        let last7Days = getLast7Days()
        var activityByDate: [String: [DailyActivityByApp]] = [:]

        // Group top apps data by date (we need to request this data from macOS)
        // For now, use dailyStats as placeholder
        for dayStats in data.dailyStats.suffix(7) {
            let date = dayStats.date
            // This is a simplified version - in reality we need per-app breakdown
            activityByDate[date] = [
                DailyActivityByApp(appName: "Total", duration: dayStats.totalSeconds)
            ]
        }

        // Convert to chart data
        dailyActivityData = last7Days.map { dateStr in
            let apps = activityByDate[dateStr] ?? []
            return DailyActivityChartData(date: dateStr, appActivities: apps)
        }

        // Process keystroke data similarly
        var keystrokesByDate: [String: [DailyKeystrokeByApp]] = [:]

        for dayStats in data.dailyStats.suffix(7) {
            let date = dayStats.date
            keystrokesByDate[date] = [
                DailyKeystrokeByApp(appName: "Total", keystrokes: dayStats.totalKeystrokes)
            ]
        }

        dailyKeystrokeData = last7Days.map { dateStr in
            let apps = keystrokesByDate[dateStr] ?? []
            return DailyKeystrokeChartData(date: dateStr, appKeystrokes: apps)
        }

        print("📊 Processed \(dailyActivityData.count) days of activity data")
    }

    private func processRealtimeActivity(_ data: RealtimeActivityData) {
        currentApp = data.activeApp.appName
        isTyping = data.isTyping
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

struct TimeBlockData: Identifiable {
    let id = UUID()
    let blockStart: Date
    let hasActivity: Bool
}
