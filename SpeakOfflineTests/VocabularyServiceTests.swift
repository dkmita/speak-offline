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

    func test_englishToSpanish_singleton() {
        XCTAssertEqual(service.spanish(for: "milk"), ["leche"])
        XCTAssertEqual(service.spanish(for: "goodbye"), ["adiós"])
    }

    func test_spanishToEnglish_singleton() {
        XCTAssertEqual(service.english(for: "agua"), ["water"])
        XCTAssertEqual(service.english(for: "perro"), ["dog"])
    }

    func test_englishToSpanish_returnsAllConjugations() {
        // "have" maps to multiple conjugations of `tener`.
        let translations = service.spanish(for: "have")
        XCTAssertTrue(translations.contains("tener"))
        XCTAssertTrue(translations.contains("tiene"))
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
