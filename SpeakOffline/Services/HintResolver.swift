import Foundation

/// Structured outcome of a single tap hint lookup.
///
/// Carries the three independent lookups (single word, left phrase, right
/// phrase) separately so the view can render each with distinct styling.
/// The `fallback` field is only populated when every dictionary path is
/// empty — it preserves the legacy proportional-position guess for words the
/// dictionary doesn't know.
struct HintResult: Equatable {
    /// Translations for the tapped word alone. May be empty.
    let single: [String]

    /// Phrase translation when `[tapped-1] [tapped]` matches the card's answer.
    let leftPair: [String]

    /// Phrase translation when `[tapped] [tapped+1]` matches the card's answer.
    let rightPair: [String]

    /// Proportional-position guess. Set only when every other field is empty.
    let fallback: String?

    var isEmpty: Bool {
        single.isEmpty && leftPair.isEmpty && rightPair.isEmpty && fallback == nil
    }

    static let empty = HintResult(single: [], leftPair: [], rightPair: [], fallback: nil)
}

/// Picks Spanish hints for an English word on a flashcard.
///
/// Probes three dictionary entries per tap — the word alone, the two-word
/// phrase ending at the tap, and the two-word phrase starting at the tap —
/// so the user sees both single-word and adjacent-phrase translations when
/// they apply.
///
/// Disambiguation: when the dictionary returns multiple candidates for a
/// lookup, we prefer those whose tokens appear in this card's answer (e.g.
/// `"red"` → `[roja, rojas, rojo]` collapses to `roja` when the answer is
/// "La bicicleta roja"). For single-word lookups with no answer match we
/// still return the top few candidates — informative even without context.
/// Phrase lookups only contribute when they match the answer; an unrelated
/// phrase that happens to share a word would be noise.
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

        // Phrase lookups. Only return candidates that match the answer —
        // an unrelated phrase sharing a word is noise.
        let leftPair = pickPhrase(
            leftIndex: index - 1,
            rightIndex: index,
            sourceWords: sourceWords,
            answerTokens: answerTokens
        )
        let rightPair = pickPhrase(
            leftIndex: index,
            rightIndex: index + 1,
            sourceWords: sourceWords,
            answerTokens: answerTokens
        )

        let fallback: String?
        if single.isEmpty && leftPair.isEmpty && rightPair.isEmpty {
            fallback = Self.proportionalHint(index: index, sourceWords: sourceWords, answer: answer)
        } else {
            fallback = nil
        }
        return HintResult(single: single, leftPair: leftPair, rightPair: rightPair, fallback: fallback)
    }

    private func pickSingle(from candidates: [String], answerTokens: Set<String>) -> [String] {
        guard !candidates.isEmpty else { return [] }
        let matching = candidates.filter { matches(candidate: $0, answerTokens: answerTokens) }
        if !matching.isEmpty { return matching }
        return Array(candidates.prefix(3))
    }

    private func pickPhrase(
        leftIndex: Int,
        rightIndex: Int,
        sourceWords: [String],
        answerTokens: Set<String>
    ) -> [String] {
        guard sourceWords.indices.contains(leftIndex),
              sourceWords.indices.contains(rightIndex),
              let left = Self.tokenize(sourceWords[leftIndex]).first,
              let right = Self.tokenize(sourceWords[rightIndex]).first
        else { return [] }
        let key = "\(left) \(right)"
        let candidates = vocabulary.spanish(for: key)
        return candidates.filter { matches(candidate: $0, answerTokens: answerTokens) }
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

    /// Legacy proportional position mapping. Splits both sides on whitespace
    /// and maps source index → answer index by ratio.
    static func proportionalHint(index: Int, sourceWords: [String], answer: String) -> String? {
        let answerWords = answer.components(separatedBy: " ").filter { !$0.isEmpty }
        let srcCount = sourceWords.count
        let dstCount = answerWords.count
        guard dstCount > 0, srcCount > 0 else { return nil }

        let ratio = Double(dstCount) / Double(srcCount)
        let startIdx = Int((Double(index) * ratio).rounded(.down))
        let endIdx = Int((Double(index + 1) * ratio).rounded(.up)) - 1
        let clamped = max(0, startIdx)...min(dstCount - 1, max(startIdx, endIdx))
        return answerWords[clamped].joined(separator: " ")
    }

    /// The keys to probe in the dictionary for a tap at `index`:
    /// the word alone, the left two-word phrase, and the right two-word phrase.
    /// Exposed for tests; production code uses `resolve(...)` directly.
    static func lookupKeys(forIndex index: Int, sourceWords: [String]) -> [String] {
        guard sourceWords.indices.contains(index),
              let current = tokenize(sourceWords[index]).first
        else { return [] }

        var keys: [String] = [current]
        if sourceWords.indices.contains(index - 1),
           let left = tokenize(sourceWords[index - 1]).first {
            keys.append("\(left) \(current)")
        }
        if sourceWords.indices.contains(index + 1),
           let right = tokenize(sourceWords[index + 1]).first {
            keys.append("\(current) \(right)")
        }
        return keys
    }
}
