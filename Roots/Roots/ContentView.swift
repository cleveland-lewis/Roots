//
//  ContentView.swift
//  Roots
//
//  Created by Cleveland Lewis III on 11/30/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    private var spacing: CGFloat = 40.0
    private var glassStyle: Glass = .clear
    private var selectedTint: Color = .clear
    private var cornerRadius: CGFloat = 16.0

    @State private var selectedPage: AppPage = .dashboard
    @State private var isNavMenuVisible: Bool = false
    @State private var triggerHaptic: Bool = false
    private let selectedSensoryFeedback: SensoryFeedback = .selection

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                // Main page content
                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)

                // Custom top toolbar
                topToolbar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Glass dropdown nav menu
                if isNavMenuVisible {
                    navMenu
                        .padding(.top, 40)
                        .padding(.leading, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .zIndex(10)
                }
            }
            .frame(minWidth: 960, minHeight: 640)
            .background(Color.clear)
        }
    }

    // MARK: - Main content
    @ViewBuilder
    private var mainContent: some View {
        switch selectedPage {
        case .dashboard:
            DashboardView()
        case .calendar:
            CalendarView()
        case .planner:
            PlannerView()
        case .assignments:
            AssignmentsView()
        case .courses:
            CoursesView()
        case .grades:
            GradesView()
        }
    }

    // MARK: - Top toolbar
    private var topToolbar: some View {
        HStack(spacing: 12) {
            // Hamburger / three-bar menu
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    isNavMenuVisible.toggle()
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .medium))
                    .padding(6)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer()

            // Settings and add button
            HStack(spacing: 8) {
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape")
                }

                Button(action: addItem) {
                    Image(systemName: "plus")
                }
            }
            .buttonStyle(.plain)
            .padding(6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Dropdown nav menu
    private var navMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(AppPage.allCases) { page in
                Button {
                    selectedPage = page
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        isNavMenuVisible = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: page.systemImage)
                            .font(.system(size: 13, weight: .medium))
                            .bounceOnTap()
                        Text(page.title)
                            .font(.system(size: 13, weight: selectedPage == page ? .semibold : .regular))
                    }
                    .foregroundStyle(selectedPage == page ? Color.accentColor : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedPage == page ? Color.accentColor.opacity(0.15) : Color.clear)
                    )
                }
                .bounceOnTap()
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
                .shadow(radius: 12, y: 4)
        )
        .fixedSize()
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        #if os(macOS)
        HapticsManager.shared.play(.error)
        #endif
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

// Simple local GlassEffectContainer used for toolbar visuals
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    var glassStyle: Glass = .clear
    var selectedTint: Color = .clear
    var cornerRadius: CGFloat = 12
    var isInteractive: Bool = false

    let content: () -> Content

    init(spacing: CGFloat = 24, glassStyle: Glass = .clear, selectedTint: Color = .clear, cornerRadius: CGFloat = 12, isInteractive: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.glassStyle = glassStyle
        self.selectedTint = selectedTint
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
        self.content = content
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .padding(4)

            content()
                .padding(.horizontal, spacing)
        }
        .padding(.trailing)
    }
}

// Reusable icon style for standalone icons (not attached to text)
struct IconGlass: View {
    let systemName: String
    var offsetX: CGFloat = 0
    var glassStyle: Glass = .clear
    var selectedTint: Color = .clear
    var cornerRadius: CGFloat = 12
    var isInteractive: Bool = false

    var body: some View {
        Image(systemName: systemName)
            .font(.largeTitle)
            .frame(width: 80, height: 80)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.clear)
                    .glassEffect(glassStyle.tint(selectedTint).interactive(isInteractive), in: .rect(cornerRadius: cornerRadius))
            }
            .offset(x: offsetX, y: 0)
    }
}

