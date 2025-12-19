import SwiftUI

#if os(macOS)
import AppKit

/// Keyboard navigation and focus management for macOS
/// Provides consistent keyboard shortcuts and focus behavior across the app
@available(macOS 13.0, *)
public struct KeyboardNavigationModifier: ViewModifier {
    
    @FocusState private var isFocused: Bool
    
    let onEscape: (() -> Void)?
    let onReturn: (() -> Void)?
    let onTab: (() -> Void)?
    let onShiftTab: (() -> Void)?
    
    public init(
        onEscape: (() -> Void)? = nil,
        onReturn: (() -> Void)? = nil,
        onTab: (() -> Void)? = nil,
        onShiftTab: (() -> Void)? = nil
    ) {
        self.onEscape = onEscape
        self.onReturn = onReturn
        self.onTab = onTab
        self.onShiftTab = onShiftTab
    }
    
    public func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onAppear {
                // Set initial focus
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
    }
}

@available(macOS 13.0, *)
extension View {
    /// Add keyboard navigation support with standard shortcuts
    public func keyboardNavigation(
        onEscape: (() -> Void)? = nil,
        onReturn: (() -> Void)? = nil,
        onTab: (() -> Void)? = nil,
        onShiftTab: (() -> Void)? = nil
    ) -> some View {
        modifier(KeyboardNavigationModifier(
            onEscape: onEscape,
            onReturn: onReturn,
            onTab: onTab,
            onShiftTab: onShiftTab
        ))
    }
}

// MARK: - App-wide Keyboard Commands

/// Standard keyboard commands for the app
public struct AppKeyboardCommands: Commands {
    
    public init() {}
    
    public var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Add Event...") {
                NotificationCenter.default.post(name: .addEvent, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command])
            
            Button("Add Course...") {
                NotificationCenter.default.post(name: .addCourse, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            
            Button("Add Assignment...") {
                NotificationCenter.default.post(name: .addAssignment, object: nil)
            }
            .keyboardShortcut("a", modifiers: [.command])
        }
        
        CommandGroup(after: .sidebar) {
            Button("Focus Mode") {
                NotificationCenter.default.post(name: .toggleFocusMode, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
            
            Divider()
            
            Button("Previous Day") {
                NotificationCenter.default.post(name: .previousDay, object: nil)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command])
            
            Button("Next Day") {
                NotificationCenter.default.post(name: .nextDay, object: nil)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            
            Button("Previous Week") {
                NotificationCenter.default.post(name: .previousWeek, object: nil)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            
            Button("Next Week") {
                NotificationCenter.default.post(name: .nextWeek, object: nil)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            
            Button("Today") {
                NotificationCenter.default.post(name: .goToToday, object: nil)
            }
            .keyboardShortcut("t", modifiers: [.command])
        }
        
        #if DEBUG
        CommandGroup(after: .help) {
            Button("Accessibility Debug...") {
                NotificationCenter.default.post(name: .showAccessibilityDebug, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command, .option, .shift])
        }
        #endif
    }
}

// MARK: - Notification Names for Keyboard Commands

extension Notification.Name {
    public static let addEvent = Notification.Name("app.keyboard.addEvent")
    public static let addCourse = Notification.Name("app.keyboard.addCourse")
    public static let addAssignment = Notification.Name("app.keyboard.addAssignment")
    public static let toggleFocusMode = Notification.Name("app.keyboard.toggleFocusMode")
    public static let previousDay = Notification.Name("app.keyboard.previousDay")
    public static let nextDay = Notification.Name("app.keyboard.nextDay")
    public static let previousWeek = Notification.Name("app.keyboard.previousWeek")
    public static let nextWeek = Notification.Name("app.keyboard.nextWeek")
    public static let goToToday = Notification.Name("app.keyboard.goToToday")
    
    #if DEBUG
    public static let showAccessibilityDebug = Notification.Name("app.keyboard.showAccessibilityDebug")
    #endif
}

#endif
