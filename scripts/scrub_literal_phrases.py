#!/usr/bin/env python3
"""
Scrub literal multi-word EN→ES entries from SpeakOffline/vocab.json.

A multi-word EN entry is "literal" when, position by position, each Spanish
word in the translation is reachable from the EN word at the same index via
a single-word en_to_es lookup (with Spanish-stem matching). The rule
requires same length AND aligned mapping — that's strict enough to leave
reordered phrases ("small dog" → "perro pequeño") and length-mismatched
ones ("the united states" → "estados unidos") in place, where the phrase
hint is actually doing work for taps on filler words like "the".

  drop:  "is very nice" → "es muy simpático"
         (is→es, very→muy, nice→simpát- — every position aligns)

  keep:  "the united states" → "estados unidos"
         (length mismatch — the→estados isn't even a position to check;
          a tap on "the" still benefits from the phrase hint)

  keep:  "you are welcome" → "de nada"
         (length mismatch + de/nada not reachable from any constituent)

  keep:  "small dog" → "perro pequeño"
         (same length, but small→perro / dog→pequeño don't align positionally)

Per-translation: a multi-word entry can keep some translations and drop
others. An entry whose translations all turn out to be literal is dropped
entirely.

Usage:
  python3 scripts/scrub_literal_phrases.py            # dry-run, prints stats
  python3 scripts/scrub_literal_phrases.py --apply    # rewrite vocab.json
"""
import json, os, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / ".claude" / "skills" / "audit-hints"))
from audit import spanish_stem, tokenize, CONTRACTIONS  # noqa: E402

VOCAB = REPO / "SpeakOffline" / "Bundled" / "vocab.json"

# Multi-word EN keys that are the expansion target of a contraction like
# "I'm" → "i am". The resolver's contraction path looks up the full expanded
# key and only falls back to the FIRST expanded token (not the auxiliary), so
# dropping these breaks hints on the contraction even if the constituent
# words individually map to the right Spanish via single-word lookups.
CONTRACTION_TARGETS = set(CONTRACTIONS.values())


def scrub(en_to_es: dict):
    new = {}
    full_drops = []        # (key, [translations]) — entry removed entirely
    partial_drops = []     # (key, [dropped_translations], [kept_translations])
    drop_count = 0

    for k, vals in en_to_es.items():
        if " " not in k:
            new[k] = vals
            continue
        if k in CONTRACTION_TARGETS:
            new[k] = vals
            continue

        en_words = k.split()
        # Per-position single-word lookup pools (token + stem)
        pos_tok = [set() for _ in en_words]
        pos_stem = [set() for _ in en_words]
        for i, w in enumerate(en_words):
            for c in en_to_es.get(w, []):
                for t in tokenize(c):
                    pos_tok[i].add(t)
                    s = spanish_stem(t)
                    if len(s) >= 3:
                        pos_stem[i].add(s)

        kept = []
        dropped = []
        for v in vals:
            es_toks = tokenize(v)
            if not es_toks:
                dropped.append(v)
                continue
            # Position-aligned literal: same length AND each ES word reachable
            # from the EN word at the same position.
            literal = len(es_toks) == len(en_words)
            if literal:
                for i, t in enumerate(es_toks):
                    if t in pos_tok[i]:
                        continue
                    s = spanish_stem(t)
                    if len(s) >= 3 and s in pos_stem[i]:
                        continue
                    literal = False
                    break
            if literal:
                dropped.append(v)
            else:
                kept.append(v)

        drop_count += len(dropped)
        if kept:
            new[k] = kept
            if dropped:
                partial_drops.append((k, dropped, kept))
        else:
            full_drops.append((k, dropped))

    return new, full_drops, partial_drops, drop_count


def main():
    vocab = json.load(open(VOCAB))
    en_to_es = vocab["en_to_es"]
    multiword = sum(1 for k in en_to_es if " " in k)

    new, full_drops, partial_drops, drop_count = scrub(en_to_es)

    print(f"Original EN keys:           {len(en_to_es):>6}")
    print(f"  single-word:              {len(en_to_es) - multiword:>6}")
    print(f"  multi-word:               {multiword:>6}")
    print()
    print(f"Entries dropped entirely:   {len(full_drops):>6}  (all translations were literal)")
    print(f"Entries partially scrubbed: {len(partial_drops):>6}  (kept ≥1 idiomatic translation)")
    print(f"Translations dropped:       {drop_count:>6}")
    print()
    print(f"New EN key count:           {len(new):>6}")
    print()
    print("Sample full drops:")
    for k, dropped in full_drops[:15]:
        print(f"  {k!r} → {dropped}")
    print()
    print("Sample partial drops (kept | dropped):")
    for k, dropped, kept in partial_drops[:10]:
        print(f"  {k!r}")
        print(f"    keep: {kept}")
        print(f"    drop: {dropped}")

    if "--apply" in sys.argv:
        vocab["en_to_es"] = {k: sorted(new[k]) for k in sorted(new)}
        vocab["meta"]["uniqueEnKeys"] = len(new)
        with open(VOCAB, "w", encoding="utf-8") as f:
            json.dump(vocab, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
        print()
        print(f"Wrote {VOCAB.relative_to(REPO)}: {os.path.getsize(VOCAB)/1024/1024:.2f} MB")


if __name__ == "__main__":
    main()
