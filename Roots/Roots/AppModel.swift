import SwiftUI
import Combine

final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var selectedPage: AppPage = .dashboard
    @Published var isPresentingAddHomework: Bool = false
    @Published var isPresentingAddExam: Bool = false
}
