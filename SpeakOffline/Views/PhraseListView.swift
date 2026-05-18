import SwiftUI
import GRDB
import Combine

struct PhraseListView: View {
    @StateObject private var viewModel = PhraseListViewModel()
    /// Tapping a row invokes this with the card's id. Lets the parent
    /// dismiss the sheet and surface the chosen card for study.
    var onSelect: ((Int64) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Status filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PhraseFilter.allCases) { filter in
                        FilterChip(
                            label: filter.label,
                            count: viewModel.countFor(filter),
                            isSelected: viewModel.filter == filter
                        ) {
                            viewModel.filter = filter
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Unit filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        label: "All Units",
                        count: viewModel.phrases.count,
                        isSelected: viewModel.selectedUnit == nil
                    ) {
                        viewModel.selectedUnit = nil
                    }
                    ForEach(viewModel.availableUnits, id: \.self) { unit in
                        FilterChip(
                            label: "Unit \(unit)",
                            count: viewModel.countForUnit(unit),
                            isSelected: viewModel.selectedUnit == unit
                        ) {
                            viewModel.selectedUnit = unit
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 6)
            }

            // Section jumper — only when a unit is selected
            if viewModel.selectedUnit != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.availableSections, id: \.self) { section in
                            Button {
                                viewModel.scrollToSection = section
                            } label: {
                                Text("S\(section)")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(viewModel.scrollToSection == section
                                                  ? Color.accentColor.opacity(0.2)
                                                  : Color.gray.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                }
            }

            Divider()

            // Phrase list
            ScrollViewReader { proxy in
                List(viewModel.phrases) { phrase in
                    Button {
                        onSelect?(phrase.id)
                    } label: {
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

                            HStack(spacing: 4) {
                                // Show last 5 reviews: green = correct, red = wrong, gray = no review
                                // Reversed so oldest is on the left, newest on the right
                                ForEach(0..<5, id: \.self) { i in
                                    let dot = phrase.recentResults[4 - i]
                                    Circle()
                                        .fill(dot == .correct ? Color.green
                                              : dot == .wrong ? Color.red
                                              : Color.gray.opacity(0.3))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .id(phrase.section)
                }
                .onChange(of: viewModel.scrollToSection) { _, section in
                    if let section {
                        withAnimation {
                            proxy.scrollTo(section, anchor: .top)
                        }
                    }
                }
            }
        }
        .navigationTitle("All Phrases")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search phrases...")
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Enum

enum PhraseFilter: String, CaseIterable, Identifiable {
    case all
    case seen
    case correct
    case wrong

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .seen: return "Seen"
        case .correct: return "Got right"
        case .wrong: return "Got wrong"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class PhraseListViewModel: ObservableObject {
    @Published var phrases: [PhraseRow] = []
    @Published var filter: PhraseFilter = .all {
        didSet { applyFilters() }
    }
    @Published var selectedUnit: Int? = nil {
        didSet { applyFilters() }
    }
    @Published var searchText: String = "" {
        didSet { reload() }
    }
    @Published var scrollToSection: Int?

    private var allPhrases: [PhraseRow] = []
    private let database: AppDatabase

    var availableUnits: [Int] {
        let units = Set(allPhrases.map(\.unit))
        return units.sorted()
    }

    var availableSections: [Int] {
        let sections = Set(phrases.map(\.section))
        return sections.sorted()
    }

    func countForUnit(_ unit: Int) -> Int {
        let unitFiltered = allPhrases.filter { $0.unit == unit }
        return unitFiltered.count(where: { matchesStatus($0) })
    }

    /// Each dot is .correct, .wrong, or .empty (no review yet for that slot)
    enum DotResult {
        case correct, wrong, empty
    }

    struct PhraseRow: Identifiable {
        let id: Int64
        let front: String
        let back: String
        let cefrLevel: String
        let unit: Int
        let section: Int
        let easeFactor: Double
        let repetitions: Int
        /// Last 5 reviews, most recent first. Padded with .empty if fewer than 5.
        let recentResults: [DotResult]

        /// Result of the single most recent review, or `.empty` if never
        /// reviewed. Drives the Got right / Got wrong filters: only the
        /// latest answer counts, not a stale failure from 4 reviews ago.
        var mostRecentResult: DotResult {
            recentResults.first ?? .empty
        }

        var lastWrong: Bool {
            mostRecentResult == .wrong
        }

        var easeLabel: String {
            String(format: "%.1f", easeFactor)
        }
    }

    init(database: AppDatabase = .shared) {
        self.database = database
        reload()
    }

    func countFor(_ filter: PhraseFilter) -> Int {
        allPhrases.count(where: { matchesStatus($0, filter: filter) })
    }

    private func matchesStatus(_ phrase: PhraseRow, filter: PhraseFilter? = nil) -> Bool {
        let f = filter ?? self.filter
        let mostRecent = phrase.mostRecentResult
        switch f {
        case .all: return true
        case .seen: return mostRecent != .empty
        case .correct: return mostRecent == .correct
        case .wrong: return mostRecent == .wrong
        }
    }

    private func applyFilters() {
        var result = allPhrases

        // Status filter
        result = result.filter { matchesStatus($0) }

        // Unit filter
        if let unit = selectedUnit {
            result = result.filter { $0.unit == unit }
        }

        phrases = result
    }

    private func reload() {
        do {
            allPhrases = try database.dbQueue.read { db in
                // Fetch last 5 reviews per card, most recent first
                let rows = try Row.fetchAll(db, sql: """
                    SELECT cardId, quality FROM (
                        SELECT cardId, quality,
                               ROW_NUMBER() OVER (PARTITION BY cardId ORDER BY reviewedAt DESC) as rn
                        FROM reviewSession
                    ) WHERE rn <= 5
                    ORDER BY cardId, rn ASC
                """)

                var reviewMap: [Int64: [DotResult]] = [:]
                for row in rows {
                    let cardId: Int64 = row["cardId"]
                    let quality: Int = row["quality"]
                    let result: DotResult = quality >= 3 ? .correct : .wrong
                    reviewMap[cardId, default: []].append(result)
                }

                var query = Card.order(Column("section").asc, Column("id").asc)

                if !searchText.isEmpty {
                    let pattern = "%\(searchText)%"
                    query = query.filter(
                        Column("front").like(pattern) || Column("back").like(pattern)
                    )
                }

                return try query.fetchAll(db).compactMap { card -> PhraseRow? in
                    guard let id = card.id else { return nil }

                    // Pad to 5 dots: recent results + empty slots
                    var results = reviewMap[id] ?? []
                    while results.count < 5 {
                        results.append(.empty)
                    }

                    return PhraseRow(
                        id: id,
                        front: card.front,
                        back: card.back,
                        cefrLevel: card.cefrLevel,
                        unit: card.unit,
                        section: card.section,
                        easeFactor: card.easeFactor,
                        repetitions: card.repetitions,
                        recentResults: results
                    )
                }
            }

            applyFilters()
        } catch {
            allPhrases = []
            phrases = []
        }
    }
}
