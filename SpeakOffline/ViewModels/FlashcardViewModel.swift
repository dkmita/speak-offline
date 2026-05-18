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
    /// True while the newest dot in `recentResults` is being celebrated
    /// with a scale-up animation. The view uses this to draw attention
    /// to the just-added result.
    @Published var justAddedDotPending: Bool = false
    /// True between rate() being called and pickNextCard completing —
    /// blocks the rating buttons from double-firing during the delay.
    @Published var isAdvancing: Bool = false
    /// Set when checkAnswer auto-adds a green dot on a speech match, so
    /// the subsequent rate() call knows the dot is already present and
    /// the animation has already played.
    private var resultRecordedFromSpeech: Bool = false
    /// On-device LLM explanation of why the speech-to-text attempt was
    /// wrong. Populated by `requestExplanation()`; cleared on card change.
    @Published var explanation: String? = nil
    @Published var isLoadingExplanation: Bool = false

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

    /// Pick the next card using weighted random selection. Weight combines:
    /// - Per-card ease/reps (struggle cards bubble up)
    /// - Per-card miss rate (cards you've gotten wrong more often outweigh
    ///   ones you've gotten right)
    /// - Last-review-wrong flag (just-missed cards get a strong push)
    /// - Per-section accuracy (Duolingo sections you're already good at
    ///   contribute less to the pool)
    /// Cards shown in the last 20 are excluded.
    func pickNextCard() {
        let maxSection = settings.maxSection
        let excluded = recentCardIds

        do {
            let candidates = try database.dbQueue.read { db -> [(Card, Double)] in
                // Per-Duolingo-section accuracy (card.unit = section index 1-8).
                // Needs ≥10 reviews in that section to count; otherwise neutral.
                let accuracyRows = try Row.fetchAll(db, sql: """
                    SELECT card.unit AS sec,
                           COUNT(*) AS total,
                           SUM(CASE WHEN rs.quality >= 3 THEN 1 ELSE 0 END) AS correct
                    FROM reviewSession rs
                    JOIN card ON rs.cardId = card.id
                    GROUP BY card.unit
                """)
                var sectionAccuracy: [Int: Double] = [:]
                for row in accuracyRows {
                    let sec: Int = row["sec"]
                    let total: Int = row["total"]
                    let correct: Int = row["correct"]
                    if total >= 10 {
                        sectionAccuracy[sec] = Double(correct) / Double(total)
                    }
                }

                // Per-card stats: total reviews, miss count, last-review-was-wrong.
                let statsRows = try Row.fetchAll(db, sql: """
                    SELECT
                        rs.cardId AS cardId,
                        COUNT(*) AS total,
                        SUM(CASE WHEN rs.quality < 3 THEN 1 ELSE 0 END) AS misses,
                        (SELECT quality FROM reviewSession rs2
                         WHERE rs2.cardId = rs.cardId
                         ORDER BY reviewedAt DESC LIMIT 1) AS lastQuality
                    FROM reviewSession rs
                    GROUP BY rs.cardId
                """)
                struct CardStats { let total: Int; let misses: Int; let lastWrong: Bool }
                var cardStats: [Int64: CardStats] = [:]
                for row in statsRows {
                    let id: Int64 = row["cardId"]
                    let total: Int = row["total"]
                    let misses: Int = row["misses"]
                    let lastQuality: Int = row["lastQuality"]
                    cardStats[id] = CardStats(total: total, misses: misses, lastWrong: lastQuality < 3)
                }

                var query = Card.filter(Column("section") <= maxSection)
                if !excluded.isEmpty {
                    query = query.filter(!excluded.contains(Column("id")))
                }
                let cards = try query.fetchAll(db)

                return cards.map { card -> (Card, Double) in
                    // Base: inverse of ease × reps. Struggle cards float up.
                    let easeWeight = 1.0 / (card.easeFactor * Double(card.repetitions + 1))

                    let stats = card.id.flatMap { cardStats[$0] }
                    let total = stats?.total ?? 0
                    let misses = stats?.misses ?? 0
                    let lastWrong = stats?.lastWrong ?? false

                    // Miss-rate boost: 1.0 (never missed) → up to 3.0 (always missed).
                    // Needs ≥3 reviews to engage; otherwise neutral.
                    let missBoost: Double = total >= 3
                        ? 1.0 + Double(misses) / Double(total) * 2.0
                        : 1.0

                    // Status boost: strong push for last-review-wrong; moderate
                    // for never-seen cards.
                    let statusBoost: Double
                    if lastWrong {
                        statusBoost = 10.0
                    } else if total == 0 {
                        statusBoost = 2.0
                    } else {
                        statusBoost = 1.0
                    }

                    // Per-section accuracy: high-accuracy sections get less weight.
                    // 100% accuracy → 0.3×; 50% → 1.0×; 0% → 1.7×.
                    // No data → neutral 1.0×.
                    let acc = sectionAccuracy[card.unit] ?? 0.5
                    let sectionAccuracyBoost = 0.3 + (1.0 - acc) * 1.4

                    let weight = easeWeight * missBoost * statusBoost * sectionAccuracyBoost
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
            justAddedDotPending = false
            isAdvancing = false
            resultRecordedFromSpeech = false
            explanation = nil
            isLoadingExplanation = false
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

    /// Ask the on-device LLM for a one- or two-sentence insight into why
    /// the user's speech-to-text attempt was wrong. Populates
    /// `explanation` on success; sets a placeholder on failure.
    func requestExplanation() {
        guard let card = currentCard else { return }
        let attempt = speechService.transcript
        guard !attempt.isEmpty else { return }
        guard !isLoadingExplanation, explanation == nil else { return }

        isLoadingExplanation = true
        let question = card.back
        let expected = card.front

        Task { @MainActor in
            let result: String?
            if #available(iOS 26, *) {
                result = await ExplanationService.shared.explainMistake(
                    question: question, expected: expected, attempt: attempt
                )
            } else {
                result = nil
            }
            isLoadingExplanation = false
            explanation = result ?? "Couldn't generate an explanation — on-device model unavailable."
        }
    }

    /// Jump straight to a specific card by id (used when the user taps a row
    /// in the analytics sheet). Resets review/answer state and refreshes the
    /// recent-results dots so it looks just like a freshly-picked card.
    /// The next rate()/skip() call returns to normal random picking.
    func loadCard(id: Int64) {
        do {
            let card = try database.dbQueue.read { db in
                try Card.fetchOne(db, key: id)
            }
            guard let card else { return }
            currentCard = card
            isShowingAnswer = false
            speechMatched = nil
            justAddedDotPending = false
            isAdvancing = false
            resultRecordedFromSpeech = false
            explanation = nil
            isLoadingExplanation = false
            speechService.stopListening()
            speechService.transcript = ""
            speechService.clearLastRecording()
            loadRecentResults(for: id)

            // Track in the recent-window buffer so the picker doesn't
            // immediately re-roll the same card on the next advance.
            recentCardIds.append(id)
            if recentCardIds.count > recentWindow {
                recentCardIds.removeFirst()
            }
        } catch {
            // Silently fail; user can pick another card.
        }
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
                // Optimistically add the green dot to history and pulse it
                // so the user sees the result land before they tap Next.
                // Flag rate() so it skips the re-add and the extra delay —
                // the user has already seen the animation by the time they
                // press the button.
                recentResults = [true] + Array(recentResults.dropLast())
                resultRecordedFromSpeech = true
                justAddedDotPending = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    justAddedDotPending = false
                }
            }
        } else if isFinal {
            speechMatched = false
        }
    }

    /// Lowercase, diacritic-fold, then keep only letter sequences joined with
    /// single spaces. Punctuation (?, ¿, !, ¡, periods, commas, em-dashes…)
    /// is dropped entirely, so "¿Cómo estás?" and "cómo estás" both
    /// normalize to "como estas". Digit runs are spelled out in Spanish first
    /// (e.g. "70" → "setenta") so the recognizer's numeric transcription still
    /// matches the card's word form.
    func normalize(_ text: String) -> String {
        Self.expandDigits(Self.stripClockMinutes(text.lowercased()))
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// The iOS speech recognizer sometimes transcribes spoken numbers as
    /// digits ("setenta" → "70"). Spell them out in Spanish so matching works
    /// regardless of which form the recognizer chose.
    private static let spanishNumberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        f.locale = Locale(identifier: "es")
        return f
    }()

    /// Speech recognition often turns a spoken hour like "a las siete" into
    /// "a las 7:00". Drop the trailing ":00" so the digit-expansion step sees
    /// just the hour. Non-zero minutes ("7:30") are left alone — Spanish has
    /// several idiomatic forms ("siete y media", "siete y treinta", "siete y
    /// cuarto", "ocho menos cuarto") and no single substitution covers them.
    private static let clockMinuteRegex = try! NSRegularExpression(
        pattern: #"(\d+):00(?!\d)"#
    )
    private static func stripClockMinutes(_ s: String) -> String {
        let range = NSRange(s.startIndex..., in: s)
        return clockMinuteRegex.stringByReplacingMatches(
            in: s, range: range, withTemplate: "$1"
        )
    }

    private static func expandDigits(_ s: String) -> String {
        var out = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i].isNumber {
                var j = i
                while j < s.endIndex, s[j].isNumber { j = s.index(after: j) }
                let digits = String(s[i..<j])
                if let n = Int(digits),
                   let spelled = spanishNumberFormatter.string(from: NSNumber(value: n)) {
                    out += spelled
                } else {
                    out += digits
                }
                i = j
            } else {
                out.append(s[i])
                i = s.index(after: i)
            }
        }
        return out
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
        guard var card = currentCard, !isAdvancing else { return }
        isAdvancing = true

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

        // Speech-match path already added + animated the dot when matched.
        // Don't re-add or re-animate — just advance.
        if resultRecordedFromSpeech {
            resultRecordedFromSpeech = false
            pickNextCard()
            return
        }

        // Manual rating: optimistically prepend the new result so the user
        // sees it land before the next card replaces the view.
        let wasCorrect = quality >= 3
        recentResults = [wasCorrect] + Array(recentResults.dropLast())

        if wasCorrect {
            // Pulse the new dot, then advance after ~1s.
            justAddedDotPending = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 800_000_000)
                justAddedDotPending = false
                try? await Task.sleep(nanoseconds: 200_000_000)
                pickNextCard()
            }
        } else {
            // Wrong answer: record the red dot and move on without ceremony.
            pickNextCard()
        }
    }
}
