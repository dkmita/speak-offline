import SwiftUI

struct DeckListView: View {
    @StateObject private var viewModel = DeckListViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.decks) { deck in
                NavigationLink(value: deck) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deck.name)
                            .font(.headline)
                        Text(deck.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("\(deck.totalCards) cards")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if deck.dueCards > 0 {
                                Text("\(deck.dueCards) due")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("SpeakOffline")
            .navigationDestination(for: DeckListViewModel.DeckSummary.self) { deck in
                FlashcardView(viewModel: FlashcardViewModel(deckId: deck.id, deckName: deck.name))
            }
        }
    }
}

extension DeckListViewModel.DeckSummary: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
