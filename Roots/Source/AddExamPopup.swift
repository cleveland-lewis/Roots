import SwiftUI
import UniformTypeIdentifiers

struct AddExamPopup: View {
    @EnvironmentObject var coursesStore: CoursesStore
    @EnvironmentObject var flashManager: FlashcardManager
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var selectedCourseId: UUID?
    @State private var date: Date = Date()
    @State private var weight: Double = 20

    @State private var uploadedURLs: [URL] = []
    @State private var showImporter = false

    @State private var generateStudyGuide: Bool = true
    @State private var createFlashcardDeck: Bool = true

    var body: some View {
        RootsPopupContainer(title: "New Exam", subtitle: "Add exam details and study materials") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Exam Title", text: $title)

                Picker("Course", selection: Binding(get: { selectedCourseId }, set: { selectedCourseId = $0 })) {
                    Text("Select course").tag(Optional<UUID>(nil))
                    ForEach(coursesStore.courses) { c in
                        Text(c.title).tag(Optional(c.id))
                    }
                }

                DatePicker("Date & Time", selection: $date)

                VStack(alignment: .leading) {
                    Text("Worth \(Int(weight))% of grade")
                    Slider(value: $weight, in: 0...100, step: 1)
                }

                Section(header: Text("Study Materials")) {
                    Button(action: { showImporter = true }) {
                        HStack { Image(systemName: "tray.and.arrow.up"); Text("Upload Syllabus / Practice Test") }
                    }
                    .buttonStyle(RootsLiquidButtonStyle())
                    .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf, .image]) { result in
                        switch result {
                        case .success(let url):
                            uploadedURLs.append(url)
                        case .failure(let err):
                            print("import failed: \(err)")
                        }
                    }

                    ForEach(uploadedURLs, id: \ .self) { url in
                        HStack {
                            Text(url.lastPathComponent)
                            Spacer()
                            Button(action: { uploadedURLs.removeAll { $0 == url } }) { Image(systemName: "xmark.circle") }
                                .buttonStyle(.plain)
                        }
                    }

                    Toggle("Generate Study Guide", isOn: $generateStudyGuide)
                        .disabled(uploadedURLs.isEmpty)

                    Toggle("Create Flashcard Deck", isOn: $createFlashcardDeck)
                        .disabled(uploadedURLs.isEmpty)
                }

                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                    Button("Save") {
                        saveExam()
                        dismiss()
                    }
                    .buttonStyle(RootsLiquidButtonStyle())
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        } footer: {
            EmptyView()
        }
    }

    private func saveExam() {
        let exam = Exam(title: title, courseId: selectedCourseId, dueDate: date, weightPercent: weight)

        // Create a placeholder exam entry in CoursesStore (not defined here) — for now just create deck if requested
        if createFlashcardDeck {
            let deckTitle = "Study: \(title)"
            let deck = flashManager.createDeck(title: deckTitle, courseID: selectedCourseId)
            // Add placeholder card per uploaded file
            for url in uploadedURLs {
                flashManager.addCard(to: deck.id, front: "From file: \(url.lastPathComponent)", back: "Notes to be generated")
            }
        }

        // Generate study plan tasks and inject them into the scheduler.
        let shouldGenerateStudyPlan = generateStudyGuide
        if shouldGenerateStudyPlan {
            let generatedTasks = PlannerService.shared.generateStudyBlocks(for: exam, fileURLs: uploadedURLs)
            for task in generatedTasks {
                AssignmentsStore.shared.addTask(task)
            }
        }
    }
}
