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
            ForEach(data) { dayData in
                ForEach(dayData.appActivities) { appActivity in
                    AreaMark(
                        x: .value("Date", formatDate(dayData.date)),
                        y: .value("Duration", Double(appActivity.duration) / 3600.0)  // Convert to hours
                    )
                    .foregroundStyle(by: .value("App", appActivity.appName))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
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

    private var uniqueApps: [String] {
        let allApps = data.flatMap { $0.appActivities.map { $0.appName } }
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
    ])
    .padding()
}
