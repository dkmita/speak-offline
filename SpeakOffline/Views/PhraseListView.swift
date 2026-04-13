import SwiftUI
import GRDB
import Combine

struct PhraseListView: View {
    @StateObject private var viewModel = PhraseListViewModel()

    var body: some View {
        List(viewModel.phrases) { phrase in
            VStack(alignment: .leading, spacing: 6) {
                Text(phrase.front)
                    .font(.subheadline)
                    .bold()
                Text(phrase.back)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Label(phrase.cefrLevel, systemImage: "graduationcap")
                    Label("S\(phrase.section)", systemImage: "number")
                    Label(phrase.easeLabel, systemImage: "brain")
                    Label("\(phrase.repetitions)x", systemImage: "arrow.counterclockwise")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)

                if phrase.repetitions > 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            Circle()
                                .fill(i < phrase.strengthDots ? Color.green : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                        Text(phrase.strengthLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Not yet reviewed")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 2)
        }
        .navigationTitle("All Phrases")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search phrases...")
    }
}

// MARK: - ViewModel

@MainActor
final class PhraseListViewModel: ObservableObject {
    @Published var phrases: [PhraseRow] = []
    @Published var searchText: String = "" {
        didSet { loadPhrases() }
    }

    private let database: AppDatabase

    struct PhraseRow: Identifiable {
        let id: Int64
        let front: String
        let back: String
        let cefrLevel: String
        let section: Int
        let easeFactor: Double
        let repetitions: Int

        var easeLabel: String {
            String(format: "%.1f", easeFactor)
        }

        // 0-5 dots based on ease factor and repetitions
        var strengthDots: Int {
            if repetitions == 0 { return 0 }
            let score = min(easeFactor * Double(min(repetitions, 5)) / 12.5, 1.0)
            return max(1, Int(round(score * 5)))
        }

        var strengthLabel: String {
            switch strengthDots {
            case 0: return "New"
            case 1: return "Weak"
            case 2: return "Learning"
            case 3: return "OK"
            case 4: return "Good"
            case 5: return "Strong"
            default: return ""
            }
        }
    }

    init(database: AppDatabase = .shared) {
        self.database = database
        loadPhrases()
    }

    func loadPhrases() {
        do {
            phrases = try database.dbQueue.read { db in
                var query = Card.order(Column("section").asc, Column("id").asc)

                if !searchText.isEmpty {
                    let pattern = "%\(searchText)%"
                    query = query.filter(
                        Column("front").like(pattern) || Column("back").like(pattern)
                    )
                }

                return try query.fetchAll(db).compactMap { card -> PhraseRow? in
                    guard let id = card.id else { return nil }
                    return PhraseRow(
                        id: id,
                        front: card.front,
                        back: card.back,
                        cefrLevel: card.cefrLevel,
                        section: card.section,
                        easeFactor: card.easeFactor,
                        repetitions: card.repetitions
                    )
                }
            }
        } catch {
            phrases = []
        }
    }
}
