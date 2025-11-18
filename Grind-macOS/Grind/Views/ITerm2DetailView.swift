//
//  ITerm2DetailView.swift
//  Grind
//
//  Created by Maxwin on 2025/11/16.
//

import SwiftUI
import Combine

struct ITerm2DetailView: View {
    let app: AppInfo
    @ObservedObject var iterm2Service = ITerm2Service.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Header
                VStack(spacing: 12) {
                    // App Icon
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .shadow(radius: 4)
                    }

                    Text(app.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(app.bundleId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 16)

                Divider()

                // iTerm2 Session Info
                if iterm2Service.isLoading {
                    ProgressView("Loading iTerm2 sessions...")
                } else if let error = iterm2Service.lastError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Error")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if let info = iterm2Service.currentInfo {
                    VStack(spacing: 20) {
                        // Session Summary
                        HStack(spacing: 20) {
                            StatCard(
                                title: "Windows",
                                value: "\(info.windows.count)",
                                icon: "macwindow",
                                color: .blue
                            )

                            StatCard(
                                title: "Sessions",
                                value: "\(info.allSessions.count)",
                                icon: "terminal",
                                color: .green
                            )
                        }

                        // Active Session Details
                        if let activeSession = info.activeSession {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "terminal.fill")
                                        .foregroundColor(.green)
                                    Text("Active Session")
                                        .font(.headline)
                                    Spacer()
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                }

                                // Session metadata
                                VStack(spacing: 8) {
                                    SessionInfoRow(
                                        icon: "terminal",
                                        label: "Job",
                                        value: activeSession.displayName
                                    )

                                    if !activeSession.displayPath.isEmpty {
                                        SessionInfoRow(
                                            icon: "folder",
                                            label: "Path",
                                            value: activeSession.displayPath
                                        )
                                    }

                                    if let tty = activeSession.tty, !tty.isEmpty {
                                        SessionInfoRow(
                                            icon: "app.connected.to.app.below.fill",
                                            label: "TTY",
                                            value: tty
                                        )
                                    }

                                    if !activeSession.displayHost.isEmpty {
                                        SessionInfoRow(
                                            icon: "network",
                                            label: "Host",
                                            value: activeSession.displayHost
                                        )
                                    }
                                }

                                // Terminal Output
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Terminal Output")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)

                                        Text("(\(activeSession.screenLines.count) lines)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }

                                    if activeSession.screenLines.isEmpty {
                                        Text("No terminal content available")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(12)
                                            .frame(maxWidth: .infinity)
                                            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                                            .cornerRadius(8)
                                    } else {
                                        ScrollView(.horizontal, showsIndicators: true) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                ForEach(Array(activeSession.lastScreenLines.enumerated()), id: \.offset) { index, line in
                                                    Text(line.isEmpty ? " " : line)
                                                        .font(.system(size: 11, design: .monospaced))
                                                        .textSelection(.enabled)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                            }
                                            .padding(12)
                                        }
                                        .frame(maxHeight: 200)
                                        .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                            .cornerRadius(12)
                        }

                        // All Sessions List
                        if info.allSessions.count > 1 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("All Sessions (\(info.allSessions.count))")
                                    .font(.headline)

                                ForEach(info.allSessions) { session in
                                    SessionRowView(session: session)
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "terminal")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No iTerm2 data")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                Spacer()
            }
            .padding(24)
        }
        .task {
            // Start the event-driven monitor when view appears
            iterm2Service.startMonitoring()
        }
        .onDisappear {
            // Stop monitoring when view disappears to save resources
            iterm2Service.stopMonitoring()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct SessionInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(6)
    }
}

struct SessionRowView: View {
    let session: ITerm2Session

    var body: some View {
        HStack(spacing: 12) {
            // Active indicator
            Circle()
                .fill(session.isActive ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(session.displayName)
                        .font(.subheadline)
                        .fontWeight(session.isActive ? .semibold : .regular)

                    if session.isActive {
                        Text("ACTIVE")
                            .font(.system(size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(3)
                    }
                }

                if !session.displayPath.isEmpty {
                    Text(session.displayPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let tty = session.tty, !tty.isEmpty {
                    Text(tty)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(session.isActive ? 0.5 : 0.2))
        .cornerRadius(8)
    }
}
