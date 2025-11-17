//
//  WeeklyKeystrokeChart.swift
//  Grind
//
//  7-day keystroke count stacked area chart
//

import SwiftUI
import Charts

struct WeeklyKeystrokeChart: View {
    let data: [DailyKeystrokeChartData]

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
            ForEach(data) { dayData in
                ForEach(dayData.appKeystrokes) { appKeystroke in
                    AreaMark(
                        x: .value("Date", formatDate(dayData.date)),
                        y: .value("Keystrokes", Double(appKeystroke.keystrokes) / 1000.0)  // Convert to thousands
                    )
                    .foregroundStyle(by: .value("App", appKeystroke.appName))
                    .interpolationMethod(.catmullRom)
                }
            }
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
                ForEach(uniqueApps, id: \.self) { appName in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colorForApp(appName))
                            .frame(width: 10, height: 10)
                        Text(appName)
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
        // Generate consistent color for each app
        let hash = abs(appName.hashValue)
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink,
            .red, .yellow, .teal, .indigo, .cyan
        ]
        return colors[hash % colors.count]
    }
}

#Preview {
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
    ])
    .padding()
}
