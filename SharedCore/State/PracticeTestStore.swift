import Foundation
import SwiftUI

@Observable
class PracticeTestStore {
    
    var tests: [PracticeTest] = []
    var currentTest: PracticeTest?
    var isGenerating: Bool = false
    var summary: PracticeTestSummary = PracticeTestSummary()
    
    private let llmService: LocalLLMService
    private let storageKey = "practice_tests_v1"
    
    init(llmService: LocalLLMService = LocalLLMService()) {
        self.llmService = llmService
        loadTests()
    }
    
    // MARK: - Test Generation
    
    func generateTest(request: PracticeTestRequest) async {
        isGenerating = true
        
        let test = PracticeTest(
            courseId: request.courseId,
            courseName: request.courseName,
            topics: request.topics,
            difficulty: request.difficulty,
            questionCount: request.questionCount,
            status: .generating
        )
        
        await MainActor.run {
            tests.append(test)
            currentTest = test
        }
        
        do {
            let questions = try await llmService.generateQuestions(request: request)
            
            await MainActor.run {
                if let index = tests.firstIndex(where: { $0.id == test.id }) {
                    tests[index].questions = questions
                    tests[index].status = .ready
                    currentTest = tests[index]
                }
                isGenerating = false
                saveTests()
            }
        } catch {
            await MainActor.run {
                if let index = tests.firstIndex(where: { $0.id == test.id }) {
                    tests[index].status = .failed
                    tests[index].generationError = error.localizedDescription
                    currentTest = tests[index]
                }
                isGenerating = false
                saveTests()
            }
        }
    }
    
    func retryGeneration(testId: UUID) async {
        guard let test = tests.first(where: { $0.id == testId }),
              test.status == .failed else { return }
        
        let request = PracticeTestRequest(
            courseId: test.courseId,
            courseName: test.courseName,
            topics: test.topics,
            difficulty: test.difficulty,
            questionCount: test.questionCount
        )
        
        await MainActor.run {
            if let index = tests.firstIndex(where: { $0.id == testId }) {
                tests[index].status = .generating
                tests[index].generationError = nil
            }
        }
        
        await generateTest(request: request)
    }
    
    // MARK: - Test Taking
    
    func startTest(_ testId: UUID) {
        guard let index = tests.firstIndex(where: { $0.id == testId }),
              tests[index].status == .ready else { return }
        
        tests[index].status = .inProgress
        currentTest = tests[index]
        saveTests()
    }
    
    func answerQuestion(testId: UUID, questionId: UUID, answer: String, timeSpent: Double? = nil) {
        guard let testIndex = tests.firstIndex(where: { $0.id == testId }),
              let question = tests[testIndex].questions.first(where: { $0.id == questionId }) else { return }
        
        let isCorrect = llmService.validateAnswer(
            userAnswer: answer,
            correctAnswer: question.correctAnswer,
            format: question.format
        )
        
        let practiceAnswer = PracticeAnswer(
            questionId: questionId,
            userAnswer: answer,
            isCorrect: isCorrect,
            timeSpentSeconds: timeSpent
        )
        
        tests[testIndex].answers[questionId] = practiceAnswer
        currentTest = tests[testIndex]
        saveTests()
    }
    
    func submitTest(_ testId: UUID) {
        guard let index = tests.firstIndex(where: { $0.id == testId }) else { return }
        
        tests[index].status = .submitted
        tests[index].submittedAt = Date()
        currentTest = tests[index]
        
        saveTests()
        updateSummary()
    }
    
    // MARK: - Test Management
    
    func deleteTest(_ testId: UUID) {
        tests.removeAll { $0.id == testId }
        if currentTest?.id == testId {
            currentTest = nil
        }
        saveTests()
        updateSummary()
    }
    
    func clearCurrentTest() {
        currentTest = nil
    }
    
    func getTest(byId id: UUID) -> PracticeTest? {
        tests.first { $0.id == id }
    }
    
    func getTestsForCourse(_ courseId: UUID) -> [PracticeTest] {
        tests.filter { $0.courseId == courseId }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Analytics
    
    private func updateSummary() {
        let submittedTests = tests.filter { $0.status == .submitted }
        
        let totalTests = submittedTests.count
        let totalQuestions = submittedTests.reduce(0) { $0 + $1.questions.count }
        let totalCorrect = submittedTests.reduce(0) { $0 + $1.correctCount }
        let averageScore = totalQuestions > 0 ? Double(totalCorrect) / Double(totalQuestions) : 0
        
        // Calculate per-topic performance
        var topicStats: [String: (total: Int, correct: Int, dates: [Date])] = [:]
        
        for test in submittedTests {
            for topic in test.topics {
                let questionsPerTopic = test.questions.count / max(test.topics.count, 1)
                let correctPerTopic = test.correctCount / max(test.topics.count, 1)
                
                if var stats = topicStats[topic] {
                    stats.total += questionsPerTopic
                    stats.correct += correctPerTopic
                    stats.dates.append(test.submittedAt ?? test.createdAt)
                    topicStats[topic] = stats
                } else {
                    topicStats[topic] = (questionsPerTopic, correctPerTopic, [test.submittedAt ?? test.createdAt])
                }
            }
        }
        
        let topicPerformance = topicStats.mapValues { stats in
            TopicPerformance(
                topic: "",
                totalQuestions: stats.total,
                correctAnswers: stats.correct,
                averageScore: stats.total > 0 ? Double(stats.correct) / Double(stats.total) : 0,
                lastPracticed: stats.dates.max()
            )
        }
        
        // Calculate practice frequency
        var frequency: [Date: Int] = [:]
        let calendar = Calendar.current
        for test in submittedTests {
            let date = calendar.startOfDay(for: test.submittedAt ?? test.createdAt)
            frequency[date, default: 0] += 1
        }
        
        summary = PracticeTestSummary(
            totalTests: totalTests,
            totalQuestions: totalQuestions,
            averageScore: averageScore,
            topicPerformance: topicPerformance.reduce(into: [:]) { result, item in
                var performance = item.value
                performance.topic = item.key
                result[item.key] = performance
            },
            recentTests: Array(submittedTests.prefix(10)),
            practiceFrequency: frequency
        )
    }
    
    // MARK: - Persistence
    
    private func saveTests() {
        do {
            let data = try JSONEncoder().encode(tests)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save practice tests: \(error)")
        }
    }
    
    private func loadTests() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        
        do {
            tests = try JSONDecoder().decode([PracticeTest].self, from: data)
            updateSummary()
        } catch {
            print("Failed to load practice tests: \(error)")
            tests = []
        }
    }
}
