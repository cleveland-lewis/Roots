import SwiftUI

struct CoursesView: View {
    @EnvironmentObject private var coursesStore: CoursesStore

    @State private var showingAddSemester = false
    @State private var showingAddCourse = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Title removed
                Color.clear.frame(height: 12)

                // Current semester selector
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Current semester")
                                .font(DesignSystem.Typography.subHeader)

                            Spacer()

                            Button {
                                showingAddSemester = true
                            } label: {
                                Label("Add Semester", systemImage: "plus")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.plain)
                        }

                        if coursesStore.semesters.isEmpty {
                            Text("No semesters yet. Add one to begin organizing your courses.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Semester", selection: Binding(
                                get: { coursesStore.currentSemesterId ?? coursesStore.semesters.first?.id },
                                set: { newId in
                                    if let id = newId,
                                       let sem = coursesStore.semesters.first(where: { $0.id == id }) {
                                        coursesStore.setCurrentSemester(sem)
                                    }
                                }
                            )) {
                                ForEach(coursesStore.semesters) { semester in
                                    Text(semester.name).tag(Optional(semester.id))
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Courses for current semester
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Courses in this semester")
                                .font(DesignSystem.Typography.subHeader)

                            Spacer()

                            Button {
                                showingAddCourse = true
                            } label: {
                                Label("Add Course", systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if let semester = coursesStore.currentSemester,
                           !coursesStore.courses(in: semester).isEmpty {
                            CardGrid {
                                ForEach(coursesStore.courses(in: semester)) { course in
                                    CourseCard(course: course, semester: semester)
                                }
                            }
                        } else {
                            EmptyStateView(icon: "book.closed")
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 20)
            }
        }
        .sheet(isPresented: $showingAddSemester) {
            AddSemesterSheet()
                .environmentObject(coursesStore)
        }
        .sheet(isPresented: $showingAddCourse) {
            AddCourseSheet()
                .environmentObject(coursesStore)
        }
    }
}

// Define the course card (uniform style)
struct CourseCard: View {
    let course: Course
    let semester: Semester

    var body: some View {
        NavigationLink(destination: CourseDetailView(course: course, semester: semester)) {
            VStack(alignment: .leading, spacing: 6) {
                Text(course.code)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)

                Text(course.title)
                    .font(DesignSystem.Typography.subHeader)

                Text(semester.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
