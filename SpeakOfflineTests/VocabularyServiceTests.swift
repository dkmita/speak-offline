import XCTest
@testable import SpeakOffline

final class VocabularyServiceTests: XCTestCase {

    // The test target hosts inside the app, so the main bundle has vocab.json.
    // We use the app target's bundle via VocabularyService.self to be explicit.
    private lazy var service = VocabularyService(bundle: Bundle(for: VocabularyService.self))

    func test_loadsBundledVocab() {
        // Smoke test: the JSON is bundled and decoded into non-empty maps.
        XCTAssertFalse(service.spanish(for: "milk").isEmpty)
        XCTAssertFalse(service.english(for: "agua").isEmpty)
    }

    func test_englishToSpanish_primaryTranslationsArePresent() {
        // The Wiktextract base includes archaic synonyms and inflected
        // variants alongside the primary translation, so we assert presence
        // rather than exact equality.
        XCTAssertTrue(service.spanish(for: "milk").contains("leche"))
        XCTAssertTrue(service.spanish(for: "goodbye").contains("adiós"))
    }

    func test_spanishToEnglish_primaryTranslationsArePresent() {
        XCTAssertTrue(service.english(for: "agua").contains("water"))
        XCTAssertTrue(service.english(for: "perro").contains("dog"))
    }

    func test_englishToSpanish_returnsAllConjugations() {
        // "have" should include both lemma and conjugated forms of `tener`.
        let translations = service.spanish(for: "have")
        XCTAssertTrue(translations.contains("tener"))
        XCTAssertGreaterThan(translations.count, 1)
    }

    func test_lookupIsCaseInsensitive() {
        let lower = service.spanish(for: "milk")
        let upper = service.spanish(for: "MILK")
        let mixed = service.spanish(for: "  Milk  ")
        XCTAssertEqual(lower, upper)
        XCTAssertEqual(lower, mixed)
    }

    func test_missingWord_returnsEmpty() {
        XCTAssertEqual(service.spanish(for: "asdkfjaslkdfj"), [])
        XCTAssertEqual(service.english(for: "xyzpqrst"), [])
    }
}
