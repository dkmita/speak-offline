import SwiftUI
import GRDB
import Combine

@MainActor
final class FlashcardViewModel: ObservableObject {
    @Published var currentCard: Card?
    @Published var isShowingAnswer: Bool = false
    @Published var speechMatched: Bool? = nil
    @Published var cardsReviewed: Int = 0
    /// Last 5 reviews of the current card, most recent first.
    /// Padded with nil if fewer than 5 reviews exist. nil = no review yet.
    @Published var recentResults: [Bool?] = Array(repeating: nil, count: 5)

    let speechService: SpeechService
    let settings: UserSettings

    private var speechCancellable: AnyCancellable?
    private let database: AppDatabase
    let deckName: String

    /// Ring buffer of recently shown card IDs to prevent repeats within 20 cards
    private var recentCardIds: [Int64] = []
    private let recentWindow = 20

    init(deckName: String, languageCode: String = "es",
         database: AppDatabase = .shared, settings: UserSettings = .shared) {
        self.deckName = deckName
        self.database = database
        self.settings = settings

        let locale = Locale(identifier: "\(languageCode)-\(languageCode.uppercased())")
        self.speechService = SpeechService(locale: locale)

        speechCancellable = speechService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        pickNextCard()
    }

    /// Pick the next card using weighted random selection.
    /// Weight favors: low ease factor, low repetitions, high section (newer material),
    /// and recently failed cards. Cards shown in the last 20 are excluded.
    func pickNextCard() {
        let maxSection = settings.maxSection
        let excluded = recentCardIds

        do {
            let candidates = try database.dbQueue.read { db -> [(Card, Double)] in
                var query = Card.filter(Column("section") <= maxSection)

                // Exclude recently shown cards
                if !excluded.isEmpty {
                    query = query.filter(!excluded.contains(Column("id")))
                }

                let cards = try query.fetchAll(db)

                // Find cards that were failed recently (quality < 3 in last 50 reviews)
                let recentFailIds: Set<Int64> = try {
                    let rows = try Row.fetchAll(db, sql: """
                        SELECT DISTINCT cardId FROM reviewSession
                        WHERE quality < 3
                        ORDER BY reviewedAt DESC
                        LIMIT 50
                    """)
                    return Set(rows.map { $0["cardId"] as Int64 })
                }()

                // Calculate weight for each card — higher weight = more likely to be picked
                return cards.map { card in
                    // Base weight: inverse of ease * reps — struggle cards get high weight
                    let easeWeight = 1.0 / (card.easeFactor * Double(card.repetitions + 1))

                    // Section proximity: cards closer to maxSection (newer) get a boost
                    let sectionBoost = 1.0 + Double(card.section) / Double(maxSection)

                    // Recently failed cards get the strongest boost (10x)
                    // New cards get a moderate boost (2x)
                    let statusBoost: Double
                    if let id = card.id, recentFailIds.contains(id) {
                        statusBoost = 10.0
                    } else if card.repetitions == 0 {
                        statusBoost = 2.0
                    } else {
                        statusBoost = 1.0
                    }

                    let weight = easeWeight * sectionBoost * statusBoost
                    return (card, weight)
                }
            }

            guard !candidates.isEmpty else {
                currentCard = nil
                return
            }

            // Weighted random selection
            let totalWeight = candidates.reduce(0.0) { $0 + $1.1 }
            var roll = Double.random(in: 0..<totalWeight)

            var selected = candidates[0].0
            for (card, weight) in candidates {
                roll -= weight
                if roll <= 0 {
                    selected = card
                    break
                }
            }

            // Track in recent window
            if let id = selected.id {
                recentCardIds.append(id)
                if recentCardIds.count > recentWindow {
                    recentCardIds.removeFirst()
                }
            }

            currentCard = selected
            isShowingAnswer = false
            speechMatched = nil
            speechService.stopListening()
            speechService.transcript = ""
            speechService.clearLastRecording()

            if let id = selected.id {
                loadRecentResults(for: id)
            }

        } catch {
            currentCard = nil
        }
    }

    /// Fetch last 5 review qualities for the given card and convert to a
    /// padded [Bool?] (most recent first; nil = no review). Mirrors the
    /// dot rendering in PhraseListView so the two stay visually consistent.
    private func loadRecentResults(for cardId: Int64) {
        do {
            recentResults = try database.dbQueue.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT quality FROM reviewSession
                    WHERE cardId = ?
                    ORDER BY reviewedAt DESC
                    LIMIT 5
                """, arguments: [cardId])
                var dots: [Bool?] = rows.map { ($0["quality"] as Int) >= 3 }
                while dots.count < 5 { dots.append(nil) }
                return dots
            }
        } catch {
            recentResults = Array(repeating: nil, count: 5)
        }
    }

    func showAnswer() {
        isShowingAnswer = true
    }

    /// Advance to the next card without recording a review.
    func skip() {
        pickNextCard()
    }

    /// Push-to-talk: invoked when the mic button is pressed down. Clears any
    /// previous transcript/match state, then starts listening. The answer is
    /// not evaluated until `endPushToTalk()` is called on release.
    func startPushToTalk() async {
        speechMatched = nil
        speechService.transcript = ""
        if let card = currentCard {
            let words = card.front.components(separatedBy: " ").filter { !$0.isEmpty }
            speechService.contextualStrings = [card.front] + words
        }
        let permitted = await speechService.requestPermissions()
        guard permitted else { return }
        speechService.startListening()
    }

    /// Push-to-talk: invoked when the mic button is released. Stops listening
    /// and evaluates whatever the recognizer produced.
    func endPushToTalk() {
        guard speechService.isListening else { return }
        let finalTranscript = speechService.transcript
        speechService.stopListening()
        checkAnswer(transcript: finalTranscript, isFinal: true)
    }

    private func checkAnswer(transcript: String, isFinal: Bool) {
        guard let card = currentCard, speechMatched != true else { return }

        let spoken = normalize(transcript)
        let expected = normalize(card.front)

        let matched = spoken == expected
        print("[SpeakOffline] Match check: spoken=\"\(spoken)\" expected=\"\(expected)\" matched=\(matched) final=\(isFinal)")

        if matched {
            speechService.stopListening()
            if isShowingAnswer {
                // They matched after peeking — don't count as correct
                speechMatched = false
            } else {
                speechMatched = true
                withAnimation(.easeIn(duration: 0.3)) {
                    isShowingAnswer = true
                }
            }
        } else if isFinal {
            speechMatched = false
        }
    }

    func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: CharacterSet.letters.inverted)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "  ", with: " ")
    }

    /// Returns an AttributedString of the transcript with words matching the expected answer in green
    func coloredTranscript() -> AttributedString {
        guard let card = currentCard else {
            return AttributedString(speechService.transcript)
        }

        let expectedWords = normalize(card.front)
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
        let expectedSet = Set(expectedWords)

        let rawWords = speechService.transcript
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }

        var result = AttributedString()
        for (i, word) in rawWords.enumerated() {
            let normalizedWord = normalize(word)
            var attrWord = AttributedString(word)
            if expectedSet.contains(normalizedWord) {
                attrWord.foregroundColor = .green
            } else if speechMatched == false {
                attrWord.foregroundColor = .yellow
            }
            if i > 0 {
                result.append(AttributedString(" "))
            }
            result.append(attrWord)
        }
        return result
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
            // Silently fail — review is lost but app continues
        }

        cardsReviewed += 1
        pickNextCard()
    }
}
