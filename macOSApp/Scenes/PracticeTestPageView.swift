#if os(macOS)
import SwiftUI

struct PracticeTestPageView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var coursesStore: CoursesStore
    @State private var practiceStore: PracticeTestStore
    @State private var showingGenerator = false
    
    init() {
        _practiceStore = State(initialValue: PracticeTestStore())
    }
    
    var body: some View {
        NavigationStack {
            if let currentTest = practiceStore.currentTest {
                if currentTest.status == .generating {
                    generatingView(test: currentTest)
                } else if currentTest.status == .failed {
                    failedView(test: currentTest)
                } else if currentTest.status == .ready || currentTest.status == .inProgress {
                    testTakingView(test: currentTest)
                } else if currentTest.status == .submitted {
                    resultsView(test: currentTest)
                }
            } else {
                testListView
            }
        }
    }
    
    // MARK: - Test List View
    
    private var testListView: some View {
        VStack(spacing: 0) {
            headerView
            
            ScrollView {
                VStack(spacing: 16) {
                    if practiceStore.tests.isEmpty {
                        emptyStateView
                    } else {
                        statsCardsView
                        testHistoryView
                    }
                }
                .padding()
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Practice Tests")
                    .font(.largeTitle.bold())
                Text("Test your knowledge and track progress")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                showingGenerator = true
            } label: {
                Label("New Practice Test", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .sheet(isPresented: $showingGenerator) {
                PracticeTestGeneratorView(store: practiceStore)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("No Practice Tests Yet")
                .font(.title2.bold())
            
            Text("Create your first practice test to start learning")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingGenerator = true
            } label: {
                Label("Create Practice Test", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    private var statsCardsView: some View {
        HStack(spacing: 16) {
            statCard(
                title: "Total Tests",
                value: "\(practiceStore.summary.totalTests)",
                icon: "checkmark.circle.fill",
                color: .blue
            )
            
            statCard(
                title: "Average Score",
                value: String(format: "%.0f%%", practiceStore.summary.averageScore * 100),
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            )
            
            statCard(
                title: "Total Questions",
                value: "\(practiceStore.summary.totalQuestions)",
                icon: "questionmark.circle.fill",
                color: .orange
            )
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title.bold())
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var testHistoryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Tests")
                .font(.headline)
            
            ForEach(practiceStore.tests.sorted { $0.createdAt > $1.createdAt }) { test in
                testRow(test: test)
            }
        }
    }
    
    private func testRow(test: PracticeTest) -> some View {
        Button {
            practiceStore.currentTest = test
        } label: {
            HStack(spacing: 12) {
                statusIcon(for: test.status)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(test.courseName)
                        .font(.headline)
                    
                    if !test.topics.isEmpty {
                        Text(test.topics.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Label("\(test.questionCount) questions", systemImage: "number")
                        Label(test.difficulty.rawValue, systemImage: "slider.horizontal.3")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if test.status == .submitted, let score = test.score {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.0f%%", score * 100))
                            .font(.title3.bold())
                            .foregroundStyle(scoreColor(score))
                        
                        Text("\(test.correctCount)/\(test.questions.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    private func statusIcon(for status: PracticeTestStatus) -> some View {
        Group {
            switch status {
            case .generating:
                ProgressView()
                    .controlSize(.small)
            case .ready:
                Image(systemName: "circle.fill")
                    .foregroundStyle(.blue)
            case .inProgress:
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(.orange)
            case .submitted:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .frame(width: 24, height: 24)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.9 { return .green }
        if score >= 0.7 { return .blue }
        if score >= 0.5 { return .orange }
        return .red
    }
    
    // MARK: - Generating View
    
    private func generatingView(test: PracticeTest) -> some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Generating Practice Test")
                .font(.title2.bold())
            
            Text("Creating \(test.questionCount) questions for \(test.courseName)")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Button("Cancel") {
                practiceStore.clearCurrentTest()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Failed View
    
    private func failedView(test: PracticeTest) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)
            
            Text("Generation Failed")
                .font(.title2.bold())
            
            if let error = test.generationError {
                Text(error)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Button("Go Back") {
                    practiceStore.clearCurrentTest()
                }
                .buttonStyle(.bordered)
                
                Button("Retry") {
                    Task {
                        await practiceStore.retryGeneration(testId: test.id)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Test Taking View
    
    private func testTakingView(test: PracticeTest) -> some View {
        PracticeTestTakingView(test: test, store: practiceStore)
    }
    
    // MARK: - Results View
    
    private func resultsView(test: PracticeTest) -> some View {
        PracticeTestResultsView(test: test, store: practiceStore)
    }
}

#endif
