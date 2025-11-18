//
//  TodayTimelineView.swift
//  Grind
//
//  24-hour activity timeline with 5-minute granularity
//

import SwiftUI

struct TodayTimelineView: View {
    let timeBlocks: [TimeBlock]

    private let hoursInDay = 24
    private let blocksPerHour = 12  // 5-minute blocks per hour

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today's Activity Timeline (\(formattedTotalHours))")
                .font(.headline)
                .foregroundColor(.primary)

            if timeBlocks.isEmpty {
                emptyStateView
            } else {
                timelineView
            }
        }
        .padding(16)
    }

    private var timelineView: some View {
        VStack(spacing: 8) {
            // Hour labels
            HStack(spacing: 0) {
                ForEach(0..<hoursInDay, id: \.self) { hour in
                    if hour % 3 == 0 {
                        Text(String(format: "%02d:00", hour))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            // Activity blocks
            GeometryReader { geometry in
                let totalBlocks = hoursInDay * blocksPerHour
                let blockWidth = geometry.size.width / CGFloat(totalBlocks)

                HStack(spacing: 0) {
                    ForEach(0..<totalBlocks, id: \.self) { blockIndex in
                        let hour = blockIndex / blocksPerHour
                        let minute = (blockIndex % blocksPerHour) * 5
                        let hasActivity = hasActivityAt(hour: hour, minute: minute)

                        Rectangle()
                            .fill(hasActivity ? Color.blue : Color.gray.opacity(0.2))
                            .frame(width: blockWidth, height: 40)
                    }
                }
            }
            .frame(height: 40)
            .cornerRadius(4)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No activity data for today")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed Properties

    private var totalActivityHours: Double {
        let totalSeconds = timeBlocks
            .filter { $0.hasActivity }
            .reduce(0) { $0 + $1.duration }
        return Double(totalSeconds) / 3600.0
    }

    private var formattedTotalHours: String {
        String(format: "%.1f h", totalActivityHours)
    }

    // MARK: - Helper Functions

    private func hasActivityAt(hour: Int, minute: Int) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let targetTime = calendar.date(byAdding: .hour, value: hour, to: today),
              let targetTimeWithMinute = calendar.date(byAdding: .minute, value: minute, to: targetTime) else {
            return false
        }

        // Round to 5-minute boundary
        let roundedTarget = roundTo5Minutes(targetTimeWithMinute)

        // Check if any block matches this time
        return timeBlocks.contains { block in
            let roundedBlock = roundTo5Minutes(block.blockStart)
            return roundedBlock == roundedTarget && block.hasActivity
        }
    }

    private func roundTo5Minutes(_ date: Date) -> Date {
        let timestamp = date.timeIntervalSince1970
        let rounded = floor(timestamp / 300) * 300
        return Date(timeIntervalSince1970: rounded)
    }
}

#if DEBUG
struct TodayTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let sampleBlocks = [
            TimeBlock(
                blockStart: calendar.date(byAdding: .hour, value: 9, to: today)!,
                hasActivity: true,
                appName: "Xcode",
                duration: 300,
                keystrokes: 45
            ),
            TimeBlock(
                blockStart: calendar.date(byAdding: .minute, value: 545, to: today)!,  // 9:05
                hasActivity: true,
                appName: "Xcode",
                duration: 300,
                keystrokes: 52
            ),
            TimeBlock(
                blockStart: calendar.date(byAdding: .hour, value: 14, to: today)!,
                hasActivity: true,
                appName: "Safari",
                duration: 180,
                keystrokes: 23
            ),
            TimeBlock(
                blockStart: calendar.date(byAdding: .minute, value: 900, to: today)!,  // 15:00
                hasActivity: true,
                appName: "Terminal",
                duration: 240,
                keystrokes: 67
            )
        ]

        return TodayTimelineView(timeBlocks: sampleBlocks)
            .padding()
    }
}
#endif
