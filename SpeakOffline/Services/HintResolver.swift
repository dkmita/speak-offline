import Foundation

/// A multi-word phrase that the dictionary matched against this card's answer.
struct PhraseMatch: Equatable, Hashable {
    /// Spanish translations of the phrase.
    let translations: [String]
    /// Source-word indices that the phrase spans, inclusive.
    let span: ClosedRange<Int>
}

/// Structured outcome of a single tap hint lookup.
struct HintResult: Equatable {
    /// Translations for the tapped word alone. May be empty.
    let single: [String]

    /// Matched multi-word phrases that involve the tapped word. Ordered by
    /// the resolver's probe order: 2-word phrases first (left-pair then
    /// right-pair), then 3-word phrases (left-triple, middle-triple,
    /// right-triple).
    let phrases: [PhraseMatch]

    var isEmpty: Bool {
        single.isEmpty && phrases.isEmpty
    }

    static let empty = HintResult(single: [], phrases: [])
}

/// Picks Spanish hints for an English word on a flashcard.
///
/// Probes the dictionary with the tapped word alone plus every adjacent
/// 2- and 3-word window that includes the tap. Contractions are expanded
/// before lookup ("don't" → "do not"), so a tap on a contraction looks up
/// the full form instead of fragments.
struct HintResolver {
    let vocabulary: VocabularyService

    init(vocabulary: VocabularyService = .shared) {
        self.vocabulary = vocabulary
    }

    /// Returns the structured hint result for the tap at `index`.
    func resolve(forIndex index: Int, sourceWords: [String], answer: String) -> HintResult {
        guard sourceWords.indices.contains(index) else { return .empty }
        let answerTokens = Self.answerMatchTokens(answer)
        // Stem set used as a permissive secondary match against the answer.
        // Catches lemma/inflected-sibling pairs like tener↔tengo, rojo↔roja
        // that exact-token equality misses.
        let answerStems = Set(answerTokens.map(Self.spanishStem))

        // Single-word lookup. For contractions this becomes a phrase key
        // (e.g., "don't" → "do not"); for everything else it's one token.
        // If the full phrase form isn't in the dictionary, fall back to the
        // first expanded token alone — usable for taps on contractions like
        // "can't" where "can not" isn't a dict entry but "can" is.
        let singleTokens = Self.lookupTokens(forWord: sourceWords[index])
        let singleKey = singleTokens.joined(separator: " ")
        var singleCandidates = singleKey.isEmpty ? [] : vocabulary.spanish(for: singleKey)
        if singleCandidates.isEmpty, singleTokens.count > 1 {
            singleCandidates = vocabulary.spanish(for: singleTokens[0])
        }
        let single = pickSingle(
            from: singleCandidates,
            answerTokens: answerTokens,
            answerStems: answerStems
        )

        // Adjacent-window phrase lookups. Spans are inclusive on both ends
        // and refer to source-word indices, not token indices — a span of
        // two source words can become a 3-token key if one is a contraction.
        let probeSpans: [ClosedRange<Int>] = [
            (index - 1)...index,           // left pair
            index...(index + 1),           // right pair
            (index - 2)...index,           // left triple
            (index - 1)...(index + 1),     // mid triple
            index...(index + 2)            // right triple
        ]
        var phrases: [PhraseMatch] = []
        for span in probeSpans {
            if let match = phraseMatch(
                forSpan: span,
                sourceWords: sourceWords,
                answerTokens: answerTokens,
                answerStems: answerStems
            ) {
                phrases.append(match)
            }
        }

        return HintResult(single: single, phrases: phrases)
    }

    private func pickSingle(
        from candidates: [String],
        answerTokens: Set<String>,
        answerStems: Set<String>
    ) -> [String] {
        guard !candidates.isEmpty else { return [] }
        // Always return the top-ranked collapse groups (3 by default) instead
        // of narrowing to "only candidates in the answer". Narrowing would
        // give away the answer and hide useful alternatives. But if any
        // candidate DOES appear in the answer, force its group into the
        // top 3 so the actual answer word is guaranteed to be visible
        // alongside the alternatives.
        let matching = Set(candidates.filter {
            matches(candidate: $0, answerTokens: answerTokens, answerStems: answerStems)
        })
        return Self.topRankedCandidates(
            from: candidates,
            maxGroups: 3,
            prefer: matching
        )
    }

    /// Look up the phrase covering `span`, returning a `PhraseMatch` only if
    /// at least one translation's tokens all appear in the answer.
    private func phraseMatch(
        forSpan span: ClosedRange<Int>,
        sourceWords: [String],
        answerTokens: Set<String>,
        answerStems: Set<String>
    ) -> PhraseMatch? {
        guard span.lowerBound >= 0,
              span.upperBound < sourceWords.count
        else { return nil }
        let tokens = span.flatMap { Self.lookupTokens(forWord: sourceWords[$0]) }
        guard !tokens.isEmpty else { return nil }
        let key = tokens.joined(separator: " ")
        let matching = vocabulary.spanish(for: key).filter {
            matches(candidate: $0, answerTokens: answerTokens, answerStems: answerStems)
        }
        guard !matching.isEmpty else { return nil }
        return PhraseMatch(translations: matching, span: span)
    }

    /// True if every tokenized part of the candidate appears in the answer.
    /// "Appears" means exact-token equality OR the part's Spanish stem
    /// equals one of the answer's stems (length ≥ 3). The stem path catches
    /// lemma/inflected-sibling mismatches like `tener` (dict) vs `tengo`
    /// (answer) and `rojo` vs `roja`.
    private func matches(candidate: String, answerTokens: Set<String>, answerStems: Set<String>) -> Bool {
        let parts = Self.tokenize(candidate)
        guard !parts.isEmpty else { return false }
        return parts.allSatisfy { part in
            if answerTokens.contains(part) { return true }
            let stem = Self.spanishStem(part)
            return stem.count >= 3 && answerStems.contains(stem)
        }
    }

    // MARK: - Static helpers

    /// Common English contractions and their expanded forms. Applied when
    /// deriving lookup keys so the dictionary sees the full form
    /// ("don't" → "do not") instead of the tokenize-split artifacts
    /// ("don" + "t"). Possessives like "mother's" / "Monet's" / "o'clock"
    /// are deliberately NOT here — they're not contractions and have their
    /// own dictionary entries (or fall back to the noun stem).
    static let contractions: [String: String] = [
        // be / not / will / would
        "i'm": "i am",
        "you're": "you are",
        "he's": "he is",
        "she's": "she is",
        "it's": "it is",
        "we're": "we are",
        "they're": "they are",
        "i'll": "i will",
        "you'll": "you will",
        "he'll": "he will",
        "she'll": "she will",
        "we'll": "we will",
        "they'll": "they will",
        "i'd": "i would",
        "you'd": "you would",
        "he'd": "he would",
        "she'd": "she would",
        "we'd": "we would",
        "they'd": "they would",
        "i've": "i have",
        "you've": "you have",
        "we've": "we have",
        "they've": "they have",
        // negations
        "don't": "do not",
        "doesn't": "does not",
        "didn't": "did not",
        "isn't": "is not",
        "aren't": "are not",
        "wasn't": "was not",
        "weren't": "were not",
        "hasn't": "has not",
        "haven't": "have not",
        "hadn't": "had not",
        "won't": "will not",
        "wouldn't": "would not",
        "can't": "can not",
        "couldn't": "could not",
        "shouldn't": "should not",
        "mustn't": "must not",
        // 's / 're / 've / 'll on common subjects
        "that's": "that is",
        "there's": "there is",
        "here's": "here is",
        "what's": "what is",
        "where's": "where is",
        "who's": "who is",
        "how's": "how is",
        "let's": "let us",
        "y'all": "you all"
    ]

    /// Returns the dictionary-lookup tokens for a single source word.
    ///
    /// Known contractions expand to their full form ("don't" → ["do", "not"]).
    /// Possessives and other apostrophe words drop to their alphanumeric core
    /// ("mother's" → ["mother"]). Plain words return a single-element array.
    /// Empty input or pure punctuation returns an empty array.
    static func lookupTokens(forWord word: String) -> [String] {
        let lower = word.lowercased()
        let stripped = lower.trimmingCharacters(
            in: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted
        )
        if let expanded = contractions[stripped] {
            return expanded.components(separatedBy: " ").filter { !$0.isEmpty }
        }
        return tokenize(word).first.map { [$0] } ?? []
    }

    /// Split on anything that isn't a Unicode letter or digit, lowercased.
    /// Used for matching tokens in answers and candidate translations; not
    /// contraction-aware — call `lookupTokens(forWord:)` for source words.
    static func tokenize(_ s: String) -> [String] {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Reduce a Spanish token to a comparable stem.
    ///
    /// Pipeline:
    /// 1. Lowercase + strip diacritics (so `rojó`/`rojo` compare equal).
    /// 2. If the surface form is a known irregular form with no useful
    ///    suffix to strip (`soy`, `voy`, `hay`, `he`, `ha`, …), map it
    ///    directly to the lemma stem.
    /// 3. Strip the longest matching Spanish inflection suffix, requiring
    ///    a result of ≥ 3 chars. Catches regular noun/adjective
    ///    plurals/genders and regular verb conjugations.
    /// 4. If the stripped stem matches a known irregular stem variant
    ///    (`teng`, `tien`, `tuv` from `tener`; `pued`, `pud` from `poder`;
    ///    etc.), normalize it to a canonical stem (`ten`, `pod`) so all
    ///    variants of one lemma collapse together.
    static func spanishStem(_ s: String) -> String {
        let normalized = s.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
        if let direct = irregularSurfaceForms[normalized] {
            return direct
        }
        for suf in spanishInflectionSuffixes {
            if normalized.count > suf.count + 2 && normalized.hasSuffix(suf) {
                let stem = String(normalized.dropLast(suf.count))
                return irregularStemMap[stem] ?? stem
            }
        }
        return normalized
    }

    /// Spanish inflection suffixes, longest first so the matcher strips the
    /// longest applicable ending. Kept conservative — short single-char
    /// gender endings (-o/-a) are at the bottom of the priority list.
    private static let spanishInflectionSuffixes: [String] = [
        "ariamos", "eriamos", "iriamos",
        "abamos", "iamos",
        "ariais", "eriais", "iriais",
        "aremos", "eremos", "iremos",
        "asteis", "isteis", "ierais",
        "iendo", "yendo",
        "abais", "iabamos",
        "ados", "adas", "idos", "idas",
        "aron", "ieron", "eron",
        "amos", "emos", "imos",
        "aban", "ian", "ais", "eis",
        "ando", "ndo",
        "ado", "ada", "ido", "ida",
        "aba", "ias", "ria",
        "an", "en",
        "ar", "er", "ir",
        "as", "es", "os", "is",
        "io",
        "a", "e", "o", "s"
    ]

    /// Common irregular Spanish surface forms with no strippable suffix.
    /// These bypass suffix stripping and map directly to a canonical lemma
    /// stem so e.g. `soy` and `ser` both stem to `ser`, and `hay`/`he`/`ha`
    /// all stem to `hab` (haber).
    private static let irregularSurfaceForms: [String: String] = [
        // ser
        "soy": "ser",
        // ir
        "voy": "ir",
        // dar
        "doy": "dar",
        // ver
        "veo": "ver",
        // haber (auxiliary "have")
        "hay": "hab", "he": "hab", "ha": "hab", "has": "hab", "han": "hab", "hemos": "hab",
        // estar
        "estoy": "est"
    ]

    /// Irregular stem variants → canonical stem. Applied after suffix
    /// stripping to unify forms whose stems shift between persons/tenses.
    /// E.g. `tener` (lemma) strips to `ten`; `tengo` strips to `teng`;
    /// `tienes` strips to `tien`; `tuvo` strips to `tuv`. Mapping the
    /// three variants back to `ten` lets the matcher treat them as one.
    private static let irregularStemMap: [String: String] = [
        // tener
        "teng": "ten", "tien": "ten", "tuv": "ten", "tendr": "ten",
        // venir
        "veng": "ven", "vien": "ven", "vin": "ven", "vendr": "ven",
        // poder
        "pued": "pod", "pud": "pod", "podr": "pod",
        // querer
        "quier": "quer", "quis": "quer", "querr": "quer",
        // hacer
        "hag": "hac", "hic": "hac", "hiz": "hac", "hech": "hac", "har": "hac",
        // decir
        "dig": "dec", "dij": "dec", "dir": "dec", "dich": "dec",
        // poner
        "pong": "pon", "pus": "pon", "pondr": "pon", "puest": "pon",
        // salir
        "salg": "sal", "saldr": "sal",
        // saber
        "sep": "sab", "sup": "sab", "sabr": "sab",
        // estar
        "estuv": "est",
        // ser
        "ere": "ser", "som": "ser", "sea": "ser", "sid": "ser",
        // ir (and overlap with ser past — favor ir here)
        "iba": "ir", "vay": "ir", "yend": "ir",
        // dar
        "dad": "dar",
        // ver
        "vist": "ver", "vea": "ver",
        // haber stem variants
        "hub": "hab", "habr": "hab", "haya": "hab", "habid": "hab", "habi": "hab"
    ]

    /// The set of tokens to use when checking whether a candidate translation
    /// appears in the card's answer. Includes every plain token plus any
    /// clitic-split forms ("conocerte" also contributes "conocer" and "te").
    ///
    /// The original token is always kept, so a wrong split can't cause a real
    /// match to be missed — at worst it adds harmless noise.
    static func answerMatchTokens(_ answer: String) -> Set<String> {
        let raw = tokenize(answer)
        var set = Set(raw)
        for tok in raw {
            let parts = splitEnclitics(tok)
            if parts.count > 1 {
                set.formUnion(parts)
            }
        }
        return set
    }

    /// Spanish enclitic pronoun suffixes, longest first to avoid premature
    /// matches (e.g. test "selo" before "lo").
    private static let cliticSuffixes: [String] = [
        "noslas", "noslos", "melas", "melos", "telas", "telos", "selas", "selos",
        "nosla", "noslo", "mela", "melo", "tela", "telo", "sela", "selo",
        "les", "los", "las", "nos",
        "me", "te", "se", "le", "lo", "la"
    ]
    private static let spanishVowels: Set<Character> = ["a", "e", "i", "o", "u", "á", "é", "í", "ó", "ú"]

    /// If a Spanish answer token looks like `<infinitive-or-gerund> + <clitic>`
    /// ("conocerte" → "conocer" + "te"), return the split. Otherwise return
    /// `[token]`. Conservative — requires a long-enough verb-form prefix and
    /// a consonant immediately before short -ar/-er/-ir endings, which filters
    /// false positives like "fuerte", "parte", "firme" whose endings are
    /// accidental.
    static func splitEnclitics(_ token: String) -> [String] {
        for suf in cliticSuffixes {
            // Require ≥4-char prefix before the clitic — short verbs like
            // "verte" (ver+te) get caught here as a false negative; the
            // tradeoff is fewer false-positive splits on common short words.
            guard token.count >= suf.count + 4, token.hasSuffix(suf) else { continue }
            let prefix = String(token.dropLast(suf.count))

            let last2 = prefix.suffix(2)
            if last2 == "ar" || last2 == "er" || last2 == "ir" {
                // For short verb endings, require a consonant immediately
                // before — filters "fuer-te", "suer-te" (vowel before).
                let beforeIdx = prefix.index(prefix.endIndex, offsetBy: -3)
                let beforeChar = prefix[beforeIdx]
                if !spanishVowels.contains(beforeChar) {
                    return [prefix, suf]
                }
            } else if prefix.hasSuffix("ando") || prefix.hasSuffix("iendo") || prefix.hasSuffix("yendo") {
                return [prefix, suf]
            }
        }
        return [token]
    }

    /// Pick the top `maxGroups` collapse-groups from a list of candidates and
    /// return their flat members in group-order.
    ///
    /// Ranking inside the candidate pool:
    ///   1. `prefer` membership DESC — any group containing a preferred
    ///      candidate (e.g. a word that appears in the card's answer) is
    ///      guaranteed to win against equal-or-lower ranked groups.
    ///   2. Group size DESC — words with multiple inflections (gender pairs,
    ///      conjugation siblings) tend to be the common, useful translations.
    ///   3. Shortest-member length ASC — short forms are usually more common.
    ///   4. Alphabetical — stable tiebreaker.
    ///
    /// Members of each group are returned in their original (alphabetical)
    /// order so that the view's `collapseVariants` re-groups them correctly.
    /// For "teacher" with no preference this yields [maestra, maestro,
    /// profesor, profesora, enseñador, enseñante] → "maestr[a/o] /
    /// profesor[/a] / enseña[dor/nte]". If the answer contains "docente",
    /// passing `prefer: ["docente"]` bumps its group into the top 3:
    /// "docente / maestr[a/o] / profesor[/a]".
    static func topRankedCandidates(
        from candidates: [String],
        maxGroups: Int,
        prefer: Set<String> = []
    ) -> [String] {
        var seen = Set<String>()
        let unique = candidates.filter { seen.insert($0).inserted }
        guard !unique.isEmpty else { return [] }

        var groups: [[String]] = []
        for item in unique {
            if let idx = groups.firstIndex(where: { g in
                g.allSatisfy { canCollapse($0, item) }
            }) {
                groups[idx].append(item)
            } else {
                groups.append([item])
            }
        }

        groups.sort { lhs, rhs in
            let lhsPref = lhs.contains { prefer.contains($0) }
            let rhsPref = rhs.contains { prefer.contains($0) }
            if lhsPref != rhsPref { return lhsPref }
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            let lhsMin = lhs.map(\.count).min() ?? 0
            let rhsMin = rhs.map(\.count).min() ?? 0
            if lhsMin != rhsMin { return lhsMin < rhsMin }
            return (lhs.first ?? "") < (rhs.first ?? "")
        }

        return Array(groups.prefix(maxGroups).flatMap { $0 })
    }

    /// Collapse strings sharing a common prefix into `prefix[end1/end2/...]`.
    /// Useful for shrinking hint cells that would otherwise list every
    /// gender/number/person variant separately, e.g.
    ///   ["negro", "negra", "negros", "negras"] → ["negr[o/a/os/as]"]
    ///   ["come", "comes", "comen"]             → ["come[/s/n]"]
    ///   ["rojo", "amarillo"]                    → ["rojo", "amarillo"] (no group)
    ///
    /// Grouping rules: a candidate joins an existing cluster only if it
    /// shares a ≥3-char prefix with every member AND each tail (the part
    /// after the common prefix) is ≤4 chars. This filters loose matches
    /// like ["ser", "soy"] (1-char LCP) or ["negro", "negruzco"] (4-char
    /// tail vs. 0). Order is preserved by first-appearance.
    static func collapseVariants(_ items: [String]) -> [String] {
        var seen = Set<String>()
        let unique = items.filter { seen.insert($0).inserted }
        guard unique.count > 1 else { return unique }

        var clusters: [[String]] = []
        for item in unique {
            if let idx = clusters.firstIndex(where: { cluster in
                cluster.allSatisfy { canCollapse($0, item) }
            }) {
                clusters[idx].append(item)
            } else {
                clusters.append([item])
            }
        }

        return clusters.map { cluster -> String in
            guard cluster.count > 1 else { return cluster[0] }
            let prefix = longestCommonPrefix(cluster)
            guard prefix.count >= 3 else { return cluster.joined(separator: " / ") }
            let tails = cluster.map { String($0.dropFirst(prefix.count)) }
            return "\(prefix)[\(tails.joined(separator: "/"))]"
        }
    }

    /// True if two strings share a long-enough common prefix and short-enough
    /// tails to merit collapsing into a single bracketed hint.
    private static func canCollapse(_ a: String, _ b: String) -> Bool {
        let lcp = longestCommonPrefix(a, b)
        guard lcp.count >= 3 else { return false }
        let tailA = a.count - lcp.count
        let tailB = b.count - lcp.count
        return tailA <= 4 && tailB <= 4 && (tailA > 0 || tailB > 0)
    }

    /// Longest common prefix of two strings.
    private static func longestCommonPrefix(_ a: String, _ b: String) -> String {
        let aChars = Array(a)
        let bChars = Array(b)
        let n = min(aChars.count, bChars.count)
        var i = 0
        while i < n && aChars[i] == bChars[i] { i += 1 }
        return String(aChars[0..<i])
    }

    /// Longest common prefix of an array of strings.
    private static func longestCommonPrefix(_ strs: [String]) -> String {
        guard let first = strs.first else { return "" }
        var prefix = first
        for s in strs.dropFirst() {
            prefix = longestCommonPrefix(prefix, s)
            if prefix.isEmpty { return "" }
        }
        return prefix
    }

    /// The keys probed in the dictionary for a tap at `index`: the word
    /// alone, then 2- and 3-word adjacent windows. Contraction expansion
    /// happens at the per-word level, so a 2-source-word window with one
    /// contraction produces a 3-token key. Exposed for tests.
    static func lookupKeys(forIndex index: Int, sourceWords: [String]) -> [String] {
        guard sourceWords.indices.contains(index),
              !lookupTokens(forWord: sourceWords[index]).isEmpty
        else { return [] }

        let probes: [(Int, Int)] = [
            (index, index),                  // single
            (index - 1, index),              // left pair
            (index, index + 1),              // right pair
            (index - 2, index),              // left triple
            (index - 1, index + 1),          // mid triple
            (index, index + 2)               // right triple
        ]
        var keys: [String] = []
        for (lo, hi) in probes {
            guard lo >= 0, hi < sourceWords.count else { continue }
            let tokens = (lo...hi).flatMap { lookupTokens(forWord: sourceWords[$0]) }
            guard !tokens.isEmpty else { continue }
            keys.append(tokens.joined(separator: " "))
        }
        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }
}
