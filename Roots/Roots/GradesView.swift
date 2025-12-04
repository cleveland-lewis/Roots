import SwiftUI

struct GradesView: View {
    // Empty model collections for now
    private let gradesSummary: [Any] = []
    private let courseGrades: [Any] = []
    private let gradeComponents: [Any] = []
    private let analytics: [Any] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                // Title removed

                LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                    // Overall Status
                    Section(header: Text("Overall Status").font(DesignSystem.Typography.body)) {
                        if gradesSummary.isEmpty {
                            AppCard {
                                VStack(spacing: DesignSystem.Spacing.small) {
                                    Image(systemName: "chart.bar")
                                        .imageScale(.large)
                                    Text("Overall Status")
                                        .font(DesignSystem.Typography.title)
                                    Text(DesignSystem.emptyStateMessage)
                                        .font(DesignSystem.Typography.body)
                                }
                            }
                            .frame(minHeight: DesignSystem.Cards.defaultHeight)
                        } else {
                            // TODO: render grades summary
                            Text("TODO: Overall status")
                        }
                    }

                    // By Course
                    Section(header: Text("By Course").font(DesignSystem.Typography.body)) {
                        if courseGrades.isEmpty {
                            AppCard {
                                VStack(spacing: DesignSystem.Spacing.small) {
                                    Image(systemName: "list.bullet")
                                        .imageScale(.large)
                                    Text("By Course")
                                        .font(DesignSystem.Typography.title)
                                    Text(DesignSystem.emptyStateMessage)
                                        .font(DesignSystem.Typography.body)
                                }
                            }
                            .frame(minHeight: DesignSystem.Cards.defaultHeight)
                        } else {
                            // TODO: render course grades
                            Text("TODO: By course")
                        }
                    }

                    // Grade Components
                    Section(header: Text("Grade Components").font(DesignSystem.Typography.body)) {
                        if gradeComponents.isEmpty {
                            AppCard {
                                VStack(spacing: DesignSystem.Spacing.small) {
                                    Image(systemName: "list.bullet.rectangle")
                                        .imageScale(.large)
                                    Text("Grade Components")
                                        .font(DesignSystem.Typography.title)
                                    Text(DesignSystem.emptyStateMessage)
                                        .font(DesignSystem.Typography.body)
                                }
                            }
                            .frame(minHeight: DesignSystem.Cards.defaultHeight)
                        } else {
                            // TODO: render components
                            Text("TODO: Grade components")
                        }
                    }

                    // Trends & Analytics
                    Section(header: Text("Trends & Analytics").font(DesignSystem.Typography.body)) {
                        if analytics.isEmpty {
                            AppCard {
                                VStack(spacing: DesignSystem.Spacing.small) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .imageScale(.large)
                                    Text("Trends & Analytics")
                                        .font(DesignSystem.Typography.title)
                                    Text(DesignSystem.emptyStateMessage)
                                        .font(DesignSystem.Typography.body)
                                }
                            }
                            .frame(minHeight: DesignSystem.Cards.defaultHeight)
                        } else {
                            // TODO: render analytics
                            Text("TODO: Trends & Analytics")
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.large)
        }
        .rootsSystemBackground()
    }
}

struct GradesView_Previews: PreviewProvider {
    static var previews: some View {
        GradesView()
    }
}
