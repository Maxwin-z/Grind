//
//  DashboardView.swift
//  Grind
//
//  Main dashboard view integrating all chart components
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    // MARK: - Layout Constants
    private let padding: CGFloat = 16

    private var legendAppNames: [String] {
        let activityApps = viewModel.dailyActivityData.flatMap { day in
            day.appActivities.map(\.appName)
        }
        let keystrokeApps = viewModel.dailyKeystrokeData.flatMap { day in
            day.appKeystrokes.map(\.appName)
        }
        let combined = Set(activityApps + keystrokeApps)
        return combined.sorted()
    }

    var body: some View {
        GeometryReader { screen in
            let layout = calculateLayout(screenWidth: screen.size.width, screenHeight: screen.size.height)

            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea(.all, edges: .all)

                // All views positioned absolutely
                dashboardContent(layout: layout)
            }
        }
    }

    // MARK: - Absolute Positioned Layout

    @ViewBuilder
    private func dashboardContent(layout: DashboardLayout) -> some View {
        ZStack(alignment: .topLeading) {
            // 1. Today's Activity Timeline (top, full width)
            TodayTimelineView(timeBlocks: viewModel.todayTimeBlocks)
                .frame(width: layout.timelineWidth, height: layout.timelineHeight)
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .position(
                    x: layout.timelineX,
                    y: layout.timelineY
                )

            // 2. App Legend (left column, below timeline)
            AppLegendListView(
                appNames: legendAppNames,
                appMetadata: viewModel.appSelectionMetadata
            )
            .frame(width: layout.appListWidth, height: layout.appListHeight)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .position(
                x: layout.appListX,
                y: layout.appListY
            )

            // 3. Weekly Activity Chart (left column, below app legend)
            WeeklyActivityChart(
                data: viewModel.dailyActivityData,
                appMetadata: viewModel.appSelectionMetadata
            )
            .frame(width: layout.chartWidth, height: layout.chartHeight)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .position(
                x: layout.activityChartX,
                y: layout.activityChartY
            )

            // 4. Weekly Keystroke Chart (left column, below activity chart)
            WeeklyKeystrokeChart(
                data: viewModel.dailyKeystrokeData,
                appMetadata: viewModel.appSelectionMetadata
            )
            .frame(width: layout.chartWidth, height: layout.chartHeight)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .position(
                x: layout.keystrokeChartX,
                y: layout.keystrokeChartY
            )

            // 5. iTerm2 Terminal View (right column, below timeline)
            ITerm2TerminalListView(sessions: viewModel.iterm2Sessions)
                .frame(width: layout.iterm2Width, height: layout.iterm2Height)
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .position(
                    x: layout.iterm2X,
                    y: layout.iterm2Y
                )

            // 6. Typing Speed (right column, bottom left)
            TypingSpeedCompactView(kpm: viewModel.currentKPM)
                .frame(width: layout.typingSpeedSize, height: layout.typingSpeedSize)
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .position(
                    x: layout.typingSpeedX,
                    y: layout.typingSpeedY
                )

            // 7. Keyboard Visualizer (right column, bottom right)
            KeyboardVisualizerView(
                currentKey: viewModel.currentKey,
                currentModifiers: viewModel.currentModifiers,
                keystrokeSequence: viewModel.keystrokeSequence
            )
            .frame(width: layout.keyboardWidth, height: layout.keyboardHeight)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .position(
                x: layout.keyboardX,
                y: layout.keyboardY
            )

            // 8. Floating connection status and refresh button (top-right)
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .shadow(color: (viewModel.isConnected ? Color.green : Color.red).opacity(0.5), radius: 3, x: 0, y: 0)

                Button(action: {
                    viewModel.refreshData()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemBackground).opacity(0.9))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
                }
            }
            .position(
                x: layout.statusX,
                y: layout.statusY
            )
        }
    }

}

// MARK: - Layout Helpers

private struct DashboardLayout {
    // Dimensions
    let timelineWidth: CGFloat
    let timelineHeight: CGFloat
    let keyboardWidth: CGFloat
    let keyboardHeight: CGFloat
    let typingSpeedSize: CGFloat
    let iterm2Width: CGFloat
    let iterm2Height: CGFloat
    let appListWidth: CGFloat
    let appListHeight: CGFloat
    let chartWidth: CGFloat
    let chartHeight: CGFloat

    // Absolute positions (center points for .position())
    let timelineX: CGFloat
    let timelineY: CGFloat
    let appListX: CGFloat
    let appListY: CGFloat
    let activityChartX: CGFloat
    let activityChartY: CGFloat
    let keystrokeChartX: CGFloat
    let keystrokeChartY: CGFloat
    let iterm2X: CGFloat
    let iterm2Y: CGFloat
    let typingSpeedX: CGFloat
    let typingSpeedY: CGFloat
    let keyboardX: CGFloat
    let keyboardY: CGFloat
    let statusX: CGFloat
    let statusY: CGFloat
}

extension DashboardView {
    private func calculateLayout(screenWidth: CGFloat, screenHeight: CGFloat) -> DashboardLayout {
        // Fixed layout for screen size 1180 x 795
        // All spacing between views = 16px (consistent padding)
        // Keyboard width = 500 (fixed), height = 200 (5:2 aspect ratio)

        // Dimensions (hardcoded)
        let timelineWidth: CGFloat = 1148        // 1180 - 16*2
        let timelineHeight: CGFloat = 180
        let keyboardWidth: CGFloat = 500
        let keyboardHeight: CGFloat = 200        // 500 * 2/5
        let typingSpeedSize: CGFloat = 200       // = keyboard height
        let iterm2Width: CGFloat = 716           // 200 + 16 + 500
        let iterm2Height: CGFloat = 351          // 795 - 180 - 200 - 16*4
        let appListWidth: CGFloat = 416          // 1180 - 716 - 16*3
        let appListHeight: CGFloat = 150
        let chartWidth: CGFloat = 416            // = appListWidth
        let chartHeight: CGFloat = 192.5         // (795 - 180 - 150 - 16*5) / 2

        // Absolute positions (center points for .position())
        // All calculated to ensure 16px spacing between all views
        let timelineX: CGFloat = 590             // 1180 / 2
        let timelineY: CGFloat = 106             // 16 + 180/2
        let leftColumnX: CGFloat = 224           // 16 + 416/2
        let appListY: CGFloat = 287              // 16 + 180 + 16 + 150/2
        let activityChartY: CGFloat = 474.25     // 16 + 180 + 16 + 150 + 16 + 192.5/2
        let keystrokeChartY: CGFloat = 682.75    // 16 + 180 + 16 + 150 + 16 + 192.5 + 16 + 192.5/2
        let rightColumnX: CGFloat = 806          // 16 + 416 + 16 + 716/2
        let iterm2Y: CGFloat = 387.5             // 16 + 180 + 16 + 351/2
        let typingSpeedX: CGFloat = 548          // 16 + 416 + 16 + 200/2
        let typingSpeedY: CGFloat = 679          // 795 - 16 - 200/2
        let keyboardX: CGFloat = 914             // 16 + 416 + 16 + 200 + 16 + 500/2
        let keyboardY: CGFloat = 679             // 795 - 16 - 200/2
        let statusX: CGFloat = 1130              // 1180 - 50
        let statusY: CGFloat = 60

        return DashboardLayout(
            timelineWidth: timelineWidth,
            timelineHeight: timelineHeight,
            keyboardWidth: keyboardWidth,
            keyboardHeight: keyboardHeight,
            typingSpeedSize: typingSpeedSize,
            iterm2Width: iterm2Width,
            iterm2Height: iterm2Height,
            appListWidth: appListWidth,
            appListHeight: appListHeight,
            chartWidth: chartWidth,
            chartHeight: chartHeight,
            timelineX: timelineX,
            timelineY: timelineY,
            appListX: leftColumnX,
            appListY: appListY,
            activityChartX: leftColumnX,
            activityChartY: activityChartY,
            keystrokeChartX: leftColumnX,
            keystrokeChartY: keystrokeChartY,
            iterm2X: rightColumnX,
            iterm2Y: iterm2Y,
            typingSpeedX: typingSpeedX,
            typingSpeedY: typingSpeedY,
            keyboardX: keyboardX,
            keyboardY: keyboardY,
            statusX: statusX,
            statusY: statusY
        )
    }
}

// MARK: - iTerm2 Terminal List View

struct ITerm2TerminalListView: View {
    let sessions: [ITerm2Session]

    private var activeSession: ITerm2Session? {
        sessions.first(where: { $0.isActive }) ?? sessions.first
    }

    var body: some View {
        ZStack {
            if let session = activeSession {
                ITerm2TerminalView(session: session)
            } else {
                placeholder(message: "Waiting for terminal output…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func placeholder(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .foregroundColor(.secondary)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct TerminalOutputArea: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundColor(Color(red: 0.5, green: 1.0, blue: 0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: lines) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastIndex = lines.indices.last else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(lastIndex, anchor: .bottom)
        }
    }
}

#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
#endif
