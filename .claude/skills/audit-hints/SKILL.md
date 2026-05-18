---
name: audit-hints
description: Run a coverage audit on the SpeakOffline tap-hint system. Use when the user asks to "audit hints", check tap-hint coverage, evaluate hint quality, or after changes to HintResolver, vocab.json, idioms.json, or the seed cards. Simulates the resolver against every English word on every seed card, classifies each tap as match / unmatched / structural_drop / no_hint, and reports a headline match rate that excludes expected language-pattern drops.
version: 0.1.0
---

# Audit hints

Use this skill when the user asks to audit hint coverage in the SpeakOffline iOS app, or whenever you change one of:

- `SpeakOffline/Services/HintResolver.swift`
- `SpeakOffline/vocab.json`
- `scripts/idioms.json`
- `SpeakOffline/seed.json`

## How to run

### Forward audit (default) — does the resolver match?

```
python3 .claude/skills/audit-hints/audit.py
```

Reads `SpeakOffline/vocab.json` and `SpeakOffline/seed.json` and prints:

- Per-bucket counts (match / unmatched / structural_drop / no_hint).
- A **headline match rate** computed against `total - structural_drop`.
- A sample of unmatched cases (dict had candidates but none matched the answer).

### Reverse audit — what idioms are missing?

```
python3 .claude/skills/audit-hints/audit.py --reverse
```

Walks the *Spanish* answer of every card and finds runs of tokens that no English word or 2-/3-word window in the source could plausibly produce (via `en_to_es`, including stem matching). Expands each uncovered run by one explained word of context on each side, then groups identical phrases across cards and sorts by frequency.

The output is a ranked list of candidates for `scripts/idioms.json`. Use it when the user asks to find idiom gaps or to extend the curated idioms file. Typical hits: periphrastic future (`voy a` / `vamos a`), time expressions (`a las ocho`), dative-of-affect verbs (`me gusta` / `me duele`), and fixed phrases (`cuando era joven`, `me gustaría saber`).

## Interpreting the buckets

| Bucket | Meaning | Treat as actionable? |
|---|---|---|
| `match` | At least one candidate appeared in the Spanish answer (success). | n/a |
| `unmatched` | Dict returned candidates but none of them appear in the answer — the user sees a hint that won't help them produce the Spanish. | **Yes — investigate.** |
| `no_hint` | Dict had nothing for the tapped word. | Yes — usually a missing entry. |
| `structural_drop` | Tapped word is an expected English-only artifact (see below). | **No — language difference, not a bug.** |

## What counts as a structural drop

Spanish systematically drops or restructures certain English words. Counting these as `unmatched` inflates the failure rate and gets in the way of finding real gaps. The script detects three:

1. **Subject pronouns** (I / you / we / they / he / she) when the Spanish answer has no subject pronoun — Spanish conjugation already encodes the subject.
2. **"to" as an infinitive marker** — when the next word isn't an article/determiner ("to eat" → "comer", not "to" + something).
3. **Auxiliary do / does / did** when sentence-initial — question scaffolding that Spanish handles via `¿…?` or word order.

If you discover a new structural pattern during an audit (e.g. "the" before proper nouns, "be" + adjective → "tener" + noun, English modal auxiliaries with no Spanish counterpart), update `is_structural_drop` in `audit.py` and re-run.

## When NOT to add to the structural-drop bucket

Don't bucket something as "structural" just because the resolver couldn't match it. Structural drops are *systematic language differences*. A missing idiom, a missing inflection, a stem-matching miss — those are genuinely unmatched. The bar for adding a new category is "Spanish virtually never expresses this English word."

## Reporting back

When summarizing for the user, lead with the **headline match rate** (excluding structural drops). Then break out `unmatched` vs `no_hint` separately so it's clear whether the gap is "dict has the wrong translation" (unmatched) vs "dict is missing this word" (no_hint). Show a handful of unmatched examples so the user can sanity-check.
