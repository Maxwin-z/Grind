//
//  DashboardView.swift
//  Grind
//
//  Main dashboard view integrating all chart components
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content - Full screen utilization
            VStack(spacing: 16) {
                // Today's Activity Timeline - Full width at top
                TodayTimelineView(timeBlocks: viewModel.todayTimeBlocks)
                    .frame(height: 200)

                // Three columns below
                HStack(spacing: 16) {
                    // Column 1: Weekly Activity + Keystrokes
                    VStack(spacing: 16) {
                        WeeklyActivityChart(
                            data: viewModel.dailyActivityData,
                            appMetadata: viewModel.appSelectionMetadata
                        )
                        .frame(maxHeight: .infinity)

                        WeeklyKeystrokeChart(
                            data: viewModel.dailyKeystrokeData,
                            appMetadata: viewModel.appSelectionMetadata
                        )
                        .frame(maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity)

                    // Column 2: Typing Speed
                    TypingSpeedGauge(
                        kpm: viewModel.currentKPM,
                        currentApp: viewModel.currentApp,
                        isTyping: viewModel.isTyping,
                        currentKey: viewModel.currentKey,
                        currentModifiers: viewModel.currentModifiers,
                        keystrokeSequence: viewModel.keystrokeSequence
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Column 3: Reserved for future use
                    VStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .overlay(
                                Text("Reserved")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)

            // Floating reconnect button and status (top-right) - No layout impact
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
}

#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
#endif
