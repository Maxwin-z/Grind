//
//  TypingSpeedCompactView.swift
//  Grind
//
//  Minimal typing speed dial used on dashboard's secondary column
//

import SwiftUI

struct TypingSpeedCompactView: View {
    let kpm: Int
    private let maxKPM = 300

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let circleDiameter = size * 0.85  // 85% of container size for padding
            let lineWidth = size * 0.09  // ~9% of size for stroke width
            let fontSize = size * 0.26  // ~26% of size for font

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                        .frame(width: circleDiameter, height: circleDiameter)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            gradientForSpeed,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .frame(width: circleDiameter, height: circleDiameter)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: kpm)

                    Text("\(kpm)")
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
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
