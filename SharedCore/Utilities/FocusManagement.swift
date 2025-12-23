import SwiftUI

#if os(macOS)
import AppKit
#endif

// MARK: - Focus Coordinator

/// Central coordinator for managing focus state across the application
@MainActor
public final class FocusCoordinator: ObservableObject {
    public static let shared = FocusCoordinator()
    
    @Published public var currentFocusArea: FocusArea = .content
    @Published public var previousFocusArea: FocusArea?
    @Published public var focusHistory: [FocusArea] = []
    
    private init() {}
    
    /// Move focus to a specific area
    public func moveFocus(to area: FocusArea) {
        previousFocusArea = currentFocusArea
        focusHistory.append(currentFocusArea)
        currentFocusArea = area
        
        // Trim history to last 10 items
        if focusHistory.count > 10 {
            focusHistory.removeFirst()
        }
    }
    
    /// Return focus to previous area
    public func returnToPreviousFocus() {
        guard let previous = previousFocusArea else { return }
        currentFocusArea = previous
        previousFocusArea = focusHistory.popLast()
    }
    
    /// Reset focus to default
    public func resetFocus() {
        currentFocusArea = .content
        previousFocusArea = nil
        focusHistory.removeAll()
    }
}

// MARK: - Focus Areas

/// Defines the major focus areas in the application
public enum FocusArea: String, Hashable {
    case sidebar
    case content
    case toolbar
    case inspector
    case search
    case calendar
    case modal
    
    var description: String {
        switch self {
        case .sidebar: return "Sidebar"
        case .content: return "Main Content"
        case .toolbar: return "Toolbar"
        case .inspector: return "Inspector"
        case .search: return "Search"
        case .calendar: return "Calendar"
        case .modal: return "Modal Dialog"
        }
    }
}

// MARK: - Focus Environment Key

private struct FocusAreaKey: EnvironmentKey {
    static let defaultValue: FocusArea = .content
}

extension EnvironmentValues {
    public var focusArea: FocusArea {
        get { self[FocusAreaKey.self] }
        set { self[FocusAreaKey.self] = newValue }
    }
}

// MARK: - Focus Management Modifier

public struct FocusManagementModifier: ViewModifier {
    let area: FocusArea
    let onFocusGained: (() -> Void)?
    let onFocusLost: (() -> Void)?
    
    @ObservedObject private var coordinator = FocusCoordinator.shared
    @FocusState private var isFocused: Bool
    
    public init(
        area: FocusArea,
        onFocusGained: (() -> Void)? = nil,
        onFocusLost: (() -> Void)? = nil
    ) {
        self.area = area
        self.onFocusGained = onFocusGained
        self.onFocusLost = onFocusLost
    }
    
    public func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .environment(\.focusArea, area)
            .onChange(of: coordinator.currentFocusArea) { _, newArea in
                if newArea == area {
                    isFocused = true
                    onFocusGained?()
                } else if isFocused {
                    isFocused = false
                    onFocusLost?()
                }
            }
            .onChange(of: isFocused) { _, focused in
                if focused && coordinator.currentFocusArea != area {
                    coordinator.moveFocus(to: area)
                }
            }
    }
}

extension View {
    /// Manages focus for a specific area of the application
    public func focusManagement(
        area: FocusArea,
        onFocusGained: (() -> Void)? = nil,
        onFocusLost: (() -> Void)? = nil
    ) -> some View {
        modifier(FocusManagementModifier(
            area: area,
            onFocusGained: onFocusGained,
            onFocusLost: onFocusLost
        ))
    }
}

// MARK: - Keyboard Navigation Extensions

#if os(macOS)

/// Enhanced keyboard navigation with arrow keys, tab, escape, and custom shortcuts
public struct EnhancedKeyboardNavigationModifier: ViewModifier {
    
    let onArrowUp: (() -> Void)?
    let onArrowDown: (() -> Void)?
    let onArrowLeft: (() -> Void)?
    let onArrowRight: (() -> Void)?
    let onEscape: (() -> Void)?
    let onReturn: (() -> Void)?
    let onTab: (() -> Void)?
    let onShiftTab: (() -> Void)?
    let onSpace: (() -> Void)?
    let onDelete: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    
    public init(
        onArrowUp: (() -> Void)? = nil,
        onArrowDown: (() -> Void)? = nil,
        onArrowLeft: (() -> Void)? = nil,
        onArrowRight: (() -> Void)? = nil,
        onEscape: (() -> Void)? = nil,
        onReturn: (() -> Void)? = nil,
        onTab: (() -> Void)? = nil,
        onShiftTab: (() -> Void)? = nil,
        onSpace: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.onArrowUp = onArrowUp
        self.onArrowDown = onArrowDown
        self.onArrowLeft = onArrowLeft
        self.onArrowRight = onArrowRight
        self.onEscape = onEscape
        self.onReturn = onReturn
        self.onTab = onTab
        self.onShiftTab = onShiftTab
        self.onSpace = onSpace
        self.onDelete = onDelete
    }
    
    public func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onKeyPress(.upArrow) {
                onArrowUp?()
                return onArrowUp != nil ? .handled : .ignored
            }
            .onKeyPress(.downArrow) {
                onArrowDown?()
                return onArrowDown != nil ? .handled : .ignored
            }
            .onKeyPress(.leftArrow) {
                onArrowLeft?()
                return onArrowLeft != nil ? .handled : .ignored
            }
            .onKeyPress(.rightArrow) {
                onArrowRight?()
                return onArrowRight != nil ? .handled : .ignored
            }
            .onKeyPress(.escape) {
                onEscape?()
                return onEscape != nil ? .handled : .ignored
            }
            .onKeyPress(.return) {
                onReturn?()
                return onReturn != nil ? .handled : .ignored
            }
            .onKeyPress(.tab) {
                onTab?()
                return onTab != nil ? .handled : .ignored
            }
            .onKeyPress(.space) {
                onSpace?()
                return onSpace != nil ? .handled : .ignored
            }
            .onKeyPress(.delete) {
                onDelete?()
                return onDelete != nil ? .handled : .ignored
            }
            .onAppear {
                // Auto-focus on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
    }
}

extension View {
    /// Enhanced keyboard navigation with all standard keys
    public func enhancedKeyboardNavigation(
        onArrowUp: (() -> Void)? = nil,
        onArrowDown: (() -> Void)? = nil,
        onArrowLeft: (() -> Void)? = nil,
        onArrowRight: (() -> Void)? = nil,
        onEscape: (() -> Void)? = nil,
        onReturn: (() -> Void)? = nil,
        onTab: (() -> Void)? = nil,
        onShiftTab: (() -> Void)? = nil,
        onSpace: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) -> some View {
        modifier(EnhancedKeyboardNavigationModifier(
            onArrowUp: onArrowUp,
            onArrowDown: onArrowDown,
            onArrowLeft: onArrowLeft,
            onArrowRight: onArrowRight,
            onEscape: onEscape,
            onReturn: onReturn,
            onTab: onTab,
            onShiftTab: onShiftTab,
            onSpace: onSpace,
            onDelete: onDelete
        ))
    }
}

// MARK: - Focus Ring Style

/// Custom focus ring style for consistent appearance
public struct RootsFocusRingStyle: ViewModifier {
    let color: Color
    let width: CGFloat
    
    public init(color: Color = .accentColor, width: CGFloat = 2) {
        self.color = color
        self.width = width
    }
    
    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(color, lineWidth: width)
                    .opacity(0.5)
            )
    }
}

extension View {
    /// Apply custom focus ring styling
    public func rootsFocusRing(color: Color = .accentColor, width: CGFloat = 2) -> some View {
        modifier(RootsFocusRingStyle(color: color, width: width))
    }
}

#endif

// MARK: - Focusable Field

/// Wrapper for text fields with enhanced focus management
public struct FocusableField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let onCommit: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    
    public init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        onCommit: (() -> Void)? = nil
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
    }
    
    public var body: some View {
        TextField(title, text: $text)
            .focused($isFocused)
            .onSubmit {
                onCommit?()
            }
    }
}

// MARK: - First Responder

#if os(macOS)

/// Make a view the first responder on appear
public struct FirstResponderModifier: ViewModifier {
    @FocusState private var isFocused: Bool
    let delay: Double
    
    public init(delay: Double = 0.1) {
        self.delay = delay
    }
    
    public func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    isFocused = true
                }
            }
    }
}

extension View {
    /// Make this view the first responder when it appears
    public func makeFirstResponder(delay: Double = 0.1) -> some View {
        modifier(FirstResponderModifier(delay: delay))
    }
}

#endif

// MARK: - Focus Debugger

#if DEBUG

/// Visual debugger for focus state
public struct FocusDebugOverlay: View {
    @ObservedObject private var coordinator = FocusCoordinator.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Focus Debugger")
                .font(.caption.bold())
            Text("Current: \(coordinator.currentFocusArea.description)")
                .font(.caption2)
            if let previous = coordinator.previousFocusArea {
                Text("Previous: \(previous.description)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("History: \(coordinator.focusHistory.count) items")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding()
        .allowsHitTesting(false)
    }
}

extension View {
    /// Show focus debugging overlay
    public func showFocusDebugger(_ enabled: Bool = true) -> some View {
        ZStack {
            self
            if enabled {
                FocusDebugOverlay()
            }
        }
    }
}

#endif
