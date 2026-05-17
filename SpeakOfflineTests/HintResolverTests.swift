import XCTest
@testable import SpeakOffline

final class HintResolverTests: XCTestCase {

    private lazy var resolver = HintResolver(
        vocabulary: VocabularyService(bundle: Bundle(for: VocabularyService.self))
    )

    // MARK: - Dictionary path

    func test_picksTheFormThatAppearsInTheAnswer() {
        // "red" maps to [roja, rojas, rojo]. The answer uses the feminine
        // singular "roja" — we should pick exactly that, not the masculine
        // or plural forms.
        let words = ["The", "red", "bicycle"]
        let hint = resolver.hint(forIndex: 1, sourceWords: words, answer: "La bicicleta roja.")
        XCTAssertEqual(hint, "roja")
    }

    func test_caseAndPunctuationDoNotBreakLookup() {
        // Capitalized source word with trailing punctuation; answer ends with
        // a period. Should still resolve cleanly.
        let words = ["Red,", "please."]
        let hint = resolver.hint(forIndex: 0, sourceWords: words, answer: "Rojo, por favor.")
        XCTAssertEqual(hint, "rojo")
    }

    func test_singletonTranslationIsReturnedDirectly() {
        let hint = resolver.hint(forIndex: 0, sourceWords: ["milk"], answer: "leche")
        XCTAssertEqual(hint, "leche")
    }

    func test_returnsCandidatesWhenNoneMatchAnswer() {
        // Dictionary has translations but none of them appear in the answer.
        // Should still return something useful (top candidates), not "?".
        let words = ["have"]
        let hint = resolver.hint(forIndex: 0, sourceWords: words, answer: "tengo")
        // "tengo" is in the answer so this is actually a matching case; verify
        // a no-match falls through to candidates instead by using an answer
        // that doesn't contain any tener form.
        XCTAssertFalse(hint.isEmpty)
        XCTAssertNotEqual(hint, "?")

        let noMatch = resolver.hint(forIndex: 0, sourceWords: words, answer: "blah xyz")
        XCTAssertFalse(noMatch.isEmpty)
        XCTAssertNotEqual(noMatch, "?")
        // Should be one or more candidates joined by " / "
        XCTAssertTrue(noMatch.contains("ten") || noMatch.contains("tien") || noMatch.contains("teng"))
    }

    // MARK: - Proportional fallback

    func test_fallsBackToProportionalWhenWordNotInDictionary() {
        // "Bicycle" isn't in the vocab dictionary; proportional mapping should
        // pick the corresponding answer word by position.
        let words = ["The", "red", "bicycle"]
        let answer = "La bicicleta roja"
        let hint = resolver.hint(forIndex: 2, sourceWords: words, answer: answer)
        // Index 2 of 3 source → maps to roughly the last word of the answer.
        // The proportional logic clamps to a range; "roja" or "bicicleta roja"
        // are both acceptable. Just check it returned an answer word, not "?".
        XCTAssertNotEqual(hint, "?")
        XCTAssertTrue(answer.lowercased().contains(hint.lowercased()))
    }

    func test_emptyAnswerReturnsQuestionMark() {
        let hint = resolver.hint(forIndex: 0, sourceWords: ["asdfqwert"], answer: "")
        XCTAssertEqual(hint, "?")
    }

    func test_outOfRangeIndexReturnsQuestionMark() {
        let hint = resolver.hint(forIndex: 5, sourceWords: ["milk"], answer: "leche")
        XCTAssertEqual(hint, "?")
    }

    // MARK: - Tokenize helper

    func test_tokenizeStripsPunctuationAndLowercases() {
        XCTAssertEqual(HintResolver.tokenize("Hello, world!"), ["hello", "world"])
        XCTAssertEqual(HintResolver.tokenize("¿Cómo estás?"), ["cómo", "estás"])
        XCTAssertEqual(HintResolver.tokenize("  "), [])
    }
}
