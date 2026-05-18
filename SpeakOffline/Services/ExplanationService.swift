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

        let session = LanguageModelSession(instructions: """
            You are a Spanish tutor. Compare the correct Spanish translation \
            to the learner's spoken attempt and explain ONLY the differences \
            between them. Do not mention or acknowledge anything the learner \
            got right. Focus exclusively on what is wrong: wrong or missing \
            words, gender or number agreement, verb conjugation, tense, or \
            word order. Be concise — one or two short sentences.

            The attempt comes from speech-to-text, so small recognition \
            artifacts (missing accents, dropped tiny function words, \
            slightly misheard short words) are usually transcription noise, \
            not real mistakes — ignore those.
            """)

        let prompt = """
        English prompt: "\(question)"
        Correct Spanish: "\(expected)"
        Learner attempted: "\(attempt)"
        """

        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            print("[SpeakOffline] FoundationModels error: \(error)")
            return nil
        }
    }
}
