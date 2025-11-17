//
//  WeeklyActivityChart.swift
//  Grind
//
//  7-day activity duration stacked area chart
//

import SwiftUI
import Charts
import UIKit

struct WeeklyActivityChart: View {
    let data: [DailyActivityChartData]
    let appMetadata: [String: SelectedAppData]

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
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var chartView: some View {
        Chart {
            ForEach(activitySeries) { series in
                ForEach(series.entries) { entry in
                    AreaMark(
                        x: .value("Date", entry.date),
                        y: .value("Duration", entry.hours)
                    )
                    .foregroundStyle(by: .value("App", series.appName))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartForegroundStyleScale(
            domain: uniqueApps,
            range: uniqueApps.map { styleForApp($0) }
        )
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(Int(hours))h")
                            .font(.caption)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatShortDate(date))
                            .font(.caption)
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading) {
            legendView
        }
        .frame(height: 220)
    }

    private var legendView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(legendEntries, id: \.appName) { entry in
                    HStack(spacing: 6) {
                        legendIcon(for: entry)
                        Text(entry.appName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(height: 24)
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
        .frame(height: 220)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helper Functions

    private var activityEntries: [ActivityEntry] {
        data.flatMap { dayData in
            dayData.appActivities.map { appActivity in
                ActivityEntry(
                    date: dateValue(dayData.date),
                    appName: appActivity.appName,
                    hours: Double(appActivity.duration) / 3600.0
                )
            }
        }
    }

    private var activitySeries: [ActivitySeries] {
        let grouped = Dictionary(grouping: activityEntries, by: { $0.appName })
        return grouped.map { appName, entries in
            ActivitySeries(appName: appName, entries: entries.sorted { $0.date < $1.date })
        }
        .sorted { $0.appName < $1.appName }
    }

    private var uniqueApps: [String] {
        activitySeries.map { $0.appName }
    }

    private func dateValue(_ dateString: String) -> Date {
        Self.isoDateFormatter.date(from: dateString) ?? Date()
    }

    private func formatShortDate(_ date: Date) -> String {
        Self.weekdayFormatter.string(from: date)
    }

    private func colorForApp(_ appName: String) -> Color {
        if let metadata = metadata(for: appName) {
            return Color(hex: metadata.accentColorHex, fallback: fallbackColor(for: appName)).boostedForCharts()
        }
        return fallbackColor(for: appName).boostedForCharts()
    }

    private func metadata(for appName: String) -> SelectedAppData? {
        if let direct = appMetadata[appName] {
            return direct
        }
        return appMetadata.first { $0.key.caseInsensitiveCompare(appName) == .orderedSame }?.value
    }

    private func fallbackColor(for appName: String) -> Color {
        let hash = abs(appName.hashValue)
        let colors: [Color] = [
            Color(red: 0.95, green: 0.35, blue: 0.2),
            Color(red: 0.95, green: 0.55, blue: 0.15),
            Color(red: 0.2, green: 0.6, blue: 0.95),
            Color(red: 0.3, green: 0.75, blue: 0.4),
            Color(red: 0.7, green: 0.4, blue: 0.9),
            Color(red: 1.0, green: 0.2, blue: 0.5),
            Color(red: 0.2, green: 0.85, blue: 0.7),
            Color(red: 0.98, green: 0.6, blue: 0.2),
            Color(red: 0.4, green: 0.5, blue: 0.95),
            Color(red: 0.25, green: 0.9, blue: 0.5)
        ]
        return colors[hash % colors.count]
    }

    private func styleForApp(_ appName: String) -> LinearGradient {
        let color = colorForApp(appName)
        let lighter = color.opacity(0.9)
        let darker = color.opacity(0.55)
        return LinearGradient(colors: [lighter, darker], startPoint: .top, endPoint: .bottom)
    }

    private var legendEntries: [LegendEntry] {
        uniqueApps.map { appName in
            LegendEntry(appName: appName, color: colorForApp(appName), icon: iconForApp(appName))
        }
    }

    private func iconForApp(_ appName: String) -> UIImage? {
        guard let data = metadata(for: appName)?.iconPNGData else {
            return nil
        }
        return UIImage(data: data)
    }

    @ViewBuilder
    private func legendIcon(for entry: LegendEntry) -> some View {
        if let icon = entry.icon {
            Image(uiImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(entry.color.opacity(0.7), lineWidth: 1)
                )
        } else {
            Circle()
                .fill(entry.color)
                .frame(width: 10, height: 10)
        }
    }

    private struct LegendEntry {
        let appName: String
        let color: Color
        let icon: UIImage?
    }

    private struct ActivityEntry: Identifiable {
        let id = UUID()
        let date: Date
        let appName: String
        let hours: Double
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

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
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
