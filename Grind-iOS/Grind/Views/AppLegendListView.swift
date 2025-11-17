//
//  AppLegendListView.swift
//  Grind
//
//  Dedicated legend showing the apps represented in the weekly charts.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AppLegendListView: View {
    let appNames: [String]
    let appMetadata: [String: SelectedAppData]

    private var colorProvider: AppColorProvider {
        AppColorProvider(appMetadata: appMetadata)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .leading), count: 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if appNames.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
                    ForEach(appNames, id: \.self) { appName in
                        legendRow(for: appName)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)  // Internal padding only
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func legendRow(for appName: String) -> some View {
        let color = colorProvider.color(for: appName)
        return HStack(spacing: 8) {
            legendIcon(for: appName, color: color)

            Text(appName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func legendIcon(for appName: String, color: Color) -> some View {
        #if canImport(UIKit)
        if let icon = colorProvider.icon(for: appName) {
            Image(uiImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(color.opacity(0.6), lineWidth: 1)
                )
        } else {
            fallbackIndicator(color: color)
        }
        #else
        fallbackIndicator(color: color)
        #endif
    }

    private func fallbackIndicator(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 16, height: 16)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "app.badge")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("Apps will show here once activity syncs.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }
}
