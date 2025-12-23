import SwiftUI

// MARK: - Scheduled Tests Section View

struct ScheduledTestsSection: View {
    @Bindable var store: ScheduledTestsStore
    var onStartTest: (ScheduledPracticeTest) -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with week navigation
            weekNavigationHeader
            
            if isExpanded {
                // Weekly calendar grid
                weeklyCalendarView
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Week Navigation Header
    
    private var weekNavigationHeader: some View {
        HStack {
            Text("Scheduled Tests")
                .font(.headline)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: store.goToPreviousWeek) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .help("Previous week")
                
                Button(action: store.goToThisWeek) {
                    Text("This Week")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(store.isCurrentWeek)
                .help("Go to current week")
                
                Button(action: store.goToNextWeek) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .help("Next week")
            }
            
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.borderless)
            .help(isExpanded ? "Collapse" : "Expand")
        }
        .padding(.bottom, isExpanded ? 16 : 0)
    }
    
    // MARK: - Weekly Calendar View
    
    private var weeklyCalendarView: some View {
        let daysOfWeek = Calendar.current.daysOfWeek(for: store.currentWeek)
        let hasTests = !store.testsForCurrentWeek().isEmpty
        
        return VStack(spacing: 12) {
            if !hasTests {
                emptyWeekBanner
            }
            ForEach(daysOfWeek, id: \.self) { day in
                dayRow(for: day)
            }
        }
    }
    
    private func dayRow(for date: Date) -> some View {
        let tests = store.testsForDay(date)
        let isToday = Calendar.current.isDateInToday(date)
        
        return VStack(alignment: .leading, spacing: 8) {
            // Day header
            HStack {
                Text(dayLabel(for: date))
                    .font(.subheadline)
                    .fontWeight(isToday ? .semibold : .regular)
                    .foregroundColor(isToday ? .blue : .primary)
                
                Text(dateLabel(for: date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isToday {
                    Text("Today")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            // Tests for this day
            if tests.isEmpty {
                Text("No scheduled tests")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 16)
            } else {
                ForEach(tests) { test in
                    testRow(test: test)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isToday ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
    
    private func testRow(test: ScheduledPracticeTest) -> some View {
        let status = store.computedStatus(for: test)
        
        return ViewThatFits(in: .horizontal) {
            testRowHorizontal(test: test, status: status)
            testRowVertical(test: test, status: status)
        }
    }

    private func testRowHorizontal(test: ScheduledPracticeTest, status: ScheduledTestStatus) -> some View {
        HStack(alignment: .top, spacing: 12) {
            timeColumn(for: test)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(test.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                subjectLine(for: test)

                HStack(spacing: 8) {
                    difficultyRow(for: test)
                    statusBadge(status: status)
                }
            }

            Spacer()

            startButton(for: test, status: status)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(status == .missed ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func testRowVertical(test: ScheduledPracticeTest, status: ScheduledTestStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                timeColumn(for: test)
                Spacer()
                statusBadge(status: status)
            }

            Text(test.title)
                .font(.subheadline)
                .fontWeight(.medium)

            subjectLine(for: test)

            HStack(spacing: 8) {
                difficultyRow(for: test)
                Spacer()
                startButton(for: test, status: status)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(status == .missed ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var emptyWeekBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("No tests scheduled this week.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func timeColumn(for test: ScheduledPracticeTest) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(timeLabel(for: test.scheduledAt))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if let minutes = test.estimatedMinutes {
                Text("\(minutes) min")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func subjectLine(for test: ScheduledPracticeTest) -> some View {
        HStack(spacing: 8) {
            Text(test.subject)
                .font(.caption)
                .foregroundColor(.secondary)

            if let unit = test.unitName {
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func difficultyRow(for test: ScheduledPracticeTest) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(level <= test.difficulty ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func startButton(for test: ScheduledPracticeTest, status: ScheduledTestStatus) -> some View {
        Button(action: { onStartTest(test) }) {
            Text("Start")
                .font(.caption)
                .fontWeight(.medium)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(status == .completed)
    }
    
    private func statusBadge(status: ScheduledTestStatus) -> some View {
        let (color, text) = statusInfo(status)
        
        return Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }
    
    private func statusInfo(_ status: ScheduledTestStatus) -> (Color, String) {
        switch status {
        case .scheduled:
            return (.blue, "Scheduled")
        case .completed:
            return (.green, "Completed")
        case .missed:
            return (.red, "Missed")
        case .archived:
            return (.gray, "Archived")
        }
    }
    
    // MARK: - Helpers
    
    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func timeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
