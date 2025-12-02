import SwiftUI

struct CurrentActivityView: View {
    @ObservedObject var viewModel: TimerPageViewModel
    var onChoose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Activity")
                .font(.headline)
            content
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var content: some View {
        Group {
            if let id = viewModel.currentActivityID, let activity = viewModel.activities.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        if let emoji = activity.emoji { Text(emoji).font(.title) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.name)
                                .font(.title3.weight(.semibold))
                            if let note = activity.note {
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        if let category = activity.studyCategory {
                            tag(category.displayName, systemName: "tag.fill")
                        }
                        if let collectionID = activity.collectionID, let collection = viewModel.collections.first(where: { $0.id == collectionID }) {
                            tag(collection.name, systemName: "folder.fill")
                        }
                        if activity.courseID != nil {
                            tag("Course", systemName: "book.fill")
                        }
                        if activity.assignmentID != nil {
                            tag("Assignment", systemName: "doc.text.fill")
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No activity selected")
                        .font(.title3.weight(.semibold))
                    Button(action: onChoose) {
                        Label("Choose Activity", systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private func tag(_ text: String, systemName: String) -> some View {
        Label(text, systemImage: systemName)
            .font(.caption2)
            .padding(6)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
