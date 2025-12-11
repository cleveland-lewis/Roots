import Foundation
import SwiftUI
import Combine

@MainActor
final class FlashcardManager: ObservableObject {
    static let shared = FlashcardManager()

    @Published private(set) var decks: [FlashcardDeck] = []

    enum FlashcardRating: Int {
        case again = 0
        case hard = 3
        case good = 4
        case easy = 5
    }

    private var storageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("flashcards.json")
    }

    private init() {
        load()
    }

    func createDeck(title: String, courseID: UUID? = nil) -> FlashcardDeck {
        let deck = FlashcardDeck(title: title, courseID: courseID)
        decks.append(deck)
        save()
        return deck
    }

    func addCard(to deckId: UUID, front: String, back: String, difficulty: FlashcardDifficulty = .medium) {
        guard let idx = decks.firstIndex(where: { $0.id == deckId }) else { return }
        var d = decks[idx]
        let card = Flashcard(frontText: front, backText: back, difficulty: difficulty, dueDate: Date())
        d.cards.append(card)
        decks[idx] = d
        save()
    }

    func updateDeck(_ deck: FlashcardDeck) {
        guard let idx = decks.firstIndex(where: { $0.id == deck.id }) else { return }
        decks[idx] = deck
        save()
    }

    func deck(withId id: UUID) -> FlashcardDeck? {
        decks.first(where: { $0.id == id })
    }

    func dueCards(for deckId: UUID, referenceDate: Date = Date()) -> [Flashcard] {
        guard let deck = deck(withId: deckId) else { return [] }
        return deck.cards.filter { $0.dueDate <= referenceDate }.sorted { $0.dueDate < $1.dueDate }
    }

    func grade(cardId: UUID, in deckId: UUID, rating: FlashcardRating, referenceDate: Date = Date()) {
        processReview(deckID: deckId, cardID: cardId, grade: rating, referenceDate: referenceDate)
    }

    func deleteDeck(_ deckId: UUID) {
        decks.removeAll { $0.id == deckId }
        save()
    }

    func exportToAnki(deck: FlashcardDeck) -> String {
        // CSV with Front,Back per line
        let lines = deck.cards.map { card in
            let front = card.frontText.replacingOccurrences(of: "\n", with: " ")
            let back = card.backText.replacingOccurrences(of: "\n", with: " ")
            let quotedFront = "\"\(front.replacingOccurrences(of: "\"", with: "\"\""))\""
            let quotedBack = "\"\(back.replacingOccurrences(of: "\"", with: "\"\""))\""
            return "\(quotedFront),\(quotedBack)"
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Persistence
    private func save() {
        do {
            let data = try JSONEncoder().encode(decks)
            try data.write(to: storageURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("[FlashcardManager] Failed to save flashcards: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            decks = []
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            decks = try JSONDecoder().decode([FlashcardDeck].self, from: data)
        } catch {
            print("[FlashcardManager] Failed to load flashcards: \(error)")
            decks = []
        }
    }

    // MARK: - Spaced Repetition (SM-2 inspired)
    func processReview(deckID: UUID, cardID: UUID, grade: FlashcardRating, referenceDate: Date = Date()) {
        guard let dIndex = decks.firstIndex(where: { $0.id == deckID }),
              let cIndex = decks[dIndex].cards.firstIndex(where: { $0.id == cardID }) else { return }

        var card = decks[dIndex].cards[cIndex]

        if grade == .again {
            card.repetition = 0
            card.interval = 0
        } else {
            if card.repetition == 0 {
                card.interval = 1
            } else if card.repetition == 1 {
                card.interval = 6
            } else {
                let newInterval = Double(max(card.interval, 1)) * card.easeFactor
                card.interval = Int(ceil(newInterval))
            }
            card.repetition += 1
        }

        if grade != .again {
            let q = Double(grade.rawValue)
            let newEF = card.easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
            card.easeFactor = max(1.3, newEF)
        }

        let calendar = Calendar.current
        if card.interval == 0 {
            card.dueDate = referenceDate
        } else {
            card.dueDate = calendar.date(byAdding: .day, value: card.interval, to: referenceDate) ?? referenceDate
        }
        card.lastReviewed = referenceDate

        decks[dIndex].cards[cIndex] = card
        save()
    }

    func estimateInterval(card: Flashcard, grade: FlashcardRating) -> String {
        if grade == .again { return "< 1m" }

        var nextInterval = 1
        if card.repetition == 0 {
            nextInterval = 1
        } else if card.repetition == 1 {
            nextInterval = 6
        } else {
            nextInterval = Int(ceil(Double(max(card.interval, 1)) * card.easeFactor))
        }

        if grade == .hard { nextInterval = max(1, Int(Double(nextInterval) * 0.8)) }
        if grade == .easy { nextInterval = Int(Double(nextInterval) * 1.3) }

        return "\(nextInterval)d"
    }
}
