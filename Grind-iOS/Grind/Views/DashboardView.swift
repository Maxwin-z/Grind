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
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection status
                    connectionStatusView

                    // Real-time typing speed gauge
                    TypingSpeedGauge(
                        kpm: viewModel.currentKPM,
                        currentApp: viewModel.currentApp,
                        isTyping: viewModel.isTyping
                    )

                    // Weekly activity chart
                    WeeklyActivityChart(data: viewModel.dailyActivityData)

                    // Weekly keystroke chart
                    WeeklyKeystrokeChart(data: viewModel.dailyKeystrokeData)

                    // Today's timeline
                    TodayTimelineView(timeBlocks: viewModel.todayTimeBlocks)

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Grind Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.refreshData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var connectionStatusView: some View {
        HStack {
            Circle()
                .fill(viewModel.isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)

            Text(viewModel.connectionStatus)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    DashboardView()
}
