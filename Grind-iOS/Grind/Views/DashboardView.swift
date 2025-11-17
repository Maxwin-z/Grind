//
//  DashboardView.swift
//  Grind
//
//  Main dashboard view integrating all chart components
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    private let columnSpacing: CGFloat = 16

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content - Full screen utilization
            VStack(spacing: columnSpacing) {
                // Today's Activity Timeline - Full width at top
                TodayTimelineView(timeBlocks: viewModel.todayTimeBlocks)
                    .frame(height: 200)

                // Two columns below with 2:3 ratio
                GeometryReader { geometry in
                    let layout = calculateDashboardLayout(
                        totalWidth: geometry.size.width,
                        spacing: columnSpacing
                    )

                    HStack(spacing: columnSpacing) {
                        // Column 1 (adaptive width): Weekly Activity + Keystrokes
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
                        .frame(width: layout.leftWidth, height: geometry.size.height)

                        // Column 2: prioritize typing + keyboard width
                        VStack(spacing: columnSpacing) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: .infinity)

                            HStack(spacing: columnSpacing) {
                                TypingSpeedCompactView(
                                    kpm: viewModel.currentKPM
                                )
                                .frame(width: layout.typingWidth, alignment: .center)
                                .frame(height: layout.bottomHeight)

                                VStack {
                                    KeyboardVisualizerView(
                                        currentKey: viewModel.currentKey,
                                        currentModifiers: viewModel.currentModifiers,
                                        keystrokeSequence: viewModel.keystrokeSequence
                                    )
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(8)
                                }
                                .frame(width: layout.keyboardWidth)
                                .frame(height: layout.bottomHeight)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                .layoutPriority(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: layout.bottomHeight)
                        }
                        .frame(width: layout.rightWidth, height: geometry.size.height)
                    }
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

// MARK: - Layout Helpers

private struct DashboardColumnLayout {
    let leftWidth: CGFloat
    let rightWidth: CGFloat
    let typingWidth: CGFloat
    let keyboardWidth: CGFloat
    let bottomHeight: CGFloat
}

private func calculateDashboardLayout(totalWidth: CGFloat, spacing: CGFloat) -> DashboardColumnLayout {
    let minimumKeyboardWidth: CGFloat = 520
    let minimumTypingWidth: CGFloat = 200
    let minimumRightColumnWidth = minimumKeyboardWidth + minimumTypingWidth + spacing
    let desiredRightWidth = max(totalWidth * 0.55, minimumRightColumnWidth)
    let rightWidth = min(desiredRightWidth, totalWidth)
    let leftWidth = max(totalWidth - rightWidth - spacing, 0)
    let safeRightWidth = max(rightWidth, 0)
    let typingRatio: CGFloat = 0.35
    var typingWidth = max(safeRightWidth * typingRatio, minimumTypingWidth)
    var keyboardWidth = safeRightWidth - typingWidth - spacing

    if keyboardWidth < minimumKeyboardWidth {
        keyboardWidth = min(
            max(minimumKeyboardWidth, 0),
            max(safeRightWidth - spacing, 0)
        )
        typingWidth = max(safeRightWidth - keyboardWidth - spacing, 0)
    }

    let bottomHeight = max(
        TypingSpeedCompactView.preferredHeight,
        KeyboardVisualizerView.preferredHeight
    )

    return DashboardColumnLayout(
        leftWidth: leftWidth,
        rightWidth: rightWidth,
        typingWidth: typingWidth,
        keyboardWidth: keyboardWidth,
        bottomHeight: bottomHeight
    )
}

#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
#endif
