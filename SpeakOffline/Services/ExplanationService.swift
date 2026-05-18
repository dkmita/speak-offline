import Foundation
import FoundationModels

/// Wraps Apple's on-device Foundation Models framework to explain why a
/// learner's Spanish attempt missed the mark. Runs entirely on-device on
/// Apple-Intelligence-eligible devices (iPhone 15 Pro / 16 series and up).
/// No network traffic — works in airplane mode.
@available(iOS 26, *)
final class ExplanationService {
    static let shared = ExplanationService()

    private init() {}

    /// True if the on-device model is downloaded and ready. False if the
    /// device isn't eligible, the user has Apple Intelligence disabled, or
    /// the model hasn't finished downloading yet.
    var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    /// Ask the on-device model what's wrong with `attempt` given the
    /// English prompt and the correct Spanish translation. Returns nil
    /// when the model is unavailable or the request fails.
    func explainMistake(question: String, expected: String, attempt: String) async -> String? {
        guard isAvailable else { return nil }

        // Pre-compute a word-level diff so the small on-device model doesn't
        // have to "find" the differences itself — it just has to name and
        // explain them. Big quality lift on a ~3B model.
        let diff = Self.wordDiff(expected: expected, attempt: attempt)

        let session = LanguageModelSession(instructions: """
            You are a Spanish tutor. The learner translated an English sentence \
            into Spanish (often by speaking aloud). You will receive the \
            correct Spanish, the learner's attempt, and a precomputed word-by-\
            word diff. Your job is to write ONE short sentence in plain English \
            explaining the real grammatical mistake and how to fix it.

            Rules:
            - Do not mention or acknowledge anything the learner got right.
            - Focus on the real error: gender agreement, verb conjugation, \
              tense, person, word choice, or missing/extra words.
            - Ignore speech-to-text noise: missing accents, dropped tiny \
              function words (a, de, la when obviously implied), slightly \
              misheard short words. These are transcription artifacts, not \
              mistakes.
            - Be concrete: name the wrong form and the correct form.
            - One sentence, two at most. Plain English, no preamble.

            Examples:

            Example 1
            English: "I am tall." (speaker is female)
            Correct Spanish: "Soy alta."
            Learner said: "Soy alto."
            Diff: missing 'alta'; extra 'alto'
            Explanation: You used the masculine 'alto' — to agree with a \
            female speaker, use the feminine form 'alta'.

            Example 2
            English: "We eat bread."
            Correct Spanish: "Comemos pan."
            Learner said: "Comimos pan."
            Diff: missing 'comemos'; extra 'comimos'
            Explanation: 'Comimos' is the preterite (we ate); for the present \
            tense (we eat) use 'comemos'.

            Example 3
            English: "The teacher is nice."
            Correct Spanish: "La maestra es amable."
            Learner said: "El maestro es amable."
            Diff: missing 'la', 'maestra'; extra 'el', 'maestro'
            Explanation: The expected sentence uses the feminine 'la maestra'; \
            you used the masculine 'el maestro'.

            Example 4
            English: "I want to drink water."
            Correct Spanish: "Quiero beber agua."
            Learner said: "Quiero bebo agua."
            Diff: missing 'beber'; extra 'bebo'
            Explanation: After 'quiero' the second verb stays in the infinitive \
            — say 'beber' (to drink), not the conjugated 'bebo' (I drink).

            Example 5
            English: "My sisters are tall."
            Correct Spanish: "Mis hermanas son altas."
            Learner said: "Mi hermana es alta."
            Diff: missing 'mis', 'hermanas', 'son', 'altas'; extra 'mi', \
            'hermana', 'es', 'alta'
            Explanation: The expected sentence is plural ('mis hermanas son \
            altas' — my sisters are tall); your attempt is singular.
            """)

        let prompt = """
        English: "\(question)"
        Correct Spanish: "\(expected)"
        Learner said: "\(attempt)"
        Diff: \(diff)
        Explanation:
        """

        do {
            let response = try await session.respond(
                to: prompt,
                options: GenerationOptions(temperature: 0.3)
            )
            return response.content
        } catch {
            print("[SpeakOffline] FoundationModels error: \(error)")
            return nil
        }
    }

    /// Word-level diff between the expected Spanish answer and the speech-to-
    /// text attempt. Normalizes both sides (lowercase, drop diacritics, strip
    /// punctuation), then uses `CollectionDifference` to find which words are
    /// in the expected answer but missing from the attempt, and vice versa.
    ///
    /// Returns a one-line summary the LLM can use directly:
    ///   "missing 'la', 'maestra'; extra 'el', 'maestro'"
    ///   "only minor accent/punctuation differences"
    static func wordDiff(expected: String, attempt: String) -> String {
        let exp = normalize(expected)
        let att = normalize(attempt)

        if exp == att {
            return "only minor accent/punctuation differences"
        }

        let diff = att.difference(from: exp)
        var missing: [String] = []   // in expected, not in attempt
        var extra: [String] = []     // in attempt, not in expected
        for change in diff {
            switch change {
            case .insert(_, let token, _): extra.append(token)
            case .remove(_, let token, _): missing.append(token)
            }
        }

        var parts: [String] = []
        if !missing.isEmpty {
            parts.append("missing " + missing.map { "'\($0)'" }.joined(separator: ", "))
        }
        if !extra.isEmpty {
            parts.append("extra " + extra.map { "'\($0)'" }.joined(separator: ", "))
        }
        return parts.isEmpty
            ? "only minor accent/punctuation differences"
            : parts.joined(separator: "; ")
    }

    /// Lowercase, strip diacritics, drop punctuation, split on whitespace.
    /// Same normalization shape as FlashcardViewModel.normalize but returns
    /// tokens rather than a joined string.
    private static func normalize(_ s: String) -> [String] {
        s.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }
}
