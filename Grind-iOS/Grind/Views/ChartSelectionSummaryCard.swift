//
//  ChartSelectionSummaryCard.swift
//  Grind
//
//  Reusable overlay card used to display per-day series values when interacting with charts.
//

import SwiftUI

struct ChartSelectionSummaryRow: Identifiable {
    let id: String
    let color: Color
    let label: String
    let value: String
}

struct ChartSelectionSummaryCard: View {
    let title: String
    let rows: [ChartSelectionSummaryRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    Capsule()
                        .fill(row.color)
                        .frame(width: 8, height: 8)
                    Text(row.label)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer(minLength: 8)
                    Text(row.value)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
