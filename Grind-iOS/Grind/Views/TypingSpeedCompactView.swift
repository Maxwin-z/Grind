//
//  TypingSpeedCompactView.swift
//  Grind
//
//  Minimal typing speed dial used on dashboard's secondary column
//

import SwiftUI

struct TypingSpeedCompactView: View {
    static let preferredHeight: CGFloat = 220

    let kpm: Int
    private let maxKPM = 300

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 18)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        gradientForSpeed,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: kpm)

                Text("\(kpm)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var progress: Double {
        min(Double(kpm) / Double(maxKPM), 1.0)
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
struct TypingSpeedCompactView_Previews: PreviewProvider {
    static var previews: some View {
        TypingSpeedCompactView(kpm: 95)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif
