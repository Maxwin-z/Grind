//
//  WeeklyKeystrokeChart.swift
//  Grind
//
//  7-day keystroke count stacked area chart
//

import SwiftUI
import Charts
import UIKit

struct WeeklyKeystrokeChart: View {
    let data: [DailyKeystrokeChartData]
    let appMetadata: [String: SelectedAppData]
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Keystrokes")
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
            ForEach(keystrokeSeries) { series in
                ForEach(series.entries) { entry in
                    AreaMark(
                        x: .value("Date", entry.date),
                        y: .value("Keystrokes", Double(entry.count))
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
        .chartYScale(domain: 0...max(Double(maxDailyKeystrokes) * 1.1, 10.0))
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let count = value.as(Double.self) {
                        Text(formatKeystrokeCount(Int(count)))
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
        .chartLegend(position: .bottom, alignment: .leading) {
            legendView
        }
        .frame(height: 220)
        .overlay(alignment: .topTrailing) {
            if let dateLabel = selectedDateLabel, !selectionRows.isEmpty {
                ChartSelectionSummaryCard(title: dateLabel, rows: selectionRows)
                    .padding(.top, 8)
                    .padding(.trailing, 8)
            }
        }
    }

    private var legendView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(legendEntries, id: \.appName) { entry in
                    HStack(spacing: 6) {
                        legendIcon(for: entry)
                        Text(entry.appName)
                            .font(.caption)
                            .foregroundColor(entry.color)
                    }
                }
            }
        }
        .frame(height: 24)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No keystroke data available")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helper Functions

    private var keystrokeEntries: [KeystrokeEntry] {
        data.flatMap { dayData in
            dayData.appKeystrokes.map { appKeystroke in
                KeystrokeEntry(
                    date: dateValue(dayData.date),
                    appName: appKeystroke.appName,
                    count: appKeystroke.keystrokes
                )
            }
        }
    }

    private var entriesByDate: [Date: [KeystrokeEntry]] {
        Dictionary(grouping: keystrokeEntries, by: { $0.date })
    }

    private var keystrokeSeries: [KeystrokeSeries] {
        let grouped = Dictionary(grouping: keystrokeEntries, by: { $0.appName })
        let allDates = Set(data.map { dateValue($0.date) })

        return grouped.map { appName, entries in
            let existingDates = Dictionary(uniqueKeysWithValues: entries.map { ($0.date, $0.count) })

            // Fill missing dates with zero values
            let completeEntries = allDates.map { date in
                KeystrokeEntry(
                    date: date,
                    appName: appName,
                    count: existingDates[date] ?? 0
                )
            }.sorted { $0.date < $1.date }

            return KeystrokeSeries(appName: appName, entries: completeEntries)
        }
        .sorted { $0.appName < $1.appName }
    }

    private var uniqueApps: [String] {
        keystrokeSeries.map { $0.appName }
    }

    private func dateValue(_ dateString: String) -> Date {
        Self.isoDateFormatter.date(from: dateString) ?? Date()
    }

    private var maxDailyKeystrokes: Int {
        let dailyTotals = Dictionary(grouping: keystrokeEntries, by: { $0.date })
            .mapValues { entries in
                entries.reduce(0) { $0 + $1.count }
            }
        return max(dailyTotals.values.max() ?? 10, 10)
    }

    private var selectedDateLabel: String? {
        guard let selectedDate else { return nil }
        return formatDateLabel(selectedDate)
    }

    private var selectionRows: [ChartSelectionSummaryRow] {
        guard let selectedDate, let entries = entriesByDate[selectedDate] else { return [] }
        return entries
            .sorted { $0.count > $1.count }
            .map { entry in
                ChartSelectionSummaryRow(
                    id: entry.appName,
                    color: colorForApp(entry.appName),
                    label: entry.appName,
                    value: formatKeystrokes(entry.count)
                )
            }
    }

    private func formatDateLabel(_ date: Date) -> String {
        Self.dateLabelFormatter.string(from: date)
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

    private struct KeystrokeEntry: Identifiable {
        let id = UUID()
        let date: Date
        let appName: String
        let count: Int
    }

    private struct KeystrokeSeries: Identifiable {
        let appName: String
        let entries: [KeystrokeEntry]
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

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private func formatKeystrokes(_ count: Int) -> String {
        let formatted = Self.decimalFormatter.string(from: NSNumber(value: count)) ?? "\(count)"
        return "\(formatted) keys"
    }

    private func formatKeystrokeCount(_ count: Int) -> String {
        if count < 1000 {
            return "\(count)"
        } else if count < 10000 {
            let thousands = Double(count) / 1000.0
            return String(format: "%.1fK", thousands)
        } else {
            let thousands = count / 1000
            return "\(thousands)K"
        }
    }
}

#if DEBUG
struct WeeklyKeystrokeChart_Previews: PreviewProvider {
    static var previews: some View {
        WeeklyKeystrokeChart(data: [
            DailyKeystrokeChartData(
                date: "2025-11-11",
                appKeystrokes: [
                    DailyKeystrokeByApp(appName: "Xcode", keystrokes: 12500),
                    DailyKeystrokeByApp(appName: "Notes", keystrokes: 3200)
                ]
            ),
            DailyKeystrokeChartData(
                date: "2025-11-12",
                appKeystrokes: [
                    DailyKeystrokeByApp(appName: "Xcode", keystrokes: 15800),
                    DailyKeystrokeByApp(appName: "Notes", keystrokes: 2700)
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
            "Notes": SelectedAppData(
                bundleIdentifier: "com.apple.Notes",
                appName: "Notes",
                accentColorHex: "#FF9500",
                iconPNGData: nil
            )
        ])
        .padding()
    }
}
#endif
