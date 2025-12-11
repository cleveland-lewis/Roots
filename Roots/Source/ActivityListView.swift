import SwiftUI

struct ActivityListView: View {
    @ObservedObject var viewModel: TimerPageViewModel
    var onAdd: () -> Void
    var onEdit: (TimerActivity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activities")
                    .font(DesignSystem.Typography.subHeader)
                Spacer()
                Button(action: onAdd) {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.glass)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Layout.spacing.small) {
                    collectionPill(name: "All", selected: viewModel.selectedCollectionID == nil) {
                        viewModel.selectedCollectionID = nil
                    }
                    ForEach(viewModel.collections) { collection in
                        collectionPill(name: collection.name, selected: viewModel.selectedCollectionID == collection.id) {
                            viewModel.selectedCollectionID = collection.id
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            Button {
                let newCollection = ActivityCollection(name: "Collection \(viewModel.collections.count + 1)")
                viewModel.addCollection(newCollection)
                viewModel.selectedCollectionID = newCollection.id
            } label: {
                Label("Add Collection", systemImage: "folder.badge.plus")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.glass)

            List {
                ForEach(viewModel.filteredActivities) { activity in
                    HStack(spacing: DesignSystem.Layout.spacing.small) {
                        if let emoji = activity.emoji { Text(emoji) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity.name)
                                .font(.subheadline.weight(.semibold))
                            HStack(spacing: 6) {
                                if let cat = activity.studyCategory {
                                    badge(cat.displayName, systemName: "tag.fill")
                                }
                                if activity.courseID != nil {
                                    badge("Course", systemName: "book.fill")
                                }
                                if activity.assignmentID != nil {
                                    badge("Assignment", systemName: "doc.text.fill")
                                }
                                if let collectionID = activity.collectionID, let collection = viewModel.collections.first(where: { $0.id == collectionID }) {
                                    badge(collection.name, systemName: "folder.fill")
                                }
                            }
                        }
                        Spacer()
                        if viewModel.currentActivityID == activity.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        Button(action: { onEdit(activity) }) {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectActivity(activity.id)
                    }
                }
                .onDelete { idx in
                    idx.map { viewModel.filteredActivities[$0].id }.forEach(viewModel.deleteActivity)
                }
            }
            .scrollContentBackground(.hidden)
            .frame(maxHeight: 360)
        }
    }

    private func collectionPill(name: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                        .stroke(selected ? Color.accentColor.opacity(0.6) : Color(nsColor: .separatorColor).opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func badge(_ text: String, systemName: String) -> some View {
        Label(text, systemImage: systemName)
            .font(.caption2)
            .padding(6)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
