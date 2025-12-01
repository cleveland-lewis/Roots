import SwiftUI
import EventKit

struct DashboardView: View {
    @StateObject private var calendarManager = CalendarManager.shared
    // Accept external arrays for future real data integration; default empty (no fake data)
    var todayItems: [AnyHashable] = []
    var courses: [AnyHashable] = []
    var tasks: [AnyHashable] = []
    var energyData: [AnyHashable] = []
    var insights: [AnyHashable] = []

    private let columns = [
        GridItem(.adaptive(minimum: 300), spacing: DesignSystem.Spacing.medium)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                Text("Dashboard")
                    .font(DesignSystem.Typography.title)
                    .padding(.bottom, DesignSystem.Spacing.small)

                // Device Calendars
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    HStack(spacing: DesignSystem.Spacing.small) {
                        Image(systemName: "calendar")
                        Text("Device Calendars").font(DesignSystem.Typography.body)
                    }

                    if calendarManager.calendars.isEmpty {
                        DesignCard(imageName: "Tahoe", material: .constant(DesignSystem.materials.first?.material ?? Material.regularMaterial)) {
                            VStack(spacing: DesignSystem.Spacing.small) {
                                Image(systemName: "calendar")
                                    .imageScale(.large)
                                Text(DesignSystem.emptyStateMessage)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: DesignSystem.Cards.defaultHeight)
                    } else {
                        DesignCard(imageName: "Tahoe", material: .constant(DesignSystem.materials.first?.material ?? Material.regularMaterial)) {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                                Image(systemName: "calendar")
                                    .imageScale(.large)
                                Text("Connected Calendars")
                                    .font(DesignSystem.Typography.body)
                                ForEach(calendarManager.calendars, id: \.calendarIdentifier) { cal in
                                    Text(cal.title)
                                        .font(DesignSystem.Typography.caption)
                                }
                            }
                        }
                        .frame(height: DesignSystem.Cards.defaultHeight)
                    }
                }

                // Today Overview
                SectionView(title: "Today Overview", items: todayItems, icon: Image(systemName: "sun.max"))

                // Courses
                SectionView(title: "Courses", items: courses, icon: Image(systemName: "book.closed"))

                // Tasks / Due Soon
                SectionView(title: "Tasks & Due Soon", items: tasks, icon: Image(systemName: "checkmark.circle"))

                // Energy & Focus
                SectionView(title: "Energy & Focus", items: energyData, icon: Image(systemName: "bolt.heart"))

                // Insights
                SectionView(title: "Insights", items: insights, icon: Image(systemName: "chart.bar.doc.horizontal"))

                Spacer()
            }
            .padding(DesignSystem.Spacing.large)
        }
        .background(DesignSystem.background(for: .light))
        .task {
            calendarManager.requestAccess { _ in }
        }
        .navigationTitle("Dashboard")
    }
}

private struct SectionView: View {
    var title: String
    var items: [AnyHashable]
    var icon: Image

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack(spacing: DesignSystem.Spacing.small) {
                icon
                Text(title).font(DesignSystem.Typography.body)
            }

            if items.isEmpty {
                // Single empty state card
                DesignCard(imageName: "Tahoe", material: .constant(DesignSystem.materials.first?.material ?? Material.regularMaterial)) {
                    VStack(spacing: DesignSystem.Spacing.small) {
                        Image(systemName: "exclamationmark.circle")
                            .imageScale(.large)
                        Text(DesignSystem.emptyStateMessage)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: DesignSystem.Cards.defaultHeight)
            } else {
                // Render a card per item (structural only)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: DesignSystem.Spacing.medium)]) {
                    ForEach(Array(items.indices), id: \.self) { idx in
                        DesignCard(imageName: "Tahoe", material: .constant(DesignSystem.materials.first?.material ?? Material.regularMaterial)) {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                                Text(title)
                                    .font(DesignSystem.Typography.body)
                                Text("Item \(idx + 1)")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: DesignSystem.Cards.defaultHeight)
                    }
                }
            }
        }
        .padding(.bottom, DesignSystem.Spacing.large)
    }
}

#Preview {
    // Default preview shows empty-state cards
    DashboardView()
}
