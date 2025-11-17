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
        Chart(keystrokeEntries) { entry in
            AreaMark(
                x: .value("Date", formatDate(entry.date)),
                y: .value("Keystrokes", entry.thousands)
            )
            .foregroundStyle(by: .value("App", entry.appName))
            .interpolationMethod(.catmullRom)
            .foregroundStyle(colorForApp(entry.appName))
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let thousands = value.as(Double.self) {
                        Text("\(Int(thousands))K")
                            .font(.caption)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(String.self) {
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
                KeystrokeEntry(date: dayData.date, appName: appKeystroke.appName, thousands: Double(appKeystroke.keystrokes) / 1000.0)
            }
        }
    }

    private var uniqueApps: [String] {
        let allApps = data.flatMap { $0.appKeystrokes.map { $0.appName } }
        return Array(Set(allApps)).sorted()
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func formatShortDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        guard let date = formatter.date(from: dateString) else { return dateString }

        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func colorForApp(_ appName: String) -> Color {
        if let metadata = metadata(for: appName) {
            return Color(hex: metadata.accentColorHex, fallback: fallbackColor(for: appName))
        }
        return fallbackColor(for: appName)
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
            .blue, .green, .orange, .purple, .pink,
            .red, .yellow, .teal, .indigo, .cyan
        ]
        return colors[hash % colors.count]
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
        let date: String
        let appName: String
        let thousands: Double
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
