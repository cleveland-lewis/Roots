import SwiftUI

struct CoursesView: View {
    @EnvironmentObject var coursesStore: CoursesStore

    @State private var isPresentingAddSheet = false
    @State private var editingCourse: Course? = nil
    @State private var sortOption: CourseSortOption = .nameAscending
    @State private var showArchived = false

    enum CourseSortOption {
        case nameAscending
        case codeAscending
        case termAscending
    }

    private var visibleCourses: [Course] {
        var list = coursesStore.courses
        if !showArchived {
            list = list.filter { !$0.isArchived }
        }

        switch sortOption {
        case .nameAscending:
            list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .codeAscending:
            list.sort { $0.code.localizedCaseInsensitiveCompare($1.code) == .orderedAscending }
        case .termAscending:
            list.sort { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
        }

        return list
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                // Header
                HStack(alignment: .center, spacing: DesignSystem.Spacing.medium) {
                    Text("Courses")
                        .font(DesignSystem.Typography.title)

                    Spacer()

                    // Toolbar area
                    HStack(spacing: DesignSystem.Spacing.small) {
                        Button(action: { isPresentingAddSheet = true }) {
                            Label("Add Course", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)

                        Menu {
                            Section("Sort by") {
                                Button("Name") { sortOption = .nameAscending }
                                Button("Code") { sortOption = .codeAscending }
                                Button("Term") { sortOption = .termAscending }
                            }

                            Section {
                                Toggle("Show Archived", isOn: $showArchived)
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }

                // Main area
                if visibleCourses.isEmpty {
                    DesignCard(imageName: "Tahoe", material: .constant(DesignSystem.materials.first?.material ?? Material.regularMaterial)) {
                        VStack(spacing: DesignSystem.Spacing.small) {
                            Image(systemName: "book.closed")
                                .imageScale(.large)
                            Text("Courses")
                                .font(DesignSystem.Typography.title)
                            Text(DesignSystem.emptyStateMessage)
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(.primary)
                        }
                    }
                    .frame(minHeight: DesignSystem.Cards.defaultHeight)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: DesignSystem.Spacing.medium)], spacing: DesignSystem.Spacing.medium) {
                        ForEach(visibleCourses, id: \.id) { course in
                            DesignCard(imageName: "Tahoe", material: .constant(DesignSystem.materials.first?.material ?? Material.regularMaterial)) {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                                    HStack {
                                        Circle()
                                            .fill(course.color)
                                            .frame(width: 14, height: 14)
                                        Text(course.name)
                                            .font(DesignSystem.Typography.body)
                                            .bold()
                                        Spacer()
                                        Text(course.code)
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(course.term)
                                        .font(DesignSystem.Typography.caption)
                                    Text(course.instructor)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(DesignSystem.Spacing.small)
                                .contextMenu {
                                    Button("Edit Course") { editingCourse = course }
                                    Button(course.isArchived ? "Unarchive" : "Archive") {
                                        var updated = course
                                        updated.isArchived.toggle()
                                        coursesStore.update(updated)
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        #if os(macOS)
                                        HapticsManager.shared.play(.error)
                                        #endif
                                        coursesStore.delete(course)
                                    }
                                }
                            }
                            .frame(minHeight: 120)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.large)
        }
        .background(DesignSystem.background(for: .light))
        .sheet(isPresented: $isPresentingAddSheet) {
            AddEditCourseView(mode: .new) { newCourse in
                coursesStore.add(newCourse)
            }
        }
        .sheet(item: $editingCourse) { course in
            AddEditCourseView(mode: .edit(course)) { updated in
                coursesStore.update(updated)
            }
        }
    }
}

struct CoursesView_Previews: PreviewProvider {
    static var previews: some View {
        CoursesView()
            .environmentObject(CoursesStore())
    }
}
