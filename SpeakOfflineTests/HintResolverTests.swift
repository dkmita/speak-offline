import XCTest
@testable import SpeakOffline

final class HintResolverTests: XCTestCase {

    private lazy var resolver = HintResolver(
        vocabulary: VocabularyService(bundle: Bundle(for: VocabularyService.self))
    )

    // MARK: - Single-word lookups

    func test_picksTheFormThatAppearsInTheAnswer() {
        // "red" maps to all gender/number forms — roja, rojas, rojo. The
        // answer uses "roja" (feminine). With stem matching, all three
        // candidates whose stem `roj` is in the answer come through, but
        // crucially the form the answer actually uses is among them.
        let words = ["The", "red", "bicycle"]
        let result = resolver.resolve(forIndex: 1, sourceWords: words, answer: "La bicicleta roja.")
        XCTAssertTrue(result.single.contains("roja"),
                      "expected `roja` in single matches; got: \(result.single)")
        XCTAssertTrue(result.phrases.isEmpty, "unexpected phrases: \(result.phrases)")
    }

    func test_caseAndPunctuationDoNotBreakLookup() {
        let words = ["Red,", "please."]
        let result = resolver.resolve(forIndex: 0, sourceWords: words, answer: "Rojo, por favor.")
        XCTAssertTrue(result.single.contains("rojo"),
                      "expected `rojo` in single matches; got: \(result.single)")
    }

    func test_singletonTranslationIsReturnedDirectly() {
        let result = resolver.resolve(forIndex: 0, sourceWords: ["milk"], answer: "leche")
        XCTAssertEqual(result.single, ["leche"])
    }

    func test_returnsTopCandidatesWhenNoneMatchAnswer() {
        let result = resolver.resolve(forIndex: 0, sourceWords: ["have"], answer: "blah xyz")
        XCTAssertFalse(result.single.isEmpty)
        XCTAssertLessThanOrEqual(result.single.count, 3)
    }

    // MARK: - Two-word phrase lookups

    func test_tappingLeftWordOfPairSurfacesRightPair() {
        // Tap "Good" — the right-pair "good morning" matches.
        let words = ["Good", "morning,", "María"]
        let result = resolver.resolve(forIndex: 0, sourceWords: words, answer: "Buenos días, María.")
        let phrase = result.phrases.first { $0.translations.contains("buenos días") }
        XCTAssertNotNil(phrase, "expected a phrase match for 'good morning', got: \(result.phrases)")
        XCTAssertEqual(phrase?.span, 0...1)
    }

    func test_tappingRightWordOfPairSurfacesLeftPair() {
        let words = ["Good", "morning,", "María"]
        let result = resolver.resolve(forIndex: 1, sourceWords: words, answer: "Buenos días, María.")
        let phrase = result.phrases.first { $0.translations.contains("buenos días") }
        XCTAssertNotNil(phrase)
        XCTAssertEqual(phrase?.span, 0...1)
    }

    func test_pairDoesNotContributeWhenAnswerLacksIt() {
        // "the red" → "el rojo" but answer has neither — no phrase match.
        let words = ["The", "red", "bicycle"]
        let result = resolver.resolve(forIndex: 1, sourceWords: words, answer: "La bicicleta roja.")
        XCTAssertTrue(result.phrases.isEmpty, "unexpected phrases: \(result.phrases)")
    }

    // MARK: - Three-word phrase lookups

    func test_threeWordPhraseFromMiddle() {
        // Tap "the" with "all" to the left and "time" to the right —
        // the mid-triple "all the time" → "todo el tiempo" matches.
        let words = ["I", "think", "about", "you", "all", "the", "time."]
        let result = resolver.resolve(forIndex: 5, sourceWords: words, answer: "Pienso en ti todo el tiempo.")
        let phrase = result.phrases.first { $0.translations.contains("todo el tiempo") }
        XCTAssertNotNil(phrase, "expected mid-triple match, got: \(result.phrases)")
        XCTAssertEqual(phrase?.span, 4...6)
    }

    func test_threeWordPhraseFromLeftEdge() {
        // Tap "all" — the right-triple "all the time" matches.
        let words = ["I", "think", "about", "you", "all", "the", "time."]
        let result = resolver.resolve(forIndex: 4, sourceWords: words, answer: "Pienso en ti todo el tiempo.")
        let phrase = result.phrases.first { $0.translations.contains("todo el tiempo") }
        XCTAssertNotNil(phrase, "expected right-triple match, got: \(result.phrases)")
        XCTAssertEqual(phrase?.span, 4...6)
    }

    func test_threeWordPhraseFromRightEdge() {
        // Tap "time" — the left-triple "all the time" matches.
        let words = ["I", "think", "about", "you", "all", "the", "time."]
        let result = resolver.resolve(forIndex: 6, sourceWords: words, answer: "Pienso en ti todo el tiempo.")
        let phrase = result.phrases.first { $0.translations.contains("todo el tiempo") }
        XCTAssertNotNil(phrase, "expected left-triple match, got: \(result.phrases)")
        XCTAssertEqual(phrase?.span, 4...6)
    }

    // MARK: - No-hint cases

    func test_unknownWordReturnsEmptyResult() {
        // A nonsense word the dictionary can't possibly know. With the
        // proportional fallback gone, the result is empty and the view will
        // show no hint above the tapped word.
        let result = resolver.resolve(forIndex: 0, sourceWords: ["asdfqwertzxcv"], answer: "La bicicleta roja")
        XCTAssertTrue(result.isEmpty)
    }

    func test_outOfRangeIndexReturnsEmpty() {
        let result = resolver.resolve(forIndex: 5, sourceWords: ["milk"], answer: "leche")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - lookupKeys / tokenize helpers

    func test_lookupKeys_includesAllAdjacentWindows() {
        let words = ["a", "b", "c", "d", "e"]
        // Tap index 2 ("c"): single + 2 pairs + 3 triples = 6 keys.
        XCTAssertEqual(
            HintResolver.lookupKeys(forIndex: 2, sourceWords: words),
            ["c", "b c", "c d", "a b c", "b c d", "c d e"]
        )
    }

    func test_lookupKeys_skipsWindowsThatRunOffTheEdge() {
        let words = ["a", "b", "c"]
        // Tap leftmost: only right-leaning windows are valid.
        XCTAssertEqual(
            HintResolver.lookupKeys(forIndex: 0, sourceWords: words),
            ["a", "a b", "a b c"]
        )
        // Tap rightmost: only left-leaning windows are valid.
        XCTAssertEqual(
            HintResolver.lookupKeys(forIndex: 2, sourceWords: words),
            ["c", "b c", "a b c"]
        )
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

    // MARK: - Spanish enclitic handling

    func test_splitEnclitics_splitsInfinitivePlusClitic() {
        XCTAssertEqual(HintResolver.splitEnclitics("conocerte"), ["conocer", "te"])
        XCTAssertEqual(HintResolver.splitEnclitics("ayudarme"), ["ayudar", "me"])
        XCTAssertEqual(HintResolver.splitEnclitics("encontrarlo"), ["encontrar", "lo"])
        XCTAssertEqual(HintResolver.splitEnclitics("repetirla"), ["repetir", "la"])
        XCTAssertEqual(HintResolver.splitEnclitics("hacerle"), ["hacer", "le"])
    }

    func test_splitEnclitics_doesNotSplitNounsWithAccidentalVerbEndings() {
        // "fuerte" / "suerte" have prefixes (fuer/suer) that end in "er" but
        // with a vowel before — these should NOT split.
        XCTAssertEqual(HintResolver.splitEnclitics("fuerte"), ["fuerte"])
        XCTAssertEqual(HintResolver.splitEnclitics("suerte"), ["suerte"])
        // "parte" / "firme" are too short — prefix < 4 chars.
        XCTAssertEqual(HintResolver.splitEnclitics("parte"), ["parte"])
        XCTAssertEqual(HintResolver.splitEnclitics("firme"), ["firme"])
    }

    func test_answerMatchTokens_includesClitcSplitForms() {
        let tokens = HintResolver.answerMatchTokens("Mucho gusto en conocerte.")
        XCTAssertTrue(tokens.contains("conocerte"), "original token must be preserved")
        XCTAssertTrue(tokens.contains("conocer"), "split prefix must be added")
        XCTAssertTrue(tokens.contains("te"), "split clitic must be added")
    }

    func test_resolveMatchesAcrossEnclitic() {
        // Tap "you" in "Nice to meet you" — answer is "Mucho gusto en
        // conocerte." Before the clitic fix, "te" (a translation of "you")
        // wouldn't match "conocerte" and the resolver fell back. Now the
        // answer token set includes "te" via the split.
        let words = ["Nice", "to", "meet", "you"]
        let result = resolver.resolve(forIndex: 3, sourceWords: words, answer: "Mucho gusto en conocerte.")
        XCTAssertTrue(result.single.contains("te"),
                      "expected 'te' to match via enclitic split; got: \(result.single)")
    }

    // MARK: - Contraction handling

    func test_lookupTokensExpandsKnownContractions() {
        XCTAssertEqual(HintResolver.lookupTokens(forWord: "don't"), ["do", "not"])
        XCTAssertEqual(HintResolver.lookupTokens(forWord: "I'm"), ["i", "am"])
        XCTAssertEqual(HintResolver.lookupTokens(forWord: "you're"), ["you", "are"])
        XCTAssertEqual(HintResolver.lookupTokens(forWord: "can't"), ["can", "not"])
    }

    func test_singleLookupFallsBackToFirstTokenForContractionsNotInDictAsPhrase() {
        // If "can not" isn't a phrase entry but "can" is a single-word entry,
        // a tap on "can't" should still return useful candidates by falling
        // back to the first expanded token. We don't assert specific Spanish
        // forms (those depend on dictionary contents); we just assert that
        // the tap surfaces *something* rather than coming back empty.
        let result = resolver.resolve(forIndex: 0, sourceWords: ["Can't"], answer: "")
        XCTAssertFalse(result.single.isEmpty, "expected fallback to single token; got empty")
    }

    func test_lookupTokensStripsTrailingPunctuationBeforeContractionLookup() {
        XCTAssertEqual(HintResolver.lookupTokens(forWord: "Don't,"), ["do", "not"])
        XCTAssertEqual(HintResolver.lookupTokens(forWord: "I'm!"), ["i", "am"])
    }

    func test_lookupTokensTreatsPossessivesAsNounStems() {
        // Possessives are not contractions — drop the trailing 's.
        XCTAssertEqual(HintResolver.lookupTokens(forWord: "mother's"), ["mother"])
        XCTAssertEqual(HintResolver.lookupTokens(forWord: "Monet's"), ["monet"])
        // o'clock isn't a contraction in our map either — falls to stem.
        XCTAssertEqual(HintResolver.lookupTokens(forWord: "o'clock"), ["o"])
    }

    func test_lookupTokensOnPlainWordsReturnsSingleStem() {
        XCTAssertEqual(HintResolver.lookupTokens(forWord: "Red,"), ["red"])
        XCTAssertEqual(HintResolver.lookupTokens(forWord: "  Hello!"), ["hello"])
        XCTAssertEqual(HintResolver.lookupTokens(forWord: "..."), [])
    }

    func test_lookupKeysExpandsContractionsInAdjacentWindows() {
        // Tap "don't" in "I don't know" — every window that includes the
        // contraction expands to "do not".
        let words = ["I", "don't", "know"]
        XCTAssertEqual(
            HintResolver.lookupKeys(forIndex: 1, sourceWords: words),
            ["do not", "i do not", "do not know", "i do not know"]
        )
    }

    // MARK: - Spanish stem matching

    func test_spanishStem_unifiesRegularVerbForms() {
        // Regular -ar verb: comprar / compramos / compre / comprado all
        // reduce to the same stem.
        XCTAssertEqual(HintResolver.spanishStem("comprar"), "compr")
        XCTAssertEqual(HintResolver.spanishStem("compramos"), "compr")
        XCTAssertEqual(HintResolver.spanishStem("comprado"), "compr")
    }

    func test_spanishStem_unifiesAdjectiveGenderAndNumber() {
        // rojo / roja / rojos / rojas → roj
        XCTAssertEqual(HintResolver.spanishStem("rojo"), "roj")
        XCTAssertEqual(HintResolver.spanishStem("roja"), "roj")
        XCTAssertEqual(HintResolver.spanishStem("rojos"), "roj")
        XCTAssertEqual(HintResolver.spanishStem("rojas"), "roj")
    }

    func test_spanishStem_normalizesIrregularStemVariants() {
        // tener family: lemma is "tener" → "ten", but conjugations stem to
        // "teng" / "tien" / "tuv" which the irregular map collapses to "ten".
        XCTAssertEqual(HintResolver.spanishStem("tener"), "ten")
        XCTAssertEqual(HintResolver.spanishStem("tengo"), "ten")
        XCTAssertEqual(HintResolver.spanishStem("tienes"), "ten")
        XCTAssertEqual(HintResolver.spanishStem("tiene"), "ten")
        XCTAssertEqual(HintResolver.spanishStem("tuvo"), "ten")
        // poder
        XCTAssertEqual(HintResolver.spanishStem("poder"), "pod")
        XCTAssertEqual(HintResolver.spanishStem("puedo"), "pod")
        XCTAssertEqual(HintResolver.spanishStem("pude"), "pod")
        // querer
        XCTAssertEqual(HintResolver.spanishStem("querer"), "quer")
        XCTAssertEqual(HintResolver.spanishStem("quiero"), "quer")
    }

    func test_spanishStem_handlesShortIrregularSurfaceForms() {
        // Surface forms with no strippable suffix get directly mapped.
        XCTAssertEqual(HintResolver.spanishStem("soy"), "ser")
        XCTAssertEqual(HintResolver.spanishStem("voy"), "ir")
        XCTAssertEqual(HintResolver.spanishStem("hay"), "hab")
        XCTAssertEqual(HintResolver.spanishStem("he"), "hab")
    }

    func test_spanishStem_stripsDiacritics() {
        // Accent variants normalize to the same stem.
        XCTAssertEqual(HintResolver.spanishStem("rojó"), "roj")
        XCTAssertEqual(HintResolver.spanishStem("estás"), HintResolver.spanishStem("estas"))
    }

    func test_resolveMatchesAcrossInflection() {
        // "have" returns infinitive `tener`, lemma `haber`, etc. The answer
        // uses `tengo` (1p sing of tener). Before stem matching, no
        // candidate matched and the resolver fell back. With stem matching,
        // `tener` / `tengo` both stem to `ten` and the match goes through.
        let result = resolver.resolve(
            forIndex: 1,
            sourceWords: ["I", "have", "a", "house"],
            answer: "Tengo una casa."
        )
        XCTAssertTrue(result.single.contains("tener"),
                      "expected `tener` to be matched via stem; got: \(result.single)")
    }

    func test_resolveMatchesAcrossGenderInflection() {
        // "red" returns `rojo` (masc) but answer uses `roja` (fem). Stem
        // matching unifies them via stem `roj`.
        let result = resolver.resolve(
            forIndex: 1,
            sourceWords: ["The", "red", "bicycle"],
            answer: "La bicicleta roja."
        )
        XCTAssertTrue(result.single.contains("rojo") || result.single.contains("roja"),
                      "expected a `roj*` form to be matched; got: \(result.single)")
    }
}
