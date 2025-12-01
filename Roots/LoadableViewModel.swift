import Foundation
import Combine

protocol LoadableViewModel: AnyObject, ObservableObject {
    // Provide default objectWillChange publisher for conforming types that may use @Published
    var objectWillChange: ObservableObjectPublisher { get }

    var isLoading: Bool { get set }
    var loadingMessage: String? { get set }
}

extension LoadableViewModel {
    var objectWillChange: ObservableObjectPublisher { ObservableObjectPublisher() }

    func withLoading<T>(
        message: String? = nil,
        work: @escaping () async throws -> T
    ) async rethrows -> T {
        await MainActor.run {
            self.isLoading = true
            self.loadingMessage = message
        }

        defer {
            Task { @MainActor in
                self.isLoading = false
                self.loadingMessage = nil
            }
        }

        return try await work()
    }
}
