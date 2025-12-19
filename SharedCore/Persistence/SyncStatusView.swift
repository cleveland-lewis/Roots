import SwiftUI

#if DEBUG
struct SyncStatusView: View {
    @ObservedObject private var monitor = SyncStatusMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Status")
                .font(.headline)

            statusRow(label: "Last Remote Change", value: formattedDate(monitor.lastRemoteChangeAt))
            statusRow(label: "Last Event", value: monitor.lastEventDescription ?? "None")
            statusRow(label: "Last Error", value: monitor.lastErrorDescription ?? "None")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.Materials.card)
        )
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
#endif
