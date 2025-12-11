import SwiftUI

struct CalendarStatsRow: View {
    var averagePerDay: String = "2.2"
    var totalThisMonth: String = "67"
    var busiestDay: String = "Dec 10"
    var upcomingBreak: String = "Winter Break starts Dec 20"

    var body: some View {
        HStack(spacing: 16) {
            statCard(icon: "chart.bar.fill", title: "Average / Day", value: averagePerDay)
            statCard(icon: "calendar", title: "Total This Month", value: totalThisMonth)
            statCard(icon: "flame.fill", title: "Busiest Day", value: busiestDay)
            statCard(icon: "leaf.fill", title: "Upcoming Break", value: upcomingBreak, tint: .green)
        }
    }

    @ViewBuilder
    private func statCard(icon: String, title: String, value: String, tint: Color = .accentColor) -> some View {
        RootsCard {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.headline.weight(.semibold))
                }
                Spacer()
            }
            .padding(12)
        }
    }
}

struct CalendarStatsRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CalendarStatsRow()
                .padding()
                .previewLayout(.sizeThatFits)

            CalendarStatsRow(averagePerDay: "3.4", totalThisMonth: "102", busiestDay: "Dec 12", upcomingBreak: "Spring Break Mar 8")
                .padding()
                .previewLayout(.sizeThatFits)
        }
    }
}
