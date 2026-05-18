import Foundation
import FoundationModels

/// Wraps Apple's on-device Foundation Models framework to explain why a
/// learner's Spanish attempt missed the mark. Runs entirely on-device on
/// Apple-Intelligence-eligible devices (iPhone 15 Pro / 16 series and up).
/// No network traffic — works in airplane mode.
@available(iOS 18.1, *)
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
            You are a friendly Spanish tutor. The learner is translating from \
            English to Spanish and answering aloud, so their attempt may have \
            small speech-recognition errors (missing accents, dropped articles, \
            slightly misheard words). Focus on the real grammatical or \
            vocabulary mistake — gender agreement, verb conjugation, tense, \
            word choice, etc. — and explain it in one or two short sentences. \
            Mention how to say it correctly.
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
