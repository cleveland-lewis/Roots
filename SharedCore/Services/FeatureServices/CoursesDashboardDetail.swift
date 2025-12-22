import SwiftUI

struct CoursesDashboardDetail: View {
    let course: CourseDashboard

    @EnvironmentObject private var appPreferences: AppPreferences

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Card
                courseHeaderCard

                // Middle Row - Meetings & Syllabus
                HStack(spacing: 16) {
                    meetingsCard
                    syllabusCard
                }

                // Quick Actions Row
                quickActionsRow

                Spacer(minLength: 80) // Space for floating nav bar
            }
            .padding(DesignSystem.Layout.padding.card)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header Card

    private var courseHeaderCard: some View {
        HStack(alignment: .top, spacing: DesignSystem.Layout.spacing.large) {
            // Left Side - Course Info
            VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                Text(course.title)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.primary)

                HStack(spacing: 16) {
                    Label(course.instructor, systemImage: "person.fill")
                    if let location = course.location {
                        Label(location, systemImage: "location.fill")
                    }
                }
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Label("\(course.credits, specifier: "%.1f") Credits", systemImage: "book.fill")
                    Label(course.term, systemImage: "calendar")
                }
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // Right Side - Circular Progress
            circularProgressView
        }
        .padding(DesignSystem.Layout.spacing.large)
        .glassCard(cornerRadius: 16)
    }

    private var circularProgressView: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                .frame(width: 120, height: 120)

            // Progress Circle
            Circle()
                .trim(from: 0, to: course.currentGrade / 100.0)
                .stroke(
                    AngularGradient(
                        colors: [.accentColor, .accentColor.opacity(0.7)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))

            // Center Text
            VStack(spacing: 2) {
                Text(course.gradePercentage)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.primary)

                Text("Current Grade")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Meetings Card

    private var meetingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Meetings", systemImage: "clock.fill")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()
            }

            if course.meetings.isEmpty {
                Text("No scheduled meetings")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                    ForEach(course.meetings) { meeting in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meeting.formattedDays)
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(.primary)

                            Text(meeting.formattedTime)
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }

            Button {
                // Open calendar
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.plus")
                        .font(DesignSystem.Typography.body)
                    Text("Add to Calendar")
                        .font(DesignSystem.Typography.body)
                }
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Layout.padding.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 14)
    }

    // MARK: - Syllabus Card

    private var syllabusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Syllabus Breakdown", systemImage: "chart.bar.fill")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                syllabusProgressBar(
                    title: "Homework",
                    percentage: course.syllabusWeights.homeworkPercentage,
                    progress: course.syllabusWeights.homeworkProgress,
                    color: .blue
                )

                syllabusProgressBar(
                    title: "Projects",
                    percentage: course.syllabusWeights.projectsPercentage,
                    progress: course.syllabusWeights.projectsProgress,
                    color: .green
                )

                syllabusProgressBar(
                    title: "Exams",
                    percentage: course.syllabusWeights.examsPercentage,
                    progress: course.syllabusWeights.examsProgress,
                    color: .orange
                )
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 14)
    }

    private func syllabusProgressBar(title: String, percentage: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()

                Text(percentage)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Quick Actions Row

    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            quickActionButton(title: "Add Assignment", icon: "doc.badge.plus")
            quickActionButton(title: "Add Exam", icon: "checkmark.seal")
            quickActionButton(title: "Add Grade", icon: "chart.line.uptrend.xyaxis")
            quickActionButton(title: "View Plan", icon: "calendar.day.timeline.left")
        }
    }

    private func quickActionButton(title: String, icon: String) -> some View {
        Button {
            // Action
        } label: {
            VStack(spacing: DesignSystem.Layout.spacing.small) {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.accentColor)

                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DesignSystem.Materials.card, in: RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Secondary Panel

    private var secondaryPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Course Overview")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.primary)

            HStack(alignment: .top, spacing: 16) {
                // Course Analytics
                analyticsColumn

                // Instructor Notes
                instructorNotesColumn

                // Upcoming Deadlines
                deadlinesColumn
            }
        }
        .padding(DesignSystem.Layout.padding.window)
        .glassCard(cornerRadius: 16)
    }

    private var analyticsColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Analytics", systemImage: "chart.xyaxis.line")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.primary)

            if hasAnalyticsData {
                VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                    analyticRow(
                        title: "Assignments",
                        value: "\(course.analytics.assignmentsCompleted)/\(course.analytics.assignmentsTotal)",
                        icon: "checkmark.circle.fill",
                        color: .accentColor
                    )

                    analyticRow(
                        title: "Average Score",
                        value: String(format: "%.1f%%", course.analytics.averageScore),
                        icon: "star.fill",
                        color: .accentColor
                    )

                    analyticRow(
                        title: "Attendance",
                        value: String(format: "%.0f%%", course.analytics.attendanceRate * 100),
                        icon: "person.fill.checkmark",
                        color: .accentColor
                    )

                    analyticRow(
                        title: "Hours Studied",
                        value: String(format: "%.1fh", course.analytics.hoursStudied),
                        icon: "clock.fill",
                        color: .accentColor
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No analytics yet.")
                        .font(.subheadline.weight(.semibold))
                    Text("We’ll show assignment progress and study time once this course has data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
    }

    private func analyticRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(color)
                .frame(width: 16)

            Text(title)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.primary)
        }
    }

    private var hasAnalyticsData: Bool {
        course.analytics.assignmentsTotal > 0
        || course.analytics.assignmentsCompleted > 0
        || course.analytics.averageScore > 0
        || course.analytics.hoursStudied > 0
    }

    private var instructorNotesColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Instructor Notes", systemImage: "note.text")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.primary)

            if let notes = course.instructorNotes {
                Text(notes)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            } else {
                Text("No notes available")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
    }

    private var deadlinesColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Upcoming Deadlines", systemImage: "calendar.badge.exclamationmark")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.primary)

            if course.upcomingDeadlines.isEmpty {
                Text("No upcoming deadlines")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                    ForEach(course.upcomingDeadlines.prefix(3)) { deadline in
                        deadlineRow(for: deadline)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
    }

    private func deadlineTypeColor(_ type: CourseDeadline.DeadlineType) -> Color {
        switch type {
        case .assignment: return .blue
        case .exam: return .red
        case .project: return .green
        case .quiz: return .orange
        }
    }
}

private extension CoursesDashboardDetail {
    func deadlineRow(for deadline: CourseDeadline) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(deadline.title)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()

                Text(deadline.type.rawValue)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(deadlineTypeColor(deadline.type), in: Capsule())
            }

            Text(deadline.formattedDate)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.secondary)
        }
        .padding(DesignSystem.Layout.spacing.small)
        .background(deadlineBackgroundColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    var deadlineBackgroundColor: Color {
    #if os(macOS)
        return Color(nsColor: .textBackgroundColor).opacity(0.5)
    #elseif canImport(UIKit)
        return Color(uiColor: .secondarySystemBackground).opacity(0.5)
    #else
        return Color.gray.opacity(0.2)
    #endif
    }
}
