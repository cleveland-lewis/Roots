//
//  WatchRootView.swift
//  Roots (watchOS)
//

#if os(watchOS)
import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var focusManager: FocusManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                Text("Today")
                    .font(DesignSystem.Typography.header)

                summaryCard(title: "Next Event", value: "Open on iPhone to sync")
                summaryCard(title: "Next Task", value: "Open on iPhone to sync")

                Button {
                    focusManager.startTimer()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.small) {
                        Image(systemName: "timer")
                        Text("Start Focus")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                summaryCard(title: "Time Studied", value: formattedStudyTime())
            }
            .padding(DesignSystem.Spacing.medium)
        }
        .background(DesignSystem.Colors.appBackground)
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xsmall) {
            Text(title)
                .font(DesignSystem.Typography.subHeader)
            Text(value)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.secondary)
        }
        .padding(DesignSystem.Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    private func formattedStudyTime() -> String {
        let totalSeconds = focusManager.activities.reduce(0) { $0 + $1.todayTrackedSeconds }
        let minutes = Int(totalSeconds / 60)
        return "\(minutes)m today"
    }
}
#endif
