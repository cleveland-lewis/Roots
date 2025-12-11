import SwiftUI

struct PermissionHelpPopup: View {
    enum PermissionKind { case calendar, reminders }
    let kind: PermissionKind
    let action: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        RootsPopupContainer(title: "Permission Required", subtitle: "Roots needs permission to access your data") {
            VStack(alignment: .leading, spacing: 12) {
                Text("1. Click the button below to open System Settings.")
                Text("2. Find 'Roots' in the list.")
                Text("3. Toggle the switch to ON.")
                Text("4. Return here to sync.")

                Spacer()

                HStack {
                    Spacer()
                    Button(kind == .calendar ? "Open Calendar Settings" : "Open Reminders Settings") {
                        action()
                        dismiss()
                    }
                    .buttonStyle(RootsLiquidButtonStyle())
                }
            }
        } footer: {
            EmptyView()
        }
    }
}
