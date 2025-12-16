#if os(macOS)
import SwiftUI

struct PracticeTestTakingView: View {
    let test: PracticeTest
    @Bindable var store: PracticeTestStore
    
    @State private var currentQuestionIndex = 0
    @State private var userAnswers: [UUID: String] = [:]
    @State private var startTime = Date()
    @State private var questionStartTimes: [UUID: Date] = [:]
    @State private var showingSubmitConfirmation = false
    
    private var currentQuestion: PracticeQuestion? {
        guard currentQuestionIndex < test.questions.count else { return nil }
        return test.questions[currentQuestionIndex]
    }
    
    private var progress: Double {
        Double(userAnswers.count) / Double(test.questions.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            HStack(spacing: 0) {
                // Question navigation sidebar
                questionListSidebar
                
                Divider()
                
                // Main question area
                if let question = currentQuestion {
                    questionView(question)
                } else {
                    Text("No questions available")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            if test.status == .ready {
                store.startTest(test.id)
            }
            initializeQuestionTimers()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button {
                store.clearCurrentTest()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(test.courseName)
                    .font(.headline)
                
                if !test.topics.isEmpty {
                    Text(test.topics.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                // Progress indicator
                HStack(spacing: 8) {
                    Text("\(userAnswers.count)/\(test.questions.count)")
                        .font(.caption.monospacedDigit())
                    
                    ProgressView(value: progress)
                        .frame(width: 80)
                }
                
                Button("Submit Test") {
                    showingSubmitConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(userAnswers.count < test.questions.count)
                .alert("Submit Practice Test?", isPresented: $showingSubmitConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Submit", role: .destructive) {
                        submitTest()
                    }
                } message: {
                    if userAnswers.count < test.questions.count {
                        Text("You have answered \(userAnswers.count) out of \(test.questions.count) questions. Unanswered questions will be marked incorrect.")
                    } else {
                        Text("Are you sure you want to submit? You cannot change your answers after submission.")
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Question List Sidebar
    
    private var questionListSidebar: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(test.questions.enumerated()), id: \.element.id) { index, question in
                    questionNavButton(index: index, question: question)
                }
            }
            .padding(12)
        }
        .frame(width: 200)
        .background(.ultraThinMaterial)
    }
    
    private func questionNavButton(index: Int, question: PracticeQuestion) -> some View {
        Button {
            currentQuestionIndex = index
        } label: {
            HStack {
                Text("\(index + 1)")
                    .font(.headline)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(questionStatusColor(for: question))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(question.format.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if let answer = userAnswers[question.id] {
                        Text("Answered")
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                    } else {
                        Text("Not answered")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(currentQuestionIndex == index ? Color.accentColor.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func questionStatusColor(for question: PracticeQuestion) -> Color {
        if userAnswers[question.id] != nil {
            return .green.opacity(0.3)
        } else if test.questions[safe: currentQuestionIndex]?.id == question.id {
            return .blue.opacity(0.3)
        } else {
            return .gray.opacity(0.2)
        }
    }
    
    // MARK: - Question View
    
    private func questionView(_ question: PracticeQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Question header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Question \(currentQuestionIndex + 1) of \(test.questions.count)")
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
                    }
                    
                    Text(question.prompt)
                        .font(.title3)
                }
                
                // Answer input
                answerInput(for: question)
                
                Divider()
                
                // Navigation buttons
                HStack {
                    if currentQuestionIndex > 0 {
                        Button {
                            currentQuestionIndex -= 1
                        } label: {
                            Label("Previous", systemImage: "chevron.left")
                        }
                    }
                    
                    Spacer()
                    
                    if currentQuestionIndex < test.questions.count - 1 {
                        Button {
                            currentQuestionIndex += 1
                        } label: {
                            Label("Next", systemImage: "chevron.right")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func answerInput(for question: PracticeQuestion) -> some View {
        switch question.format {
        case .multipleChoice:
            multipleChoiceInput(question)
        case .shortAnswer:
            shortAnswerInput(question)
        case .explanation:
            explanationInput(question)
        }
    }
    
    private func multipleChoiceInput(_ question: PracticeQuestion) -> some View {
        VStack(spacing: 12) {
            ForEach(question.options ?? [], id: \.self) { option in
                Button {
                    saveAnswer(for: question, answer: option)
                } label: {
                    HStack {
                        Image(systemName: userAnswers[question.id] == option ? "circle.fill" : "circle")
                            .foregroundStyle(.blue)
                        
                        Text(option)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(userAnswers[question.id] == option ? Color.blue.opacity(0.1) : Color.clear)
                            .stroke(userAnswers[question.id] == option ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func shortAnswerInput(_ question: PracticeQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your answer:")
                .font(.subheadline.bold())
            
            TextEditor(text: Binding(
                get: { userAnswers[question.id] ?? "" },
                set: { saveAnswer(for: question, answer: $0) }
            ))
            .font(.body)
            .frame(minHeight: 120)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private func explanationInput(_ question: PracticeQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your explanation:")
                .font(.subheadline.bold())
            
            Text("Provide a detailed explanation with specific examples")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextEditor(text: Binding(
                get: { userAnswers[question.id] ?? "" },
                set: { saveAnswer(for: question, answer: $0) }
            ))
            .font(.body)
            .frame(minHeight: 200)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helpers
    
    private func saveAnswer(for question: PracticeQuestion, answer: String) {
        userAnswers[question.id] = answer
        
        let timeSpent = questionStartTimes[question.id].map { Date().timeIntervalSince($0) }
        store.answerQuestion(
            testId: test.id,
            questionId: question.id,
            answer: answer,
            timeSpent: timeSpent
        )
        
        // Reset timer for this question
        questionStartTimes[question.id] = Date()
    }
    
    private func initializeQuestionTimers() {
        for question in test.questions {
            if questionStartTimes[question.id] == nil {
                questionStartTimes[question.id] = Date()
            }
        }
    }
    
    private func submitTest() {
        store.submitTest(test.id)
    }
}

// Array safe subscript extension
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#endif
