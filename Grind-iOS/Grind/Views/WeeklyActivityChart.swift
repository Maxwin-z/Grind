//
//  WeeklyActivityChart.swift
//  Grind
//
//  7-day activity duration stacked area chart
//

import SwiftUI
import Charts

struct WeeklyActivityChart: View {
    let data: [DailyActivityChartData]
    let appMetadata: [String: SelectedAppData]
    @State private var selectedDate: Date?
    private var colorProvider: AppColorProvider {
        AppColorProvider(appMetadata: appMetadata)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Activity")
                .font(.headline)
                .foregroundColor(.primary)

            if data.isEmpty {
                emptyStateView
            } else {
                chartView
            }
        }
        .padding(16)
    }

    private var chartView: some View {
        Chart {
            ForEach(activitySeries) { series in
                ForEach(series.entries) { entry in
                    AreaMark(
                        x: .value("Date", entry.date),
                        y: .value("Duration", entry.minutes)
                    )
                    .foregroundStyle(by: .value("App", series.appName))
                    .position(by: .value("App", series.appName))
                    .interpolationMethod(.monotone)
                }
            }
            if let selectedDate {
                RuleMark(x: .value("Date", selectedDate))
                    .foregroundStyle(Color.secondary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }
        }
        .chartForegroundStyleScale(
            domain: uniqueApps,
            range: uniqueApps.map { styleForApp($0) }
        )
        .chartYScale(domain: 0...max(maxDailyActivityMinutes * 1.1, 5.0))
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text(formatMinutes(minutes))
                            .font(.caption)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 1)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatDateLabel(date))
                            .font(.caption)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .overlay(alignment: .topTrailing) {
            if let dateLabel = selectedDateLabel, !selectionRows.isEmpty {
                ChartSelectionSummaryCard(title: dateLabel, rows: selectionRows)
                    .padding(.top, 8)
                    .padding(.trailing, 8)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No activity data available")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Functions

    private var activityEntries: [ActivityEntry] {
        data.flatMap { dayData in
            dayData.appActivities.map { appActivity in
                ActivityEntry(
                    date: dateValue(dayData.date),
                    appName: appActivity.appName,
                    minutes: Double(appActivity.duration) / 60.0
                )
            }
        }
    }

    private var entriesByDate: [Date: [ActivityEntry]] {
        Dictionary(grouping: activityEntries, by: { $0.date })
    }

    private var activitySeries: [ActivitySeries] {
        let grouped = Dictionary(grouping: activityEntries, by: { $0.appName })
        let allDates = Set(data.map { dateValue($0.date) })

        return grouped.map { appName, entries in
            let existingDates = Dictionary(uniqueKeysWithValues: entries.map { ($0.date, $0.minutes) })

            // Fill missing dates with zero values
            let completeEntries = allDates.map { date in
                ActivityEntry(
                    date: date,
                    appName: appName,
                    minutes: existingDates[date] ?? 0.0
                )
            }.sorted { $0.date < $1.date }

            return ActivitySeries(appName: appName, entries: completeEntries)
        }
        .sorted { $0.appName < $1.appName }
    }

    private var uniqueApps: [String] {
        activitySeries.map { $0.appName }
    }

    private func dateValue(_ dateString: String) -> Date {
        Self.isoDateFormatter.date(from: dateString) ?? Date()
    }

    private var maxDailyActivityMinutes: Double {
        let dailyTotals = Dictionary(grouping: activityEntries, by: { $0.date })
            .mapValues { entries in
                entries.reduce(0.0) { $0 + $1.minutes }
            }
        return max(dailyTotals.values.max() ?? 5.0, 5.0)
    }

    private var selectedDateLabel: String? {
        guard let selectedDate else { return nil }
        return formatDateLabel(selectedDate)
    }

    private var selectionRows: [ChartSelectionSummaryRow] {
        guard let selectedDate, let entries = entriesByDate[selectedDate] else { return [] }
        return entries
            .sorted { $0.minutes > $1.minutes }
            .map { entry in
                ChartSelectionSummaryRow(
                    id: entry.appName,
                    color: colorProvider.color(for: entry.appName),
                    label: entry.appName,
                    value: formatDuration(minutes: entry.minutes)
                )
            }
    }

    private func formatDateLabel(_ date: Date) -> String {
        Self.dateLabelFormatter.string(from: date)
    }

    private func styleForApp(_ appName: String) -> LinearGradient {
        colorProvider.gradient(for: appName)
    }

    private struct ActivityEntry: Identifiable {
        let id = UUID()
        let date: Date
        let appName: String
        let minutes: Double
    }

    private struct ActivitySeries: Identifiable {
        let appName: String
        let entries: [ActivityEntry]
        var id: String { appName }
    }

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let dateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private func formatDuration(minutes: Double) -> String {
        let totalMinutes = Int(minutes.rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h > 0 && m > 0 {
            return "\(h)h \(m)m"
        } else if h > 0 {
            return "\(h)h"
        } else {
            return "\(m)m"
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        if minutes < 1.0 {
            return "0m"
        } else if minutes < 60.0 {
            return "\(Int(minutes.rounded()))m"
        } else {
            let hours = minutes / 60.0
            return String(format: "%.1fh", hours)
        }
    }
}

#if DEBUG
struct WeeklyActivityChart_Previews: PreviewProvider {
    static var previews: some View {
        WeeklyActivityChart(data: [
            DailyActivityChartData(
                date: "2025-11-11",
                appActivities: [
                    DailyActivityByApp(appName: "Xcode", duration: 14400),
                    DailyActivityByApp(appName: "Safari", duration: 7200)
                ]
            ),
            DailyActivityChartData(
                date: "2025-11-12",
                appActivities: [
                    DailyActivityByApp(appName: "Xcode", duration: 18000),
                    DailyActivityByApp(appName: "Safari", duration: 5400)
                ]
            )
        ],
        appMetadata: [
            "Xcode": SelectedAppData(
                bundleIdentifier: "com.apple.dt.Xcode",
                appName: "Xcode",
                accentColorHex: "#3A7AFE",
                iconPNGData: nil
            ),
            "Safari": SelectedAppData(
                bundleIdentifier: "com.apple.Safari",
                appName: "Safari",
                accentColorHex: "#34C759",
                iconPNGData: nil
            )
        ])
        .padding()
    }
}
#endif
