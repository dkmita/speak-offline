import Foundation

/// A multi-word phrase that the dictionary matched against this card's answer.
struct PhraseMatch: Equatable, Hashable {
    /// Spanish translations of the phrase.
    let translations: [String]
    /// Source-word indices that the phrase spans, inclusive.
    let span: ClosedRange<Int>
}

/// Structured outcome of a single tap hint lookup.
///
/// Carries the single-word translations and any matched multi-word phrases
/// separately so the view can render each with distinct styling.
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
/// 2- and 3-word window that includes the tap:
///
/// ```
///   single           [i]
///   left pair    [i-1][i]
///   right pair       [i][i+1]
///   left triple  [i-2][i-1][i]
///   mid  triple  [i-1][i][i+1]
///   right triple     [i][i+1][i+2]
/// ```
///
/// Single-word lookups can fall back to top candidates when nothing in the
/// answer matches — informative even without context. Phrase lookups only
/// contribute when they match the answer; an unrelated phrase that happens to
/// share a word would be noise.
struct HintResolver {
    let vocabulary: VocabularyService

    init(vocabulary: VocabularyService = .shared) {
        self.vocabulary = vocabulary
    }

    /// Returns the structured hint result for the tap at `index`.
    func resolve(forIndex index: Int, sourceWords: [String], answer: String) -> HintResult {
        guard sourceWords.indices.contains(index) else { return .empty }
        let answerTokens = Set(Self.tokenize(answer))

        // Single-word lookup.
        let singleKey = Self.tokenize(sourceWords[index]).first ?? ""
        let singleCandidates = singleKey.isEmpty ? [] : vocabulary.spanish(for: singleKey)
        let single = pickSingle(from: singleCandidates, answerTokens: answerTokens)

        // Phrase lookups. Spans are inclusive on both ends.
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
        let tokens = span.compactMap { Self.tokenize(sourceWords[$0]).first }
        guard tokens.count == span.count else { return nil }
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

    /// Split on anything that isn't a Unicode letter or digit, lowercased.
    static func tokenize(_ s: String) -> [String] {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// The keys probed in the dictionary for a tap at `index`: the word
    /// alone, then 2- and 3-word adjacent windows. Exposed for tests.
    static func lookupKeys(forIndex index: Int, sourceWords: [String]) -> [String] {
        guard sourceWords.indices.contains(index),
              let current = tokenize(sourceWords[index]).first
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
            let tokens = (lo...hi).compactMap { tokenize(sourceWords[$0]).first }
            guard tokens.count == hi - lo + 1 else { continue }
            keys.append(tokens.joined(separator: " "))
        }
        // Deduplicate while preserving order — single-word probe overlaps
        // with degenerate triple at edges in some configurations.
        _ = current
        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }
}
