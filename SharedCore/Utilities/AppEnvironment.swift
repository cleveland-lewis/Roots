import SwiftUI

// MARK: - AppModel Environment Key

private struct AppModelKey: EnvironmentKey {
    static let defaultValue: AppModel = AppModel.shared
}

extension EnvironmentValues {
    var appModel: AppModel {
        get { self[AppModelKey.self] }
        set { self[AppModelKey.self] = newValue }
    }
}
