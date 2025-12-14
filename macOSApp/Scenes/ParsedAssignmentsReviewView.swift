#if os(macOS)
import SwiftUI

// MARK: - Parsed Assignment Review View

struct ParsedAssignmentsReviewView: View {
    @EnvironmentObject private var parsingStore: SyllabusParsingStore
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var coursesStore: CoursesStore
    
    let courseId: UUID
    @Environment(\.dismiss) private var dismiss
    
    @State private var parsedItems: [ParsedAssignment] = []
    @State private var approvedIds: Set<UUID> = []
    @State private var editingItem: ParsedAssignment? = nil
    @State private var showingImportConfirmation = false
    @State private var importSuccessCount = 0
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if parsedItems.isEmpty {
                emptyStateView
            } else {
                listView
            }
            
            footerView
        }
        .frame(width: 800, height: 600)
        .onAppear {
            loadParsedAssignments()
        }
        .sheet(item: $editingItem) { item in
            ParsedAssignmentEditSheet(
                assignment: item,
                onSave: { updated in
                    updateParsedAssignment(updated)
                },
                onCancel: {
                    editingItem = nil
                }
            )
        }
        .alert("Import Successful", isPresented: $showingImportConfirmation) {
            Button("OK") {
                showingImportConfirmation = false
                dismiss()
            }
        } message: {
            Text("\(importSuccessCount) assignment(s) imported successfully.")
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review Parsed Assignments")
                        .font(.title2.weight(.semibold))
                    Text("Approve items to import them into your assignments")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            
            Divider()
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Parsed Assignments")
                .font(.title3.weight(.semibold))
            Text("Parse a syllabus file to see assignments here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var listView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(parsedItems) { item in
                    ParsedAssignmentRow(
                        assignment: item,
                        isApproved: approvedIds.contains(item.id),
                        onToggleApproval: {
                            toggleApproval(item.id)
                        },
                        onEdit: {
                            editingItem = item
                        },
                        provenance: provenanceForItem(item)
                    )
                }
            }
            .padding()
        }
    }
    
    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Text("\(approvedIds.count) of \(parsedItems.count) approved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Select All") {
                    approvedIds = Set(parsedItems.map { $0.id })
                }
                .buttonStyle(.plain)
                
                Button("Deselect All") {
                    approvedIds.removeAll()
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                
                Button("Add Parsed Assignments") {
                    importApprovedAssignments()
                }
                .buttonStyle(.borderedProminent)
                .disabled(approvedIds.isEmpty)
                .padding(.leading, 16)
            }
            .padding()
        }
    }
    
    private func loadParsedAssignments() {
        parsedItems = parsingStore.parsedAssignmentsByCourse(courseId)
    }
    
    private func toggleApproval(_ id: UUID) {
        if approvedIds.contains(id) {
            approvedIds.remove(id)
        } else {
            approvedIds.insert(id)
        }
    }
    
    private func updateParsedAssignment(_ updated: ParsedAssignment) {
        parsingStore.updateParsedAssignment(updated)
        if let index = parsedItems.firstIndex(where: { $0.id == updated.id }) {
            parsedItems[index] = updated
        }
        editingItem = nil
    }
    
    private func provenanceForItem(_ item: ParsedAssignment) -> String {
        guard let job = parsingStore.parsingJobs.first(where: { $0.id == item.jobId }),
              let file = coursesStore.courseFiles.first(where: { $0.id == job.fileId }) else {
            return "Unknown source"
        }
        return file.filename
    }
    
    private func importApprovedAssignments() {
        let approved = parsedItems.filter { approvedIds.contains($0.id) }
        var importedCount = 0
        
        for item in approved {
            // Check for duplicates by comparing title and date
            let isDuplicate = assignmentsStore.tasks.contains { task in
                task.courseId == item.courseId &&
                task.title == item.title &&
                task.due == item.dueDate
            }
            
            if !isDuplicate {
                let task = AppTask(
                    id: UUID(),
                    title: item.title,
                    courseId: item.courseId,
                    due: item.dueDate,
                    estimatedMinutes: 120,
                    minBlockMinutes: 30,
                    maxBlockMinutes: 90,
                    difficulty: 0.5,
                    importance: 0.7,
                    type: taskTypeFromInferred(item.inferredType),
                    locked: false,
                    attachments: [],
                    isCompleted: false,
                    category: taskTypeFromInferred(item.inferredType)
                )
                
                assignmentsStore.addTask(task)
                parsingStore.markAsImported(item.id, taskId: task.id)
                importedCount += 1
            }
        }
        
        importSuccessCount = importedCount
        showingImportConfirmation = true
        loadParsedAssignments()
    }
    
    private func taskTypeFromInferred(_ inferredType: String?) -> TaskType {
        guard let type = inferredType?.lowercased() else { return .practiceHomework }
        
        if type.contains("exam") || type.contains("test") {
            return .exam
        } else if type.contains("quiz") {
            return .quiz
        } else if type.contains("project") {
            return .project
        } else if type.contains("reading") {
            return .reading
        } else if type.contains("review") {
            return .review
        }
        
        return .practiceHomework
    }
}

// MARK: - Parsed Assignment Row

struct ParsedAssignmentRow: View {
    let assignment: ParsedAssignment
    let isApproved: Bool
    let onToggleApproval: () -> Void
    let onEdit: () -> Void
    let provenance: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: .init(
                get: { isApproved },
                set: { _ in onToggleApproval() }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(assignment.title)
                        .font(.body.weight(.semibold))
                    
                    if let type = assignment.inferredType {
                        Text(type)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 16) {
                    if let dueDate = assignment.dueDate {
                        Label(formatDate(dueDate), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let time = assignment.dueTime {
                        Label(time, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let anchor = assignment.provenanceAnchor {
                    Text("Source: \(anchor)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                
                Text("From: \(provenance)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Button("Edit") {
                onEdit()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isApproved ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Edit Sheet

struct ParsedAssignmentEditSheet: View {
    let assignment: ParsedAssignment
    let onSave: (ParsedAssignment) -> Void
    let onCancel: () -> Void
    
    @State private var title: String
    @State private var dueDate: Date
    @State private var dueTime: String
    @State private var inferredType: String
    
    init(assignment: ParsedAssignment, onSave: @escaping (ParsedAssignment) -> Void, onCancel: @escaping () -> Void) {
        self.assignment = assignment
        self.onSave = onSave
        self.onCancel = onCancel
        
        _title = State(initialValue: assignment.title)
        _dueDate = State(initialValue: assignment.dueDate ?? Date())
        _dueTime = State(initialValue: assignment.dueTime ?? "")
        _inferredType = State(initialValue: assignment.inferredType ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Parsed Assignment")
                .font(.title2.weight(.semibold))
            
            Form {
                TextField("Title", text: $title)
                
                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                
                TextField("Due Time (optional)", text: $dueTime)
                
                TextField("Type", text: $inferredType)
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("Save") {
                    var updated = assignment
                    updated.title = title
                    updated.dueDate = dueDate
                    updated.dueTime = dueTime.isEmpty ? nil : dueTime
                    updated.inferredType = inferredType.isEmpty ? nil : inferredType
                    onSave(updated)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

#endif
