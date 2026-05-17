import Foundation

/// A multi-word phrase that the dictionary matched against this card's answer.
struct PhraseMatch: Equatable, Hashable {
    /// Spanish translations of the phrase.
    let translations: [String]
    /// Source-word indices that the phrase spans, inclusive.
    let span: ClosedRange<Int>
}

/// Structured outcome of a single tap hint lookup.
struct HintResult: Equatable {
    /// Translations for the tapped word alone. May be empty.
    let single: [String]

    /// Matched multi-word phrases that involve the tapped word. Ordered by
    /// the resolver's probe order: 2-word phrases first (left-pair then
    /// right-pair), then 3-word phrases (left-triple, middle-triple,
    /// right-triple).
    let phrases: [PhraseMatch]

    var isEmpty: Bool {
        single.isEmpty && phrases.isEmpty
    }

    static let empty = HintResult(single: [], phrases: [])
}

/// Picks Spanish hints for an English word on a flashcard.
///
/// Probes the dictionary with the tapped word alone plus every adjacent
/// 2- and 3-word window that includes the tap. Contractions are expanded
/// before lookup ("don't" → "do not"), so a tap on a contraction looks up
/// the full form instead of fragments.
struct HintResolver {
    let vocabulary: VocabularyService

    init(vocabulary: VocabularyService = .shared) {
        self.vocabulary = vocabulary
    }

    /// Returns the structured hint result for the tap at `index`.
    func resolve(forIndex index: Int, sourceWords: [String], answer: String) -> HintResult {
        guard sourceWords.indices.contains(index) else { return .empty }
        let answerTokens = Set(Self.tokenize(answer))

        // Single-word lookup. For contractions this becomes a phrase key
        // (e.g., "don't" → "do not"); for everything else it's one token.
        // If the full phrase form isn't in the dictionary, fall back to the
        // first expanded token alone — usable for taps on contractions like
        // "can't" where "can not" isn't a dict entry but "can" is.
        let singleTokens = Self.lookupTokens(forWord: sourceWords[index])
        let singleKey = singleTokens.joined(separator: " ")
        var singleCandidates = singleKey.isEmpty ? [] : vocabulary.spanish(for: singleKey)
        if singleCandidates.isEmpty, singleTokens.count > 1 {
            singleCandidates = vocabulary.spanish(for: singleTokens[0])
        }
        let single = pickSingle(from: singleCandidates, answerTokens: answerTokens)

        // Adjacent-window phrase lookups. Spans are inclusive on both ends
        // and refer to source-word indices, not token indices — a span of
        // two source words can become a 3-token key if one is a contraction.
        let probeSpans: [ClosedRange<Int>] = [
            (index - 1)...index,           // left pair
            index...(index + 1),           // right pair
            (index - 2)...index,           // left triple
            (index - 1)...(index + 1),     // mid triple
            index...(index + 2)            // right triple
        ]
        var phrases: [PhraseMatch] = []
        for span in probeSpans {
            if let match = phraseMatch(forSpan: span, sourceWords: sourceWords, answerTokens: answerTokens) {
                phrases.append(match)
            }
        }

        return HintResult(single: single, phrases: phrases)
    }

    private func pickSingle(from candidates: [String], answerTokens: Set<String>) -> [String] {
        guard !candidates.isEmpty else { return [] }
        let matching = candidates.filter { matches(candidate: $0, answerTokens: answerTokens) }
        if !matching.isEmpty { return matching }
        return Array(candidates.prefix(3))
    }

    /// Look up the phrase covering `span`, returning a `PhraseMatch` only if
    /// at least one translation's tokens all appear in the answer.
    private func phraseMatch(
        forSpan span: ClosedRange<Int>,
        sourceWords: [String],
        answerTokens: Set<String>
    ) -> PhraseMatch? {
        guard span.lowerBound >= 0,
              span.upperBound < sourceWords.count
        else { return nil }
        let tokens = span.flatMap { Self.lookupTokens(forWord: sourceWords[$0]) }
        guard !tokens.isEmpty else { return nil }
        let key = tokens.joined(separator: " ")
        let matching = vocabulary.spanish(for: key).filter { matches(candidate: $0, answerTokens: answerTokens) }
        guard !matching.isEmpty else { return nil }
        return PhraseMatch(translations: matching, span: span)
    }

    private func matches(candidate: String, answerTokens: Set<String>) -> Bool {
        let parts = Self.tokenize(candidate)
        return !parts.isEmpty && parts.allSatisfy { answerTokens.contains($0) }
    }

    // MARK: - Static helpers

    /// Common English contractions and their expanded forms. Applied when
    /// deriving lookup keys so the dictionary sees the full form
    /// ("don't" → "do not") instead of the tokenize-split artifacts
    /// ("don" + "t"). Possessives like "mother's" / "Monet's" / "o'clock"
    /// are deliberately NOT here — they're not contractions and have their
    /// own dictionary entries (or fall back to the noun stem).
    static let contractions: [String: String] = [
        // be / not / will / would
        "i'm": "i am",
        "you're": "you are",
        "he's": "he is",
        "she's": "she is",
        "it's": "it is",
        "we're": "we are",
        "they're": "they are",
        "i'll": "i will",
        "you'll": "you will",
        "he'll": "he will",
        "she'll": "she will",
        "we'll": "we will",
        "they'll": "they will",
        "i'd": "i would",
        "you'd": "you would",
        "he'd": "he would",
        "she'd": "she would",
        "we'd": "we would",
        "they'd": "they would",
        "i've": "i have",
        "you've": "you have",
        "we've": "we have",
        "they've": "they have",
        // negations
        "don't": "do not",
        "doesn't": "does not",
        "didn't": "did not",
        "isn't": "is not",
        "aren't": "are not",
        "wasn't": "was not",
        "weren't": "were not",
        "hasn't": "has not",
        "haven't": "have not",
        "hadn't": "had not",
        "won't": "will not",
        "wouldn't": "would not",
        "can't": "can not",
        "couldn't": "could not",
        "shouldn't": "should not",
        "mustn't": "must not",
        // 's / 're / 've / 'll on common subjects
        "that's": "that is",
        "there's": "there is",
        "here's": "here is",
        "what's": "what is",
        "where's": "where is",
        "who's": "who is",
        "how's": "how is",
        "let's": "let us",
        "y'all": "you all"
    ]

    /// Returns the dictionary-lookup tokens for a single source word.
    ///
    /// Known contractions expand to their full form ("don't" → ["do", "not"]).
    /// Possessives and other apostrophe words drop to their alphanumeric core
    /// ("mother's" → ["mother"]). Plain words return a single-element array.
    /// Empty input or pure punctuation returns an empty array.
    static func lookupTokens(forWord word: String) -> [String] {
        let lower = word.lowercased()
        let stripped = lower.trimmingCharacters(
            in: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted
        )
        if let expanded = contractions[stripped] {
            return expanded.components(separatedBy: " ").filter { !$0.isEmpty }
        }
        return tokenize(word).first.map { [$0] } ?? []
    }

    /// Split on anything that isn't a Unicode letter or digit, lowercased.
    /// Used for matching tokens in answers and candidate translations; not
    /// contraction-aware — call `lookupTokens(forWord:)` for source words.
    static func tokenize(_ s: String) -> [String] {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// The keys probed in the dictionary for a tap at `index`: the word
    /// alone, then 2- and 3-word adjacent windows. Contraction expansion
    /// happens at the per-word level, so a 2-source-word window with one
    /// contraction produces a 3-token key. Exposed for tests.
    static func lookupKeys(forIndex index: Int, sourceWords: [String]) -> [String] {
        guard sourceWords.indices.contains(index),
              !lookupTokens(forWord: sourceWords[index]).isEmpty
        else { return [] }

        let probes: [(Int, Int)] = [
            (index, index),                  // single
            (index - 1, index),              // left pair
            (index, index + 1),              // right pair
            (index - 2, index),              // left triple
            (index - 1, index + 1),          // mid triple
            (index, index + 2)               // right triple
        ]
        var keys: [String] = []
        for (lo, hi) in probes {
            guard lo >= 0, hi < sourceWords.count else { continue }
            let tokens = (lo...hi).flatMap { lookupTokens(forWord: sourceWords[$0]) }
            guard !tokens.isEmpty else { continue }
            keys.append(tokens.joined(separator: " "))
        }
        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }
}
