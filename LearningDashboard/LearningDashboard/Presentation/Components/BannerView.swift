//
//  BannerView.swift
//  LearningDashboard
//

import SwiftUI

struct BannerView: View {
    enum Style {
        case error, warning, info

        var icon: String {
            switch self {
            case .error: "exclamationmark.triangle.fill"
            case .warning: "wifi.slash"
            case .info: "checkmark.icloud"
            }
        }

        var tint: Color {
            switch self {
            case .error: .red
            case .warning: .orange
            case .info: .blue
            }
        }
    }

    let style: Style
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: style.icon)
                .foregroundStyle(style.tint)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(12)
        .background(style.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

struct ProgressBar: View {
    let progress: Int

    var body: some View {
        ProgressView(value: Double(progress), total: 100)
            .tint(progress >= 100 ? Color.green : Color.accentColor)
            .accessibilityLabel("Progress")
            .accessibilityValue("\(progress) percent")
    }
}
