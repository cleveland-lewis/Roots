import SwiftUI
import EventKit
#if os(macOS)
import AppKit
#endif

struct CalendarView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case month = "Month"
        case week = "Week"
        case agenda = "Agenda"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .month

    // No sample events — empty state only
    private let events: [Any] = []

    @EnvironmentObject var permissions: PermissionsManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                // Top bar: month navigation + view mode toggles
                HStack(spacing: DesignSystem.Spacing.medium) {
                    HStack(spacing: DesignSystem.Spacing.small) {
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.borderless)
                        .disabled(true) // placeholder

                        Button(action: {}) {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.borderless)
                        .disabled(true) // placeholder
                    }

                    Picker("View", selection: $mode) {
                        ForEach(Mode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)

                    Spacer()
                }

                // Main content area
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                    // Month grid area (TODO: implement grid)
                    // If there are no events for the selected mode, show empty state
                    if events.isEmpty {
                        if permissions.calendarStatus == .denied || permissions.calendarStatus == .restricted {
                            DesignCard(imageName: "Tahoe", material: .constant(DesignSystem.materials.first?.material ?? Material.regularMaterial)) {
                                VStack(spacing: DesignSystem.Spacing.small) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .imageScale(.large)
                                    Text("Calendar access is turned off")
                                        .font(DesignSystem.Typography.title)
                                    Text("Enable Calendar access in System Settings → Privacy so Roots can show your schedule.")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(.primary)
                                    Button("Open System Settings") {
                                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                            #if os(macOS)
                                            NSWorkspace.shared.open(url)
                                            #endif
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .onAppear {
                                #if os(macOS)
                                HapticsManager.shared.play(.warning)
                                #endif
                            }
                            .frame(minHeight: DesignSystem.Cards.defaultHeight)
                        } else {
                            DesignCard(imageName: "Tahoe", material: .constant(DesignSystem.materials.first?.material ?? Material.regularMaterial)) {
                                VStack(spacing: DesignSystem.Spacing.small) {
                                    Image(systemName: "calendar")
                                        .imageScale(.large)
                                    Text("Calendar")
                                        .font(DesignSystem.Typography.title)
                                    Text(DesignSystem.emptyStateMessage)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .frame(minHeight: DesignSystem.Cards.defaultHeight)
                        }
                    } else {
                        // TODO: display calendar content when events exist
                        Text("TODO: Calendar content")
                    }

                    // Agenda list area (TODO)
                    // Today section (TODO)
                }
            }
            .padding(DesignSystem.Spacing.large)
        }
        .navigationTitle("Calendar")
        .onAppear {
            permissions.requestCalendarIfNeeded()
            permissions.requestRemindersIfNeeded()
        }
        .background(DesignSystem.background(for: .light))
    }
}

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView()
    }
}
