import SwiftUI

struct SettingsPane_Courses: View {
    @EnvironmentObject private var coursesStore: CoursesStore
    @State private var courseToDelete: Course?
    @State private var showDeleteConfirmation = false

    private var activeCourses: [Course] { coursesStore.courses.filter { !$0.isArchived } }
    private var archivedCourses: [Course] { coursesStore.courses.filter { $0.isArchived } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RootsSpacing.l) {
                GroupBox {
                    VStack(alignment: .leading, spacing: RootsSpacing.s) {
                        Text("Manage your courses. Archive to hide from active views, or delete to remove completely.")
                            .rootsBodySecondary()

                        if activeCourses.isEmpty {
                            Text("No active courses.")
                                .rootsCaption()
                                .foregroundStyle(RootsColor.textSecondary)
                        } else {
                            VStack(spacing: RootsSpacing.s) {
                                ForEach(activeCourses) { course in
                                    courseRow(course: course, archived: false)
                                }
                            }
                        }
                    }
                } label: {
                    Label("Active Courses", systemImage: "text.book.closed")
                }

                if !archivedCourses.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: RootsSpacing.s) {
                            Text("Archived courses stay available for history but are hidden from daily views.")
                                .rootsBodySecondary()
                            VStack(spacing: RootsSpacing.s) {
                                ForEach(archivedCourses) { course in
                                    courseRow(course: course, archived: true)
                                }
                            }
                        }
                    } label: {
                        Label("Archived Courses", systemImage: "archivebox")
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: 720, alignment: .leading)
        .confirmationDialog(
            "Delete this course?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let course = courseToDelete {
                    coursesStore.deleteCourse(course)
                }
                courseToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                courseToDelete = nil
            }
        } message: {
            Text("This will remove the course and may affect linked assignments, grades, and plans. This action cannot be undone.")
        }
    }

    @ViewBuilder
    private func courseRow(course: Course, archived: Bool) -> some View {
        HStack(spacing: RootsSpacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(course.code)
                    .rootsBody()
                Text(course.title)
                    .rootsCaption()
                    .foregroundStyle(RootsColor.textSecondary)
                if archived {
                    Text("Archived")
                        .rootsCaption()
                        .foregroundStyle(RootsColor.textSecondary)
                }
            }

            Spacer()

            Button {
                coursesStore.toggleArchive(course)
            } label: {
                Image(systemName: course.isArchived ? "archivebox.fill" : "archivebox")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)

            Button {
                courseToDelete = course
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, RootsSpacing.s)
    }
}
