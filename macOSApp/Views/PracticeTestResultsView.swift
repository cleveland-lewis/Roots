#if os(macOS)
import SwiftUI

struct PracticeTestResultsView: View {
    let test: PracticeTest
    @Bindable var store: PracticeTestStore
    
    @State private var selectedQuestionId: UUID?
    
    private var score: Double {
        test.score ?? 0
    }
    
    private var scorePercentage: String {
        String(format: "%.0f%%", score * 100)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            HStack(spacing: 0) {
                // Results overview sidebar
                resultsSidebar
                
                Divider()
                
                // Question review area
                if let questionId = selectedQuestionId,
                   let question = test.questions.first(where: { $0.id == questionId }) {
                    questionReviewView(question)
                } else {
                    emptySelectionView
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button {
                store.clearCurrentTest()
            } label: {
                Label("Back to Tests", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("Practice Test Results")
                    .font(.headline)
                
                Text(test.courseName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                retryTest()
            } label: {
                Label("New Test", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Results Sidebar
    
    private var resultsSidebar: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Score card
                scoreCard
                
                Divider()
                
                // Question list
                VStack(spacing: 8) {
                    Text("Review Questions")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(test.questions) { question in
                        questionResultButton(question)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .onAppear {
            if selectedQuestionId == nil {
                selectedQuestionId = test.questions.first?.id
            }
        }
    }
    
    private var scoreCard: some View {
        VStack(spacing: 12) {
            // Overall score
            VStack(spacing: 4) {
                Text(scorePercentage)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
                
                Text("Overall Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Correct/Total
            HStack(spacing: 20) {
                statItem(
                    label: "Correct",
                    value: "\(test.correctCount)",
                    color: .green
                )
                
                statItem(
                    label: "Incorrect",
                    value: "\(test.questions.count - test.correctCount)",
                    color: .red
                )
            }
            
            // Performance indicator
            HStack {
                Image(systemName: performanceIcon)
                    .foregroundStyle(scoreColor)
                Text(performanceText)
                    .font(.subheadline.bold())
                    .foregroundStyle(scoreColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(scoreColor.opacity(0.2))
            .clipShape(Capsule())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var scoreColor: Color {
        if score >= 0.9 { return .green }
        if score >= 0.7 { return .blue }
        if score >= 0.5 { return .orange }
        return .red
    }
    
    private var performanceIcon: String {
        if score >= 0.9 { return "star.fill" }
        if score >= 0.7 { return "hand.thumbsup.fill" }
        if score >= 0.5 { return "checkmark.circle.fill" }
        return "exclamationmark.triangle.fill"
    }
    
    private var performanceText: String {
        if score >= 0.9 { return "Excellent!" }
        if score >= 0.7 { return "Good Job!" }
        if score >= 0.5 { return "Keep Practicing" }
        return "Needs Improvement"
    }
    
    private func questionResultButton(_ question: PracticeQuestion) -> some View {
        Button {
            selectedQuestionId = question.id
        } label: {
            HStack(spacing: 12) {
                // Status indicator
                Image(systemName: questionIsCorrect(question) ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(questionIsCorrect(question) ? .green : .red)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Q\(questionNumber(question))")
                        .font(.subheadline.bold())
                    
                    Text(question.format.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedQuestionId == question.id ? Color.accentColor.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Question Review
    
    @ViewBuilder
    private var emptySelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Select a question to review")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func questionReviewView(_ question: PracticeQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Question header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Question \(questionNumber(question))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if let bloomsLevel = question.bloomsLevel {
                            Text(bloomsLevel)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        
                        // Correctness badge
                        HStack(spacing: 4) {
                            Image(systemName: questionIsCorrect(question) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            Text(questionIsCorrect(question) ? "Correct" : "Incorrect")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(questionIsCorrect(question) ? .green : .red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((questionIsCorrect(question) ? Color.green : Color.red).opacity(0.2))
                        .clipShape(Capsule())
                    }
                    
                    Text(question.prompt)
                        .font(.title3)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                
                // User's answer
                if let userAnswer = test.answers[question.id]?.userAnswer {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Your Answer", systemImage: "person.fill")
                            .font(.headline)
                        
                        answerDisplay(question: question, answer: userAnswer, isUserAnswer: true)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(questionIsCorrect(question) ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    )
                }
                
                // Correct answer
                if !questionIsCorrect(question) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Correct Answer", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        
                        answerDisplay(question: question, answer: question.correctAnswer, isUserAnswer: false)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                }
                
                // Explanation
                VStack(alignment: .leading, spacing: 12) {
                    Label("Explanation", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    
                    Text(question.explanation)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.blue.opacity(0.1))
                )
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func answerDisplay(question: PracticeQuestion, answer: String, isUserAnswer: Bool) -> some View {
        switch question.format {
        case .multipleChoice:
            Text(answer)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.background)
                )
        case .shortAnswer, .explanation:
            Text(answer)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.background)
                )
        }
    }
    
    // MARK: - Helpers
    
    private func questionIsCorrect(_ question: PracticeQuestion) -> Bool {
        test.answers[question.id]?.isCorrect ?? false
    }
    
    private func questionNumber(_ question: PracticeQuestion) -> Int {
        (test.questions.firstIndex { $0.id == question.id } ?? 0) + 1
    }
    
    private func retryTest() {
        let request = PracticeTestRequest(
            courseId: test.courseId,
            courseName: test.courseName,
            topics: test.topics,
            difficulty: test.difficulty,
            questionCount: test.questionCount
        )
        
        Task {
            await store.generateTest(request: request)
        }
    }
}

#endif
