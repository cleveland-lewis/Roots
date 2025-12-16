#if os(macOS)
import SwiftUI

struct PracticeTestGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var coursesStore: CoursesStore
    @Bindable var store: PracticeTestStore
    
    @State private var selectedCourse: Course?
    @State private var selectedTopics: [String] = []
    @State private var customTopic: String = ""
    @State private var difficulty: PracticeTestDifficulty = .medium
    @State private var questionCount: Int = 10
    @State private var includeMultipleChoice = true
    @State private var includeShortAnswer = true
    @State private var includeExplanation = false
    
    private let questionCountOptions = [5, 10, 15, 20]
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    courseSelectionSection
                    topicsSection
                    settingsSection
                    questionTypesSection
                }
                .padding(24)
            }
            
            bottomBar
        }
        .frame(width: 600, height: 700)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Generate Practice Test")
                    .font(.title2.bold())
                Text("Configure your practice test parameters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Course Selection
    
    private var courseSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Course", systemImage: "book.closed")
                .font(.headline)
            
            if coursesStore.courses.isEmpty {
                Text("No courses available. Please add a course first.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                Picker("Select Course", selection: $selectedCourse) {
                    Text("Select a course").tag(nil as Course?)
                    ForEach(coursesStore.courses) { course in
                        Text(course.code).tag(course as Course?)
                    }
                }
                .labelsHidden()
            }
        }
    }
    
    // MARK: - Topics
    
    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Topics (Optional)", systemImage: "tag")
                .font(.headline)
            
            Text("Specify topics to focus on, or leave blank for general practice")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if !selectedTopics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedTopics, id: \.self) { topic in
                            topicChip(topic)
                        }
                    }
                }
            }
            
            HStack {
                TextField("Add topic", text: $customTopic)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addCustomTopic)
                
                Button("Add") {
                    addCustomTopic()
                }
                .disabled(customTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private func topicChip(_ topic: String) -> some View {
        HStack(spacing: 4) {
            Text(topic)
                .font(.caption)
            
            Button {
                selectedTopics.removeAll { $0 == topic }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.blue.opacity(0.2))
        .clipShape(Capsule())
    }
    
    private func addCustomTopic() {
        let trimmed = customTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !selectedTopics.contains(trimmed) else { return }
        selectedTopics.append(trimmed)
        customTopic = ""
    }
    
    // MARK: - Settings
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Settings", systemImage: "slider.horizontal.3")
                .font(.headline)
            
            // Difficulty
            VStack(alignment: .leading, spacing: 8) {
                Text("Difficulty")
                    .font(.subheadline.bold())
                
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(PracticeTestDifficulty.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Question Count
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Number of Questions")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(questionCount)")
                        .foregroundStyle(.secondary)
                }
                
                Picker("Question Count", selection: $questionCount) {
                    ForEach(questionCountOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    // MARK: - Question Types
    
    private var questionTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Question Types", systemImage: "list.bullet.circle")
                .font(.headline)
            
            Text("Select at least one question type")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Toggle(isOn: $includeMultipleChoice) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Multiple Choice")
                        .font(.subheadline)
                    Text("Select from 4 options")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Toggle(isOn: $includeShortAnswer) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Short Answer")
                        .font(.subheadline)
                    Text("Brief written responses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Toggle(isOn: $includeExplanation) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Explanation")
                        .font(.subheadline)
                    Text("Detailed explanations with examples")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            Button("Generate Test") {
                generateTest()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canGenerate)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private var canGenerate: Bool {
        selectedCourse != nil && 
        (includeMultipleChoice || includeShortAnswer || includeExplanation)
    }
    
    private func generateTest() {
        guard let course = selectedCourse else { return }
        
        let request = PracticeTestRequest(
            courseId: course.id,
            courseName: course.code,
            topics: selectedTopics,
            difficulty: difficulty,
            questionCount: questionCount,
            includeMultipleChoice: includeMultipleChoice,
            includeShortAnswer: includeShortAnswer,
            includeExplanation: includeExplanation
        )
        
        Task {
            await store.generateTest(request: request)
        }
        
        dismiss()
    }
}

#endif
