import Foundation
import Combine

final class InsightsViewModel: LoadableViewModel {
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String? = nil
    @Published var insights: [Insight] = []

    private let engine: InsightEngine
    private let historyStore: HistoryStore

    init(
        engine: InsightEngine = RuleBasedInsightEngine(),
        historyStore: HistoryStore = HistoryStoreImpl.shared
    ) {
        self.engine = engine
        self.historyStore = historyStore
    }

    func refresh(windowDays: Int = 14) {
        Task { [weak self] in
            _ = try await self?.withLoading(message: "Analyzing usage…") {
                guard let self else { return () }
                let stats = UsageStatsBuilder.build(
                    from: self.historyStore,
                    window: .days(windowDays)
                )
                await MainActor.run {
                    self.insights = self.engine.generateInsights(from: stats)
                }
                return ()
            }
        }
    }
}
