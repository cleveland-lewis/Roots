import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ScrollView {
            CardGrid {
                AppCard(title: "Today Overview", icon: Image(systemName: "sunrise.fill")) {
                    DashboardTileBody(
                        rows: [
                            ("Schedule Today", "No data available"),
                            ("Mood", "Balanced")
                        ]
                    )
                }
                .onTapGesture {
                    UILogger.log(.dashboard, "Tapped: today_overview")
                }

                AppCard(title: "Energy & Focus", icon: Image(systemName: "heart.fill")) {
                    DashboardTileBody(
                        rows: [
                            ("Streak", "4 days"),
                            ("Focus Window", "Next slot 2h")
                        ]
                    )
                }
                .onTapGesture {
                    UILogger.log(.dashboard, "Tapped: energy_focus")
                }

                AppCard(title: "Insights", icon: Image(systemName: "lightbulb.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No data available")
                            .foregroundColor(.secondary)
                            .font(settings.font(for: .body))
                    }
                }
                .onTapGesture {
                    UILogger.log(.dashboard, "Tapped: insights")
                }

                AppCard(title: "Upcoming Deadlines", icon: Image(systemName: "clock.arrow.circlepath")) {
                    DashboardTileBody(
                        rows: [
                            ("Next", "Assignment - due tomorrow"),
                            ("Following", "Quiz - Friday")
                        ]
                    )
                }
                .onTapGesture {
                    UILogger.log(.dashboard, "Tapped: upcoming_deadlines")
                }
            }
            .padding()
            .contentTransition(.opacity)
        }
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
                }
            }
        }
    }
}

