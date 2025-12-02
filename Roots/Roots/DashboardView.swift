import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var todayBounce = false
    @State private var energyBounce = false
    @State private var insightsBounce = false
    @State private var deadlinesBounce = false

    private var showIcons: Bool { settings.iconLabelMode != .textOnly }
    private var showText: Bool { settings.iconLabelMode != .iconsOnly }

    private var labelModeBinding: Binding<IconLabelMode> {
        Binding(get: { settings.iconLabelMode }, set: { newValue in
            withAnimation(.easeInOut(duration: 0.25)) {
                settings.iconLabelMode = newValue
            }
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerControls
                CardGrid {
                    todayCard
                    energyCard
                    insightsCard
                    deadlinesCard
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .contentTransition(.opacity)
        .onAppear {
            LOG_UI(.info, "Navigation", "Displayed DashboardView")
        }
    }

    private var headerControls: some View {
        HStack(spacing: 12) {
            Text("Dashboard")
                .font(settings.font(for: .headline))
                .foregroundStyle(.primary)
            Spacer()
            Picker("", selection: labelModeBinding) {
                ForEach(IconLabelMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            .labelsHidden()
            .help("Toggle how the cards present icons and text")
        }
    }

    private var todayCard: some View {
        AppCard(
            title: cardTitle("Today Overview"),
            icon: cardIcon("sun.max"),
            iconBounceTrigger: todayBounce
        ) {
            DashboardTileBody(
                rows: [
                    ("Schedule Today", "No data available"),
                    ("Mood", "Balanced")
                ]
            )
        }
        .onTapGesture {
            todayBounce.toggle()
            print("[Dashboard] card tapped: todayOverview")
        }
        .help("Today Overview")
    }

    private var energyCard: some View {
        AppCard(
            title: cardTitle("Energy & Focus"),
            icon: cardIcon("heart.fill"),
            iconBounceTrigger: energyBounce
        ) {
            DashboardTileBody(
                rows: [
                    ("Streak", "4 days"),
                    ("Focus Window", "Next slot 2h")
                ]
            )
        }
        .onTapGesture {
            energyBounce.toggle()
            print("[Dashboard] card tapped: energyFocus")
        }
        .help("Energy & Focus")
    }

    private var insightsCard: some View {
        AppCard(
            title: cardTitle("Insights"),
            icon: cardIcon("lightbulb.fill"),
            iconBounceTrigger: insightsBounce
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .font(settings.font(for: .body))
            }
        }
        .onTapGesture {
            insightsBounce.toggle()
            print("[Dashboard] card tapped: insights")
        }
        .help("Insights")
    }

    private var deadlinesCard: some View {
        AppCard(
            title: cardTitle("Upcoming Deadlines"),
            icon: cardIcon("clock.arrow.circlepath"),
            iconBounceTrigger: deadlinesBounce
        ) {
            DashboardTileBody(
                rows: [
                    ("Next", "Assignment - due tomorrow"),
                    ("Following", "Quiz - Friday")
                ]
            )
        }
        .onTapGesture {
            deadlinesBounce.toggle()
            print("[Dashboard] card tapped: upcomingDeadlines")
        }
        .help("Upcoming Deadlines")
    }

    private func cardTitle(_ title: String) -> String? {
        showText ? title : nil
    }

    private func cardIcon(_ name: String) -> Image? {
        showIcons ? Image(systemName: name) : nil
    }
}

struct DashboardTileBody: View {
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.0)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(row.1)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}
