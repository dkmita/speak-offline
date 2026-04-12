import Foundation
import GRDB
import Combine

@MainActor
final class FlashcardViewModel: ObservableObject {
    @Published var cards: [Card] = []
    @Published var currentIndex: Int = 0
    @Published var isShowingAnswer: Bool = false

    private var cancellable: AnyCancellable?
    private let database: AppDatabase
    let deckId: Int64
    let deckName: String

    var currentCard: Card? {
        guard !cards.isEmpty, currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var progress: String {
        guard !cards.isEmpty else { return "No cards due" }
        return "\(currentIndex + 1) / \(cards.count)"
    }

    var hasNext: Bool {
        currentIndex < cards.count - 1
    }

    init(deckId: Int64, deckName: String, database: AppDatabase = .shared) {
        self.deckId = deckId
        self.deckName = deckName
        self.database = database
        loadDueCards()
    }

    func loadDueCards() {
        do {
            cards = try database.dbQueue.read { db in
                try Card
                    .filter(Column("deckId") == deckId)
                    .filter(Column("nextReviewDate") <= Date())
                    .order(Column("nextReviewDate"))
                    .fetchAll(db)
            }
            currentIndex = 0
            isShowingAnswer = false
        } catch {
            cards = []
        }
    }

    func showAnswer() {
        isShowingAnswer = true
    }

    func rate(quality: Int) {
        guard var card = currentCard else { return }

        card.applyReview(quality: quality)

        do {
            try database.dbQueue.write { db in
                try card.update(db)

                var session = ReviewSession(
                    cardId: card.id!,
                    quality: quality,
                    reviewedAt: Date()
                )
                try session.insert(db)
            }
        } catch {
            // Silently fail for now — review is lost but app continues
        }

        advance()
    }

    private func advance() {
        if hasNext {
            currentIndex += 1
            isShowingAnswer = false
        } else {
            // Reload to see if any cards became due again (failed cards)
            loadDueCards()
        }
    }
}
