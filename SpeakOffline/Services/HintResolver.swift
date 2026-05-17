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
    /// Spanish answer.
    ///
    /// Probes three dictionary keys and merges the results: the tapped word
    /// alone, the tapped word + one neighbor to the left, and the tapped word
    /// + one neighbor to the right. Two-word phrases like "good morning" or
    /// "a lot of" are common in the dictionary, and surfacing them lets the
    /// hint suggest "buenos días" when the user taps either "good" or
    /// "morning" individually.
    ///
    /// Answer-matching disambiguation is applied per lookup, so each set
    /// contributes either its answer-matching forms or its top few candidates.
    /// Returns "?" only if no lookup hits and the proportional fallback also
    /// fails.
    func hint(forIndex index: Int, sourceWords: [String], answer: String) -> String {
        guard index >= 0, index < sourceWords.count else { return "?" }

        let answerTokens = Set(Self.tokenize(answer))
        let keys = Self.lookupKeys(forIndex: index, sourceWords: sourceWords)
        var combined: [String] = []
        var seen = Set<String>()

        for (i, key) in keys.enumerated() {
            // Index 0 is the single-word key; everything after is a phrase.
            let isSingleWord = (i == 0)
            let candidates = vocabulary.spanish(for: key)
            guard !candidates.isEmpty else { continue }

            let matching = candidates.filter { candidate in
                let parts = Self.tokenize(candidate)
                return !parts.isEmpty && parts.allSatisfy { answerTokens.contains($0) }
            }

            // Single-word lookups fall back to top candidates when nothing in
            // this card's answer matches — still informative for the learner.
            // Phrase lookups only contribute when they match the answer, since
            // an unrelated phrase that happens to share a word would be noise.
            let picks: [String]
            if !matching.isEmpty {
                picks = matching
            } else if isSingleWord {
                picks = Array(candidates.prefix(3))
            } else {
                picks = []
            }

            for p in picks where seen.insert(p).inserted {
                combined.append(p)
            }
        }

        if !combined.isEmpty {
            return combined.joined(separator: " / ")
        }
        return Self.proportionalHint(index: index, sourceWords: sourceWords, answer: answer) ?? "?"
    }

    /// The keys to probe in the dictionary for a tap at `index`:
    /// the word alone, the left two-word phrase, and the right two-word phrase.
    /// Tokens are normalized (lowercased, punctuation stripped) before
    /// concatenation, so "Good," + "morning?" becomes "good morning".
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
