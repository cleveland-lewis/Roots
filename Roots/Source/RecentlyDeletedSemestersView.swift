import SwiftUI

struct RecentlyDeletedSemestersView: View {
    @EnvironmentObject var coursesStore: CoursesStore

    var body: some View {
        List {
            if coursesStore.recentlyDeletedSemesters.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: DesignSystem.Layout.spacing.small) {
                        Image(systemName: "tray.full")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(.tertiary)
                        Text("No recently deleted semesters.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ForEach(coursesStore.recentlyDeletedSemesters) { semester in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(semester.name)
                            .font(DesignSystem.Typography.subHeader)
                        Text("\(semester.startDate.formatted(date: .abbreviated, time: .omitted)) – \(semester.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button("Recover") {
                                coursesStore.recoverSemester(semester.id)
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Delete Immediately", role: .destructive) {
                                coursesStore.permanentlyDeleteSemester(semester.id)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Recently Deleted")
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    RecentlyDeletedSemestersView()
        .environmentObject(CoursesStore())
}
#endif
