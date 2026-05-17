import XCTest
@testable import SpeakOffline

final class HintResolverTests: XCTestCase {

    private lazy var resolver = HintResolver(
        vocabulary: VocabularyService(bundle: Bundle(for: VocabularyService.self))
    )

    // MARK: - Single-word lookups

    func test_picksTheFormThatAppearsInTheAnswer() {
        // "red" maps to [roja, rojas, rojo]. Answer uses the feminine
        // singular "roja" — we should pick exactly that, not the masculine
        // or plural forms.
        let words = ["The", "red", "bicycle"]
        let result = resolver.resolve(forIndex: 1, sourceWords: words, answer: "La bicicleta roja.")
        XCTAssertEqual(result.single, ["roja"])
        XCTAssertTrue(result.leftPair.isEmpty)
        XCTAssertTrue(result.rightPair.isEmpty)
        XCTAssertNil(result.fallback)
    }

    func test_caseAndPunctuationDoNotBreakLookup() {
        let words = ["Red,", "please."]
        let result = resolver.resolve(forIndex: 0, sourceWords: words, answer: "Rojo, por favor.")
        XCTAssertEqual(result.single, ["rojo"])
    }

    func test_singletonTranslationIsReturnedDirectly() {
        let result = resolver.resolve(forIndex: 0, sourceWords: ["milk"], answer: "leche")
        XCTAssertEqual(result.single, ["leche"])
    }

    func test_returnsTopCandidatesWhenNoneMatchAnswer() {
        // "have" has candidates [ten, tenemos, tener, ...] but the answer
        // doesn't contain any of them — single should fall back to top 3.
        let result = resolver.resolve(forIndex: 0, sourceWords: ["have"], answer: "blah xyz")
        XCTAssertFalse(result.single.isEmpty)
        XCTAssertLessThanOrEqual(result.single.count, 3)
        XCTAssertNil(result.fallback)
    }

    // MARK: - Phrase lookups

    func test_tappingLeftWordOfPhraseSurfacesRightPair() {
        // Tap "Good" in "Good morning, María" → right-pair lookup of
        // "good morning" → "buenos días" matches the answer.
        let words = ["Good", "morning,", "María"]
        let result = resolver.resolve(forIndex: 0, sourceWords: words, answer: "Buenos días, María.")
        XCTAssertEqual(result.rightPair, ["buenos días"])
        XCTAssertTrue(result.leftPair.isEmpty)
        // Single may also have candidates (top fallback); that's fine, just
        // confirm the phrase is captured.
    }

    func test_tappingRightWordOfPhraseSurfacesLeftPair() {
        let words = ["Good", "morning,", "María"]
        let result = resolver.resolve(forIndex: 1, sourceWords: words, answer: "Buenos días, María.")
        XCTAssertEqual(result.leftPair, ["buenos días"])
        XCTAssertTrue(result.rightPair.isEmpty)
    }

    func test_phraseDoesNotContributeWhenAnswerLacksIt() {
        // "the red" → "el rojo" exists in the dictionary, but the answer
        // "La bicicleta roja." doesn't contain "el" or "rojo". The phrase
        // must not pollute the result.
        let words = ["The", "red", "bicycle"]
        let result = resolver.resolve(forIndex: 1, sourceWords: words, answer: "La bicicleta roja.")
        XCTAssertTrue(result.leftPair.isEmpty, "unexpected leftPair: \(result.leftPair)")
        XCTAssertTrue(result.rightPair.isEmpty, "unexpected rightPair: \(result.rightPair)")
    }

    // MARK: - Fallback

    func test_fallsBackToProportionalWhenNothingMatches() {
        // "Bicycle" isn't in the vocab dictionary; proportional mapping
        // should produce a position-mapped answer word.
        let words = ["The", "red", "bicycle"]
        let answer = "La bicicleta roja"
        let result = resolver.resolve(forIndex: 2, sourceWords: words, answer: answer)
        XCTAssertTrue(result.single.isEmpty)
        XCTAssertTrue(result.leftPair.isEmpty)
        XCTAssertTrue(result.rightPair.isEmpty)
        XCTAssertNotNil(result.fallback)
        XCTAssertTrue(answer.lowercased().contains(result.fallback!.lowercased()))
    }

    func test_emptyAnswerHasNoFallback() {
        let result = resolver.resolve(forIndex: 0, sourceWords: ["asdfqwert"], answer: "")
        XCTAssertTrue(result.isEmpty)
    }

    func test_outOfRangeIndexReturnsEmpty() {
        let result = resolver.resolve(forIndex: 5, sourceWords: ["milk"], answer: "leche")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - lookupKeys / tokenize helpers

    func test_lookupKeys_returnsSingleAndAdjacentPairs() {
        let words = ["Good", "morning,", "María"]
        XCTAssertEqual(HintResolver.lookupKeys(forIndex: 0, sourceWords: words), ["good", "good morning"])
        XCTAssertEqual(HintResolver.lookupKeys(forIndex: 1, sourceWords: words), ["morning", "good morning", "morning maría"])
        XCTAssertEqual(HintResolver.lookupKeys(forIndex: 2, sourceWords: words), ["maría", "morning maría"])
    }

    func test_lookupKeys_outOfBoundsReturnsEmpty() {
        XCTAssertEqual(HintResolver.lookupKeys(forIndex: 5, sourceWords: ["a", "b"]), [])
        XCTAssertEqual(HintResolver.lookupKeys(forIndex: -1, sourceWords: ["a"]), [])
    }

    func test_tokenizeStripsPunctuationAndLowercases() {
        XCTAssertEqual(HintResolver.tokenize("Hello, world!"), ["hello", "world"])
        XCTAssertEqual(HintResolver.tokenize("¿Cómo estás?"), ["cómo", "estás"])
        XCTAssertEqual(HintResolver.tokenize("  "), [])
    }
}
