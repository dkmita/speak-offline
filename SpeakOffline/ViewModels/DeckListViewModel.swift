import Foundation
import GRDB
import Combine

@MainActor
final class DeckListViewModel: ObservableObject {
    @Published var decks: [DeckSummary] = []

    private var cancellable: AnyCancellable?
    private let database: AppDatabase

    struct DeckSummary: Identifiable {
        let id: Int64
        let name: String
        let description: String
        let totalCards: Int
        let dueCards: Int
    }

    init(database: AppDatabase = .shared) {
        self.database = database
        observe()
    }

    private func observe() {
        let observation = ValueObservation.tracking { db -> [DeckSummary] in
            let now = Date()
            let decks = try Deck.fetchAll(db)

            return try decks.map { deck in
                let totalCards = try deck.cards.fetchCount(db)
                let dueCards = try deck.cards
                    .filter(Column("nextReviewDate") <= now)
                    .fetchCount(db)

                return DeckSummary(
                    id: deck.id!,
                    name: deck.name,
                    description: deck.description,
                    totalCards: totalCards,
                    dueCards: dueCards
                )
            }
        }

        cancellable = observation
            .publisher(in: database.dbQueue, scheduling: .immediate)
            .catch { _ in Just([]) }
            .sink { [weak self] decks in
                self?.decks = decks
            }
    }
}
