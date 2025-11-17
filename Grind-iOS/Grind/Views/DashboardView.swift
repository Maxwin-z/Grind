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

    // MARK: - State for dynamic heights
    @State private var timelineHeight: CGFloat = 0
    @State private var appLegendHeight: CGFloat = 0

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
            

            ZStack(alignment: .topTrailing) {
                VStack(spacing: padding) {
                    // 1. Today's Activity Timeline
                    TodayTimelineView(timeBlocks: viewModel.todayTimeBlocks)
                        .frame(width: layout.timelineWidth)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: TimelineHeightPreferenceKey.self,
                                    value: proxy.size.height
                                )
                            }
                        )

                    // 2. Main content area
                    HStack(spacing: padding) {
                        // Left Column: Apps + Two Charts
                        VStack(spacing: padding) {
                            // Apps (3-column layout, self-sizing)
                            AppLegendListView(
                                appNames: legendAppNames,
                                appMetadata: viewModel.appSelectionMetadata
                            )
                            .frame(width: layout.appListWidth)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: AppLegendHeightPreferenceKey.self,
                                        value: proxy.size.height
                                    )
                                }
                            )

                            // Weekly Activity Chart
                            WeeklyActivityChart(
                                data: viewModel.dailyActivityData,
                                appMetadata: viewModel.appSelectionMetadata
                            )
                            .frame(width: layout.chartWidth, height: layout.chartHeight)

                            // Weekly Keystroke Chart
                            WeeklyKeystrokeChart(
                                data: viewModel.dailyKeystrokeData,
                                appMetadata: viewModel.appSelectionMetadata
                            )
                            .frame(width: layout.chartWidth, height: layout.chartHeight)
                        }

                        // Right Column: iTerm2 + (Typing Speed + Keyboard)
                        VStack(spacing: padding) {
                            // iTerm2 Terminal View
                            ITerm2TerminalView(sessions: viewModel.iterm2Sessions)
                                .frame(width: layout.iterm2Width, height: layout.iterm2Height)

                            // Bottom row: Typing Speed + Keyboard
                            HStack(spacing: padding) {
                                // Typing Speed (square)
                                TypingSpeedCompactView(kpm: viewModel.currentKPM)
                                    .frame(width: layout.typingSpeedSize, height: layout.typingSpeedSize)

                                // Keyboard Visualizer
                                KeyboardVisualizerView(
                                    currentKey: viewModel.currentKey,
                                    currentModifiers: viewModel.currentModifiers,
                                    keystrokeSequence: viewModel.keystrokeSequence
                                )
                                .frame(width: layout.keyboardWidth, height: layout.keyboardHeight)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                }
                .padding(padding)

                // Floating connection status and refresh button (top-right)
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
                .padding(.trailing, 20)
                .padding(.top, 60)
            }
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(.all, edges: .all)
        }
        .onPreferenceChange(TimelineHeightPreferenceKey.self) { newHeight in
            timelineHeight = newHeight
        }
        .onPreferenceChange(AppLegendHeightPreferenceKey.self) { newHeight in
            appLegendHeight = newHeight
        }
    }
}

// MARK: - Layout Helpers

private struct DashboardLayout {
    let timelineWidth: CGFloat
    let keyboardWidth: CGFloat
    let keyboardHeight: CGFloat
    let typingSpeedSize: CGFloat
    let iterm2Width: CGFloat
    let iterm2Height: CGFloat
    let appListWidth: CGFloat
    let chartWidth: CGFloat
    let chartHeight: CGFloat
}

extension DashboardView {
    private func calculateLayout(screenWidth: CGFloat, screenHeight: CGFloat) -> DashboardLayout {
        // Step 1: TodayTimelineView
        let timelineWidth = screenWidth - padding * 2

        // Step 2: KeyboardVisualizerView (w = screen.w/2, aspect ratio 5:2)
        let keyboardWidth = (CGFloat)(500)
        let keyboardHeight = keyboardWidth * 2 / 5

        // Step 3: TypingSpeedCompactView (square, size = keyboard height)
        let typingSpeedSize = keyboardHeight

        // Step 4: ITerm2TerminalView
        let iterm2Width = keyboardWidth + typingSpeedSize + padding
        let iterm2Height = screenHeight - keyboardHeight - timelineHeight - padding * 4

        // Step 5: AppLegendListView
        let appListWidth = screenWidth - iterm2Width - padding * 3

        // Step 6: WeeklyActivityChart and WeeklyKeystrokeChart
        let chartWidth = appListWidth
        let chartHeight = (screenHeight - timelineHeight - appLegendHeight - padding * 5) / 2

        return DashboardLayout(
            timelineWidth: timelineWidth,
            keyboardWidth: keyboardWidth,
            keyboardHeight: keyboardHeight,
            typingSpeedSize: typingSpeedSize,
            iterm2Width: iterm2Width,
            iterm2Height: iterm2Height,
            appListWidth: appListWidth,
            chartWidth: chartWidth,
            chartHeight: chartHeight
        )
    }
}

// MARK: - Preference Keys

private struct TimelineHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AppLegendHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


// MARK: - iTerm2 Terminal View

struct ITerm2TerminalView: View {
    let sessions: [ITerm2Session]

    private var renderedLines: [String] {
        guard let session = sessions.first(where: { $0.isActive }) ?? sessions.first else {
            return []
        }

        let lines = session.screenLines ?? []
        let maxLines = 100
        if lines.count > maxLines {
            return Array(lines.suffix(maxLines))
        }
        return lines
    }

    var body: some View {
        ZStack {
            if renderedLines.isEmpty {
                placeholder(message: "Waiting for terminal output…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TerminalOutputArea(lines: renderedLines)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.05))
        )
    }

    private func placeholder(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .foregroundColor(.secondary)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemBackground))
        )
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
            .onChange(of: lines) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
        )
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
