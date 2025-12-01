import SwiftUI

struct LoadingIndicatorCircular: View {
    @Binding var progress: Double
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(appSettings.accentColor)
    }
}

struct LoadingIndicatorLinear: View {
    @Binding var progress: Double
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        ProgressView(value: progress, total: 100) {
            EmptyView()
        } currentValueLabel: {
            Text("\(Int(progress))%")
                .monospacedDigit()
                .font(.caption)
        }
        .progressViewStyle(.linear)
        .tint(appSettings.accentColor)
    }
}
