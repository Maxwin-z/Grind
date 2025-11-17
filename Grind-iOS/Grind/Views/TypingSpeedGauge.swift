//
//  TypingSpeedGauge.swift
//  Grind
//
//  Real-time typing speed gauge (KPM - Keys Per Minute)
//

import SwiftUI

struct TypingSpeedGauge: View {
    let kpm: Int
    let currentApp: String
    let isTyping: Bool

    // Gauge ranges
    private let maxKPM = 300  // Maximum displayable KPM

    var body: some View {
        VStack(spacing: 16) {
            Text("Typing Speed")
                .font(.headline)
                .foregroundColor(.primary)

            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)

                // Speed arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        gradientForSpeed,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: kpm)

                // Center content
                VStack(spacing: 8) {
                    Text("\(kpm)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("KPM")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if isTyping {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Typing")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.top, 4)
                    }
                }
            }

            // Current app indicator
            VStack(spacing: 6) {
                Text("Current App")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(currentApp)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            // Speed legend
            HStack(spacing: 20) {
                speedLegendItem(label: "Slow", color: .blue, range: "< 60")
                speedLegendItem(label: "Normal", color: .green, range: "60-120")
                speedLegendItem(label: "Fast", color: .orange, range: "120-180")
                speedLegendItem(label: "Very Fast", color: .red, range: "> 180")
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    // MARK: - Helper Views

    private func speedLegendItem(label: String, color: Color, range: String) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(range)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Computed Properties

    private var progress: Double {
        return min(Double(kpm) / Double(maxKPM), 1.0)
    }

    private var gradientForSpeed: LinearGradient {
        let colors: [Color]

        switch kpm {
        case 0..<60:
            colors = [.blue, .blue]
        case 60..<120:
            colors = [.green, .green]
        case 120..<180:
            colors = [.orange, .orange]
        default:
            colors = [.red, .red]
        }

        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#if DEBUG
struct TypingSpeedGauge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            TypingSpeedGauge(kpm: 85, currentApp: "Xcode", isTyping: true)
            TypingSpeedGauge(kpm: 150, currentApp: "VS Code", isTyping: false)
            TypingSpeedGauge(kpm: 0, currentApp: "—", isTyping: false)
        }
        .padding()
    }
}
#endif
