import SwiftUI
import Combine

/// Centralized settings for Roots. Extend as needed and inject via @EnvironmentObject.
// Deprecated: pomodoro defaults migrated into AppSettingsModel. Keep this file empty to avoid breaking imports.
import Foundation

// Intentionally left minimal; prefer AppSettingsModel for persisted configuration.
final class RootsSettings: ObservableObject {
    static let shared = RootsSettings()
    private init() {}
}

