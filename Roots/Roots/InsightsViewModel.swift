import Foundation
import Combine

final class InsightsViewModel: ObservableObject {
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
        let stats = UsageStatsBuilder.build(
            from: historyStore,
            window: .days(windowDays)
        )
        insights = engine.generateInsights(from: stats)
    }
}
