import SwiftUI
import AppKit

enum RootsWindowRole {
    case main
    case settings
    case popup
}

enum RootsWindowSizing {
    static let minMainWidth: CGFloat = 1024
    static let minMainHeight: CGFloat = 720

    static let minSettingsWidth: CGFloat = 900
    static let minSettingsHeight: CGFloat = 600

    static let minPopupWidth: CGFloat = 540
    static let minPopupHeight: CGFloat = 360

    static func applyMinimumSize(to window: NSWindow, role: RootsWindowRole) {
        switch role {
        case .main:
            window.contentMinSize = CGSize(width: minMainWidth, height: minMainHeight)
        case .settings:
            window.contentMinSize = CGSize(width: minSettingsWidth, height: minSettingsHeight)
        case .popup:
            window.contentMinSize = CGSize(width: minPopupWidth, height: minPopupHeight)
        }
    }
}
