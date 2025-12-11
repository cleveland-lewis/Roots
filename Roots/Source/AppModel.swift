import SwiftUI
import Combine

final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var selectedPage: AppPage = .dashboard
    @Published var isPresentingAddHomework: Bool = false
    @Published var isPresentingAddExam: Bool = false

    // Reset publisher to coordinate app-level reset actions
    let resetPublisher = PassthroughSubject<Void, Never>()

    func requestReset() {
        resetPublisher.send(())
    }
}
