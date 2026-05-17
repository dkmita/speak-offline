import Foundation

/// Picks a Spanish hint for an English word on a flashcard.
///
/// Strategy, in order:
///   1. Look up the word in the bundled vocab dictionary.
///   2. Prefer dictionary translations whose tokens actually appear in this
///      card's Spanish answer — disambiguates conjugations and gendered forms
///      (e.g. "have" returns many tener-forms; we keep the one in the answer).
///   3. If the dictionary has translations but none match this answer, fall
///      back to showing the top few (a likely-correct guess across cards).
///   4. If the dictionary doesn't know the word, fall back to proportional
///      position mapping against the answer — the legacy behavior, useful for
///      proper nouns and words not in the dictionary.
struct HintResolver {
    let vocabulary: VocabularyService

    init(vocabulary: VocabularyService = .shared) {
        self.vocabulary = vocabulary
    }

    /// Resolve a hint for the word at `index` in `sourceWords`, given the full
    /// Spanish answer. Returns "?" only if the answer has no usable tokens.
    func hint(forIndex index: Int, sourceWords: [String], answer: String) -> String {
        guard index >= 0, index < sourceWords.count else { return "?" }
        let raw = sourceWords[index]
        let key = Self.tokenize(raw).first ?? raw.lowercased()

        let candidates = vocabulary.spanish(for: key)
        if candidates.isEmpty {
            return Self.proportionalHint(index: index, sourceWords: sourceWords, answer: answer) ?? "?"
        }

        let answerTokens = Set(Self.tokenize(answer))
        let matching = candidates.filter { candidate in
            let parts = Self.tokenize(candidate)
            return !parts.isEmpty && parts.allSatisfy { answerTokens.contains($0) }
        }

        if !matching.isEmpty {
            return matching.joined(separator: " / ")
        }
        // The dictionary knows the word but none of its forms appear in this
        // particular answer; the user still gets a usable cluster of options.
        return candidates.prefix(3).joined(separator: " / ")
    }

    /// Split on anything that isn't a Unicode letter or digit, lowercased.
    /// Used both to derive the lookup key from the tapped word and to match
    /// dictionary candidates against the answer.
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
}
