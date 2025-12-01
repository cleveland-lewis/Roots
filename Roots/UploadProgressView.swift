import SwiftUI

struct UploadProgressView: View {
    @State private var uploadProgress: Double = 0.5
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ViewThatFits(in: .horizontal) {

            // 1. Full layout (text + bar + spacer)
            HStack(spacing: 8) {
                Text(uploadProgress.formatted(.percent))
                    .monospacedDigit()

                ProgressView(value: uploadProgress)
                    .frame(width: 100)

                Spacer()
            }

            // 2. Compact layout (just the bar)
            ProgressView(value: uploadProgress)
                .frame(width: 100)

            // 3. Ultra-compact (just text)
            HStack {
                Text(uploadProgress.formatted(.percent))
                    .monospacedDigit()
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .onReceive(timer) { _ in
            // demo animation: loop from 0 → 1
            uploadProgress += 0.01
            if uploadProgress > 1 { uploadProgress = 0 }
        }
    }
}

struct UploadProgressView_Previews: PreviewProvider {
    static var previews: some View {
        AppCard {
            UploadProgressView()
        }
        .padding()
        .frame(width: 360)
    }
}
