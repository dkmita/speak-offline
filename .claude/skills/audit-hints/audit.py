#!/usr/bin/env python3
"""
Hint-coverage audit for the SpeakOffline tap-hint system.

Simulates the resolver in pure Python: for every English word on every
seed card, computes whether a tap would produce a hint and whether at
least one candidate appears in the card's Spanish answer.

Buckets per tap:
  match            One or more candidates appear in the answer (success).
  structural_drop  Expected absence — see EXPECTED_DROPS below for details.
                   Counted separately so the headline match rate isn't
                   dragged down by language patterns that are pedagogically
                   accurate (Spanish dropping subject pronouns, "to" as an
                   infinitive marker, "do" as a question auxiliary).
  unmatched        Dict had candidates but none of them appear in the
                   answer — the user sees a hint cell whose contents won't
                   help them produce the Spanish. This is the bucket audit
                   work should focus on.
  no_hint          The dict had nothing for this word at all.

The "headline" match rate is computed against (total - structural_drop)
so it reflects only the cases the resolver could plausibly resolve.
"""

import json
import os
import re
import string
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path


# ============================================================
# Expected language-pattern drops.
# These English words/positions have NO direct Spanish counterpart in
# typical translations. Treating them as "unmatched" inflates the
# miss rate without representing real fixable cases.
# ============================================================

# Subject pronouns Spanish typically drops (the conjugation encodes the
# subject). We treat a tap as a structural drop if the English word is
# one of these AND no Spanish subject pronoun appears in the answer.
SUBJECT_PRONOUNS_EN = {"i", "you", "we", "they", "he", "she"}
SUBJECT_PRONOUNS_ES_MARKERS = (
    "yo ", "tú ", "tu ", "usted ", "ustedes ",
    "nosotros", "nosotras", "vosotros", "vosotras",
    "ellos", "ellas",
)

# Auxiliaries Spanish doesn't have an equivalent for. These appear in
# English questions/negations as scaffolding — Spanish handles via word
# order or just `¿`.
AUX_DO = {"do", "does", "did"}

# Articles English uses where Spanish drops them (with proper nouns,
# countries, professions in some constructions). Tighter to detect — we
# only flag when the immediately-next word is capitalized in the source
# and the answer doesn't include an article.
ARTICLES_EN = {"the", "a", "an"}


def is_structural_drop(word: str, source_words: list, index: int, answer: str) -> bool:
    """Classify a tap as an expected drop rather than a fixable fallback."""
    bare = word.lower().strip(string.punctuation + "¿¡")
    answer_lower = answer.lower()

    # Subject pronoun dropped.
    if bare in SUBJECT_PRONOUNS_EN:
        if not any(m in answer_lower for m in SUBJECT_PRONOUNS_ES_MARKERS):
            return True

    # "to" as an infinitive marker — followed by a verb. We approximate
    # "verb" as "not an article/determiner/preposition".
    if bare == "to" and index + 1 < len(source_words):
        nxt = source_words[index + 1].lower().strip(string.punctuation)
        DETS = {"the", "a", "an", "my", "your", "his", "her", "our", "their", "this", "that"}
        if nxt and nxt not in DETS:
            return True

    # Auxiliary do/does/did at the front of a question.
    if bare in AUX_DO and index == 0:
        return True

    return False


# ============================================================
# Resolver simulation — mirrors SpeakOffline/Services/HintResolver.swift
# ============================================================

CONTRACTIONS = {
    "i'm": "i am", "you're": "you are", "he's": "he is", "she's": "she is",
    "it's": "it is", "we're": "we are", "they're": "they are",
    "i'll": "i will", "you'll": "you will", "he'll": "he will",
    "she'll": "she will", "we'll": "we will", "they'll": "they will",
    "i'd": "i would", "you'd": "you would", "he'd": "he would",
    "she'd": "she would", "we'd": "we would", "they'd": "they would",
    "i've": "i have", "you've": "you have", "we've": "we have", "they've": "they have",
    "don't": "do not", "doesn't": "does not", "didn't": "did not",
    "isn't": "is not", "aren't": "are not", "wasn't": "was not", "weren't": "were not",
    "hasn't": "has not", "haven't": "have not", "hadn't": "had not",
    "won't": "will not", "wouldn't": "would not", "can't": "can not",
    "couldn't": "could not", "shouldn't": "should not", "mustn't": "must not",
    "that's": "that is", "there's": "there is", "here's": "here is",
    "what's": "what is", "where's": "where is", "who's": "who is",
    "how's": "how is", "let's": "let us", "y'all": "you all",
}
CLITICS = [
    "noslas", "noslos", "melas", "melos", "telas", "telos", "selas", "selos",
    "nosla", "noslo", "mela", "melo", "tela", "telo", "sela", "selo",
    "les", "los", "las", "nos",
    "me", "te", "se", "le", "lo", "la",
]
VOWELS = set("aeiouáéíóú")
IRREG_SURFACE = {
    "soy": "ser", "voy": "ir", "doy": "dar", "veo": "ver",
    "hay": "hab", "he": "hab", "ha": "hab", "has": "hab",
    "han": "hab", "hemos": "hab", "estoy": "est",
}
IRREG_STEM = {
    "teng": "ten", "tien": "ten", "tuv": "ten", "tendr": "ten",
    "veng": "ven", "vien": "ven", "vin": "ven", "vendr": "ven",
    "pued": "pod", "pud": "pod", "podr": "pod",
    "quier": "quer", "quis": "quer", "querr": "quer",
    "hag": "hac", "hic": "hac", "hiz": "hac", "hech": "hac", "har": "hac",
    "dig": "dec", "dij": "dec", "dir": "dec", "dich": "dec",
    "pong": "pon", "pus": "pon", "pondr": "pon", "puest": "pon",
    "salg": "sal", "saldr": "sal",
    "sep": "sab", "sup": "sab", "sabr": "sab",
    "estuv": "est",
    "ere": "ser", "som": "ser", "sea": "ser", "sid": "ser",
    "iba": "ir", "vay": "ir", "yend": "ir",
    "dad": "dar",
    "vist": "ver", "vea": "ver",
    "hub": "hab", "habr": "hab", "haya": "hab", "habid": "hab", "habi": "hab",
}
SUFFIXES = [
    "ariamos", "eriamos", "iriamos", "abamos", "iamos",
    "ariais", "eriais", "iriais", "aremos", "eremos", "iremos",
    "asteis", "isteis", "ierais",
    "iendo", "yendo", "abais", "iabamos",
    "ados", "adas", "idos", "idas", "aron", "ieron", "eron",
    "amos", "emos", "imos", "aban", "ian", "ais", "eis",
    "ando", "ndo", "ado", "ada", "ido", "ida",
    "aba", "ias", "ria",
    "an", "en", "ar", "er", "ir", "as", "es", "os", "is", "io",
    "a", "e", "o", "s",
]


def strip_acc(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", s) if not unicodedata.combining(c))


def tokenize(s: str) -> list:
    return [t for t in re.split(r"[^\w]+", s.lower(), flags=re.UNICODE) if t]


def split_clitics(t: str) -> list:
    for s in CLITICS:
        if len(t) >= len(s) + 4 and t.endswith(s):
            p = t[:-len(s)]
            if p[-2:] in ("ar", "er", "ir") and p[-3] not in VOWELS:
                return [p, s]
            if p.endswith(("ando", "iendo", "yendo")):
                return [p, s]
    return [t]


def ans_tokens(s: str) -> set:
    raw = tokenize(s)
    out = set(raw)
    for t in raw:
        p = split_clitics(t)
        if len(p) > 1:
            out.update(p)
    return out


def spanish_stem(s: str) -> str:
    n = strip_acc(s.lower())
    if n in IRREG_SURFACE:
        return IRREG_SURFACE[n]
    for suf in SUFFIXES:
        if len(n) > len(suf) + 2 and n.endswith(suf):
            stem = n[: -len(suf)]
            return IRREG_STEM.get(stem, stem)
    return n


def lookup_tokens(w: str) -> list:
    lo = w.lower()
    st = re.sub(r"^[^\w']+|[^\w']+$", "", lo)
    if st in CONTRACTIONS:
        return CONTRACTIONS[st].split()
    p = tokenize(w)
    return p[:1] if p else []


def matches(c: str, at: set, ast: set) -> bool:
    p = tokenize(c)
    if not p:
        return False
    for x in p:
        if x in at:
            continue
        s = spanish_stem(x)
        if len(s) >= 3 and s in ast:
            continue
        return False
    return True


# ============================================================
# Audit
# ============================================================

def audit(vocab_path: Path, seed_path: Path) -> dict:
    vocab = json.load(open(vocab_path))
    seed = json.load(open(seed_path))
    en_to_es = vocab["en_to_es"]

    stats = Counter()
    unmatched_examples = []  # collect a sample for reporting

    for deck in seed["decks"]:
        for card in deck["cards"]:
            words = card["back"].split()
            at = ans_tokens(card["front"])
            ast = {spanish_stem(t) for t in at}
            for i, w in enumerate(words):
                if is_structural_drop(w, words, i, card["front"]):
                    stats["structural_drop"] += 1
                    continue
                st = lookup_tokens(w)
                k = " ".join(st)
                cd = en_to_es.get(k, [])
                if not cd and len(st) > 1:
                    cd = en_to_es.get(st[0], [])
                sm = [x for x in cd if matches(x, at, ast)]
                ph = False
                for lo, hi in [(i - 1, i), (i, i + 1), (i - 2, i),
                               (i - 1, i + 1), (i, i + 2)]:
                    if lo < 0 or hi >= len(words):
                        continue
                    ts = []
                    for j in range(lo, hi + 1):
                        ts.extend(lookup_tokens(words[j]))
                    ck = en_to_es.get(" ".join(ts), [])
                    if any(matches(x, at, ast) for x in ck):
                        ph = True
                        break
                if sm or ph:
                    stats["match"] += 1
                elif cd:
                    stats["unmatched"] += 1
                    if len(unmatched_examples) < 20:
                        unmatched_examples.append({
                            "word": w,
                            "candidates": cd[:3],
                            "card_en": card["back"],
                            "card_es": card["front"],
                        })
                else:
                    stats["no_hint"] += 1

    return {"stats": dict(stats), "unmatched_examples": unmatched_examples}


def format_report(result: dict) -> str:
    s = result["stats"]
    total = sum(s.values())
    actionable = total - s.get("structural_drop", 0)
    lines = [f"Total taps simulated: {total}"]
    for k in ("match", "unmatched", "structural_drop", "no_hint"):
        v = s.get(k, 0)
        lines.append(f"  {k:18s} {v:5d}  ({100*v/total:5.1f}% of total)")
    if actionable > 0:
        m = s.get("match", 0)
        u = s.get("unmatched", 0)
        n = s.get("no_hint", 0)
        lines.append("")
        lines.append(f"Headline rates (excluding structural drops; out of {actionable}):")
        lines.append(f"  match     {100*m/actionable:5.1f}%")
        lines.append(f"  unmatched {100*u/actionable:5.1f}%")
        lines.append(f"  no_hint   {100*n/actionable:5.1f}%")
    if result["unmatched_examples"]:
        lines.append("")
        lines.append("Sample unmatched cases (dict had candidates, none matched):")
        for ex in result["unmatched_examples"][:10]:
            lines.append(f"  EN: {ex['card_en']!r}")
            lines.append(f"     tap {ex['word']!r} → {ex['candidates']}")
            lines.append(f"     ES: {ex['card_es']!r}")
    return "\n".join(lines)


# ============================================================
# Reverse audit — surface Spanish phrases in answers that no English
# word/phrase in the source explains. These are idiom candidates for
# `scripts/idioms.json` (e.g. "a las siete" for "at seven").
# ============================================================

def reverse_audit(vocab_path: Path, seed_path: Path) -> dict:
    vocab = json.load(open(vocab_path))
    seed = json.load(open(seed_path))
    en_to_es = vocab["en_to_es"]

    # phrase (context-expanded uncovered ES run) -> [(card_en, card_es), ...]
    candidates = defaultdict(list)

    for deck in seed["decks"]:
        for card in deck["cards"]:
            en_words = card["back"].split()
            es_raw = card["front"].split()
            es_tokens = []
            for w in es_raw:
                ts = tokenize(w)
                es_tokens.append(ts[0] if ts else "")

            # Gather every ES token (and its stem) that ANY en_to_es lookup
            # across the English source could produce. Includes single-word
            # entries plus 2- and 3-word windows.
            reach_tok = set()
            reach_stem = set()

            def absorb(key):
                for c in en_to_es.get(key, []):
                    for cpt in tokenize(c):
                        reach_tok.add(cpt)
                        s = spanish_stem(cpt)
                        if len(s) >= 3:
                            reach_stem.add(s)

            for w in en_words:
                lt = lookup_tokens(w)
                if not lt:
                    continue
                absorb(" ".join(lt))
                if len(lt) > 1:
                    absorb(lt[0])

            for size in (2, 3):
                for i in range(len(en_words) - size + 1):
                    ts = []
                    for j in range(i, i + size):
                        ts.extend(lookup_tokens(en_words[j]))
                    if ts:
                        absorb(" ".join(ts))

            # Mark ES answer tokens as explained or not.
            explained = [False] * len(es_tokens)
            for i, t in enumerate(es_tokens):
                if not t:
                    explained[i] = True  # punctuation-stripped to empty
                    continue
                if t in reach_tok:
                    explained[i] = True
                    continue
                s = spanish_stem(t)
                if len(s) >= 3 and s in reach_stem:
                    explained[i] = True

            # Find uncovered runs, expand by one explained word on each side
            # for context (so "las" surfaces as "a las siete" not bare "las").
            i = 0
            while i < len(es_tokens):
                if not explained[i] and es_tokens[i]:
                    j = i
                    while j < len(es_tokens) and not explained[j] and es_tokens[j]:
                        j += 1
                    lo = max(0, i - 1)
                    hi = min(len(es_tokens) - 1, j)
                    phrase = " ".join(t for t in es_tokens[lo:hi + 1] if t)
                    if phrase and len(phrase.split()) >= 2:
                        candidates[phrase].append((card["back"], card["front"]))
                    i = j
                else:
                    i += 1

    return dict(candidates)


def format_reverse(candidates: dict, top: int = 30) -> str:
    by_count = sorted(candidates.items(), key=lambda kv: (-len(kv[1]), kv[0]))
    total_pairs = sum(len(v) for v in candidates.values())
    lines = [
        f"Reverse audit — Spanish phrases in answers that no English word/phrase in",
        f"the source explained. {len(candidates)} distinct phrases across {total_pairs} card occurrences.",
        f"Phrases shown with one explained word of context on each side.",
        f"Top {min(top, len(by_count))} by frequency:",
        "",
    ]
    for phrase, cards in by_count[:top]:
        lines.append(f"[{len(cards)}x] {phrase!r}")
        for ce, cs in cards[:2]:
            lines.append(f"        EN: {ce!r}")
            lines.append(f"        ES: {cs!r}")
        lines.append("")
    return "\n".join(lines)


def main():
    repo = Path(__file__).resolve().parents[3]
    vocab = repo / "SpeakOffline" / "Bundled" / "vocab.json"
    seed = repo / "SpeakOffline" / "Bundled" / "cards.json"
    if not vocab.exists() or not seed.exists():
        print(f"Couldn't find vocab.json or cards.json under {repo}", file=sys.stderr)
        sys.exit(1)
    if "--reverse" in sys.argv:
        candidates = reverse_audit(vocab, seed)
        print(format_reverse(candidates))
    else:
        result = audit(vocab, seed)
        print(format_report(result))


if __name__ == "__main__":
    main()
