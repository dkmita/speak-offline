import Foundation

/// In-memory bidirectional EN ↔ ES vocab lookup, seeded from a bundled JSON
/// produced from github.com/jmbeach/duolingo-vocab-lists. Used to power the
/// tap-a-word hint feature on flashcards; the reverse direction is exposed for
/// future use cases.
///
/// Keys are normalized to lowercase. A single key may map to multiple
/// translations (e.g. "have" → ten / tienes / tenemos / …); callers receive
/// the full list ordered alphabetically.
final class VocabularyService {

    static let shared = VocabularyService()

    private let enToEs: [String: [String]]
    private let esToEn: [String: [String]]

    init(bundle: Bundle = .main, resource: String = "vocab", ext: String = "json") {
        guard
            let url = bundle.url(forResource: resource, withExtension: ext,
                                 subdirectory: "Resources"),
            let data = try? Data(contentsOf: url),
            let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            // Missing/corrupt bundle resource is a build-time bug, not a runtime
            // error to recover from. Fail loud in DEBUG, degrade silently in
            // release so the app still runs (callers get empty lookups).
            assertionFailure("VocabularyService: bundled vocab.\(ext) missing or unreadable")
            self.enToEs = [:]
            self.esToEn = [:]
            return
        }
        self.enToEs = payload.en_to_es
        self.esToEn = payload.es_to_en
    }

    /// Translations from English → Spanish. Returns `[]` if the word/phrase is
    /// not in the vocab. Lookup is case-insensitive.
    func spanish(for english: String) -> [String] {
        enToEs[normalize(english)] ?? []
    }

    /// Translations from Spanish → English. Returns `[]` if not present.
    /// Lookup is case-insensitive.
    func english(for spanish: String) -> [String] {
        esToEn[normalize(spanish)] ?? []
    }

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private struct Payload: Decodable {
        let en_to_es: [String: [String]]
        let es_to_en: [String: [String]]
    }
}
