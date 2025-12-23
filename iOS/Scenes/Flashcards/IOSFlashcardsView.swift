#if os(iOS)
import SwiftUI

struct IOSFlashcardsView: View {
    @EnvironmentObject private var settings: AppSettingsModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text(NSLocalizedString("ios.flashcards.title", comment: "Flashcards"))
                .font(.largeTitle.weight(.bold))
            
            Text(NSLocalizedString("ios.flashcards.coming_soon", comment: "Flashcard decks and study sessions coming soon"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.appBackground)
    }
}
#endif
