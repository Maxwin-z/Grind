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

    // MARK: - State for dynamic heights and layout
    @State private var timelineHeight: CGFloat = 0
    @State private var appLegendHeight: CGFloat = 0
    @State private var screenSize: CGSize = .zero
    @State private var cachedAppNames: [String] = []
    @State private var hasCompletedInitialLayout: Bool = false  // Track if initial layout is done
    @State private var isMeasuring: Bool = false  // Prevent concurrent remeasurements

    // Three-stage layout process
    enum LayoutStage {
        case measuringTimeline      // Stage 1: Measure timeline height
        case measuringAppLegend     // Stage 2: Measure app legend height
        case ready                  // Stage 3: All measurements done, show final layout
    }
    @State private var layoutStage: LayoutStage = .measuringTimeline

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
            ZStack {
                switch layoutStage {
                case .measuringTimeline:
                    // Stage 1: Only render Timeline to measure its height
                    measureTimelineStage(screenSize: screen.size)
                        .opacity(0.3)

                case .measuringAppLegend:
                    // Stage 2: Render Timeline + AppLegend to measure AppLegend height
                    measureAppLegendStage(screenSize: screen.size)
                        .opacity(0.3)

                case .ready:
                    // Stage 3: All measurements done, show final layout
                    dashboardContent(screenSize: screen.size)
                }

                // Measurement overlay during calculation
                if layoutStage != .ready {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(stageMessage)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground).opacity(0.8))
                }
            }
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(.all, edges: .all)
            .onChange(of: screen.size) { oldValue, newValue in
                // Only reset if size actually changed (not initial load) and not currently measuring
                if screenSize != .zero && newValue != screenSize && !isMeasuring {
                    print("📱 Screen size changed: \(screenSize) → \(newValue), triggering remeasurement")
                    screenSize = newValue
                    // Reset to stage 1 to remeasure
                    isMeasuring = true
                    hasCompletedInitialLayout = false
                    layoutStage = .measuringTimeline
                    timelineHeight = 0
                    appLegendHeight = 0
                } else if screenSize == .zero {
                    print("📱 Initial screen size: \(newValue)")
                    screenSize = newValue
                } else if isMeasuring {
                    print("📱 Screen size change ignored (currently measuring)")
                }
            }
            .onAppear {
                print("👋 DashboardView appeared")
                if screenSize == .zero {
                    screenSize = screen.size
                }
                // Cache initial app names (will be updated when layout completes)
                if cachedAppNames.isEmpty {
                    cachedAppNames = legendAppNames
                    print("📋 Initial app list cached: \(cachedAppNames)")
                }
            }
            .onChange(of: legendAppNames) { oldValue, newValue in
                // Only remeasure if:
                // 1. Initial layout is complete (hasCompletedInitialLayout == true)
                // 2. App list actually changed
                // 3. Not currently measuring
                if hasCompletedInitialLayout && newValue != cachedAppNames && !isMeasuring {
                    print("📋 App list changed after initial layout: \(cachedAppNames.count) → \(newValue.count), triggering remeasurement")
                    print("   Old: \(cachedAppNames)")
                    print("   New: \(newValue)")
                    cachedAppNames = newValue
                    // Reset to stage 1 to remeasure
                    isMeasuring = true
                    hasCompletedInitialLayout = false
                    layoutStage = .measuringTimeline
                    timelineHeight = 0
                    appLegendHeight = 0
                } else if !hasCompletedInitialLayout {
                    print("📋 App list changed during initial layout: \(cachedAppNames.count) → \(newValue.count), ignoring")
                    cachedAppNames = newValue  // Update cache but don't trigger remeasure
                } else if isMeasuring {
                    print("📋 App list change ignored (currently measuring)")
                    cachedAppNames = newValue  // Update cache
                }
            }
        }
    }

    private var stageMessage: String {
        switch layoutStage {
        case .measuringTimeline:
            return "Measuring timeline... (1/3)"
        case .measuringAppLegend:
            return "Measuring app legend... (2/3)"
        case .ready:
            return ""
        }
    }


    // MARK: - Stage 1: Measure Timeline

    @ViewBuilder
    private func measureTimelineStage(screenSize: CGSize) -> some View {
        let timelineWidth = screenSize.width - padding * 2

        ZStack {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                TodayTimelineView(timeBlocks: viewModel.todayTimeBlocks)
                    .frame(width: timelineWidth)
                    .fixedSize(horizontal: false, vertical: true)  // Allow vertical auto-sizing
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear {
                                    // Only measure if we're still in Stage 1
                                    guard layoutStage == .measuringTimeline else {
                                        print("⚠️ [Stage 1] GeometryReader appeared but not in Stage 1 (stage=\(layoutStage)), ignoring")
                                        return
                                    }

                                    let height = proxy.size.height
                                    print("📐 [Stage 1] Timeline GeometryReader appeared, size: \(proxy.size)")

                                    if height > 0 && timelineHeight == 0 {
                                        print("📏 [Stage 1] Timeline height measured: \(height)")
                                        // Update state in next run loop to ensure propagation
                                        DispatchQueue.main.async {
                                            self.timelineHeight = height
                                            print("📊 [Stage 1] timelineHeight updated to: \(self.timelineHeight)")
                                            // Wait for another run loop before transitioning
                                            if self.layoutStage == .measuringTimeline {
                                                DispatchQueue.main.async {
                                                    print("🔄 [Stage 1→2] About to transition with timelineHeight=\(self.timelineHeight)")
                                                    self.layoutStage = .measuringAppLegend
                                                    print("✅ [Stage 1→2] Now in app legend measurement stage, timelineHeight=\(self.timelineHeight)")
                                                }
                                            }
                                        }
                                    }
                                }
                        }
                    )
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(padding)
        }
    }

    // MARK: - Stage 2: Measure AppLegend

    @ViewBuilder
    private func measureAppLegendStage(screenSize: CGSize) -> some View {
        let _ = print("📋 [Stage 2 Build] Building measureAppLegendStage with timelineHeight=\(timelineHeight), appLegendHeight=\(appLegendHeight)")

        // Calculate dimensions needed for AppLegend positioning
        let timelineWidth = screenSize.width - padding * 2
        let keyboardWidth = CGFloat(500)
        let keyboardHeight = keyboardWidth * 2 / 5
        let typingSpeedSize = keyboardHeight
        let iterm2Width = keyboardWidth + typingSpeedSize + padding
        let appListWidth = screenSize.width - iterm2Width - padding * 3

        VStack(alignment: .leading, spacing: padding) {
            // Timeline (already measured, fixed height)
            if timelineHeight > 0 {
                TodayTimelineView(timeBlocks: viewModel.todayTimeBlocks)
                    .frame(width: timelineWidth, height: timelineHeight)
            }

            // AppLegend (measuring)
            HStack(spacing: padding) {
                AppLegendListView(
                    appNames: legendAppNames,
                    appMetadata: viewModel.appSelectionMetadata
                )
                .frame(width: appListWidth)
                .fixedSize(horizontal: false, vertical: true)  // Allow vertical auto-sizing
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                print("📐 [Stage 2] AppLegend GeometryReader onAppear called!")
                                print("   layoutStage: \(layoutStage)")
                                print("   proxy.size: \(proxy.size)")

                                // Only measure if we're still in Stage 2
                                guard layoutStage == .measuringAppLegend else {
                                    print("⚠️ [Stage 2] Not in Stage 2, ignoring")
                                    return
                                }

                                let height = proxy.size.height
                                print("📐 [Stage 2] AppLegend measured height: \(height)")

                                if height > 0 {
                                    print("✅ [Stage 2] Valid height, proceeding to update...")
                                    // Update state in next run loop
                                    DispatchQueue.main.async {
                                        self.appLegendHeight = height
                                        print("📊 [Stage 2] appLegendHeight updated to: \(self.appLegendHeight)")
                                        // Wait for another run loop before transitioning
                                        if self.layoutStage == .measuringAppLegend {
                                            DispatchQueue.main.async {
                                                print("🔄 [Stage 2→3] Transitioning to ready state...")
                                                self.layoutStage = .ready
                                                self.hasCompletedInitialLayout = true
                                                self.isMeasuring = false  // Measurement complete
                                                print("✅ [Stage 2→3] Layout complete! Timeline=\(self.timelineHeight), AppLegend=\(self.appLegendHeight), can accept new triggers now")
                                            }
                                        }
                                    }
                                } else {
                                    print("❌ [Stage 2] Invalid height: \(height)")
                                }
                            }
                    }
                )

                Spacer()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(padding)  // Outer padding for entire dashboard
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Stage 3: Final Layout

    @ViewBuilder
    private func dashboardContent(screenSize: CGSize) -> some View {
        let _ = print("🎯 [Stage 3] dashboardContent called with timelineHeight=\(timelineHeight), appLegendHeight=\(appLegendHeight)")
        let layout = calculateLayout(screenWidth: screenSize.width, screenHeight: screenSize.height)

        ZStack(alignment: .topTrailing) {
            VStack(spacing: padding) {
                // 1. Today's Activity Timeline (using measured height)
                TodayTimelineView(timeBlocks: viewModel.todayTimeBlocks)
                    .frame(width: layout.timelineWidth, height: timelineHeight)

                // 2. Main content area
                HStack(spacing: padding) {
                    // Left Column: Apps + Two Charts
                    VStack(spacing: padding) {
                        // Apps (using measured height)
                        AppLegendListView(
                            appNames: legendAppNames,
                            appMetadata: viewModel.appSelectionMetadata
                        )
                        .frame(width: layout.appListWidth, height: appLegendHeight)

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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(padding)  // Outer padding for entire dashboard

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
        print("📐 ========== DASHBOARD LAYOUT CALCULATION ==========")
        print("📱 Screen Size: \(screenWidth) x \(screenHeight)")
        print("📏 Padding: \(padding)")
        print("📊 Dynamic Heights (measured): timeline=\(timelineHeight), appLegend=\(appLegendHeight)")
        print("")

        // Step 1: TodayTimelineView width (height is measured)
        let timelineWidth = screenWidth - padding * 2
        print("1️⃣ Timeline: width=\(timelineWidth), height=\(timelineHeight)")

        // Step 2: KeyboardVisualizerView (w = fixed, aspect ratio 5:2)
        let keyboardWidth = (CGFloat)(500)
        let keyboardHeight = keyboardWidth * 2 / 5
        print("2️⃣ Keyboard: width=\(keyboardWidth), height=\(keyboardHeight)")

        // Step 3: TypingSpeedCompactView (square, size = keyboard height)
        let typingSpeedSize = keyboardHeight
        print("3️⃣ TypingSpeed: size=\(typingSpeedSize)x\(typingSpeedSize)")

        // Step 4: ITerm2TerminalView
        let iterm2Width = keyboardWidth + typingSpeedSize + padding
        let iterm2Height = screenHeight - keyboardHeight - timelineHeight - padding * 4
        print("4️⃣ iTerm2: width=\(iterm2Width), height=\(iterm2Height)")

        // Step 5: AppLegendListView width (height is measured)
        let appListWidth = screenWidth - iterm2Width - padding * 3
        print("5️⃣ AppList: width=\(appListWidth), height=\(appLegendHeight)")

        // Step 6: WeeklyActivityChart and WeeklyKeystrokeChart
        let chartWidth = appListWidth
        // Calculate available height for left column
        let leftColumnAvailableHeight = screenHeight - timelineHeight - padding * 4
        let remainingHeightForCharts = leftColumnAvailableHeight - appLegendHeight - padding * 2
        let chartHeight = max(remainingHeightForCharts / 2, 120)
        print("6️⃣ Charts: width=\(chartWidth), height=\(chartHeight)")
        print("   └─ leftColumnAvailable=\(leftColumnAvailableHeight), remaining=\(remainingHeightForCharts)")

        print("📐 ================================================")
        print("")

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
        .padding(12)  // Internal padding only
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
            .onChange(of: lines) { oldValue, newValue in
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
