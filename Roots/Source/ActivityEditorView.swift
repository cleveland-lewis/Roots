import SwiftUI

struct ActivityEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: TimerActivity
    @State private var selectedCourseID: UUID?
    @State private var selectedAssignmentID: UUID?
    @State private var selectedCollectionID: UUID?
    @State private var selectedCategory: StudyCategory?
    @State private var note: String
    @State private var emoji: String

    let collections: [ActivityCollection]
    let isEditing: Bool
    let onSave: (TimerActivity) -> Void
    let onCancel: () -> Void

    private let mockCourses: [UUID: String]
    private let mockAssignments: [UUID: String]

    init(activity: TimerActivity?, collections: [ActivityCollection], onSave: @escaping (TimerActivity) -> Void, onCancel: @escaping () -> Void) {
        let initial = activity ?? TimerActivity(name: "New Activity")
        _draft = State(initialValue: initial)
        _selectedCourseID = State(initialValue: initial.courseID)
        _selectedAssignmentID = State(initialValue: initial.assignmentID)
        _selectedCollectionID = State(initialValue: initial.collectionID)
        _selectedCategory = State(initialValue: initial.studyCategory)
        _note = State(initialValue: initial.note ?? "")
        _emoji = State(initialValue: initial.emoji ?? "")
        self.collections = collections
        self.isEditing = activity != nil
        self.onSave = onSave
        self.onCancel = onCancel

        let courses: [UUID: String] = [
            UUID(): "Biology 201",
            UUID(): "Calculus II",
            UUID(): "History Seminar",
            UUID(): "Computer Science"
        ]
        let assignments: [UUID: String] = [
            UUID(): "Lab Report",
            UUID(): "Essay Draft",
            UUID(): "Problem Set 5",
            UUID(): "Reading Reflection"
        ]
        self.mockCourses = courses
        self.mockAssignments = assignments
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Name", text: $draft.name)
                    TextField("Emoji", text: $emoji)
                        .frame(width: 80)
                    Picker("Study Category", selection: Binding(get: { selectedCategory ?? StudyCategory.reading }, set: { selectedCategory = $0 })) {
                        ForEach(StudyCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(header: Text("Links")) {
                    Picker("Course", selection: Binding(get: { selectedCourseID }, set: { selectedCourseID = $0 })) {
                        Text("None").tag(UUID?.none)
                        ForEach(mockCourses.sorted(by: { $0.value < $1.value }), id: \.key) { id, name in
                            Text(name).tag(Optional(id))
                        }
                    }

                    Picker("Assignment", selection: Binding(get: { selectedAssignmentID }, set: { selectedAssignmentID = $0 })) {
                        Text("None").tag(UUID?.none)
                        ForEach(mockAssignments.sorted(by: { $0.value < $1.value }), id: \.key) { id, name in
                            Text(name).tag(Optional(id))
                        }
                    }

                    Picker("Collection", selection: Binding(get: { selectedCollectionID }, set: { selectedCollectionID = $0 })) {
                        Text("None").tag(UUID?.none)
                        ForEach(collections) { collection in
                            Text(collection.name).tag(Optional(collection.id))
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Activity" : "New Activity")
#if os(iOS) || os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismissView() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private func save() {
        var updated = draft
        updated.courseID = selectedCourseID
        updated.assignmentID = selectedAssignmentID
        updated.collectionID = selectedCollectionID
        updated.studyCategory = selectedCategory
        updated.note = note.isEmpty ? nil : note
        updated.emoji = emoji.isEmpty ? nil : emoji
        onSave(updated)
        dismiss()
    }

    private func dismissView() {
        dismiss()
        onCancel()
    }
}
