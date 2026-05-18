#!/usr/bin/env python3
"""
Merge scripts/idioms.json into SpeakOffline/vocab.json.

Run after editing idioms.json to add new conversational idioms. Keys are the
contraction-EXPANDED form ("you are welcome", not "you're welcome") because
that's the form the resolver looks up after expanding contractions.
"""
import json, os, sys

VOCAB = 'SpeakOffline/Resources/vocab.json'
IDIOMS = 'scripts/idioms.json'

vocab = json.load(open(VOCAB))
idioms = json.load(open(IDIOMS))
en_to_es = vocab['en_to_es']

added = 0
merged = 0
for en, es in idioms.items():
    if en.startswith('_'):  # skip comment fields
        continue
    if en in en_to_es:
        # Promote curated translations to the front, then dedup + cap at 8
        existing = list(en_to_es[en])
        for e in reversed(es):
            if e in existing:
                existing.remove(e)
            existing.insert(0, e)
        en_to_es[en] = sorted(existing[:8])
        merged += 1
    else:
        en_to_es[en] = sorted(es)
        added += 1

vocab['en_to_es'] = {k: sorted(v) for k, v in sorted(en_to_es.items())}
vocab['meta']['uniqueEnKeys'] = len(en_to_es)

with open(VOCAB, 'w', encoding='utf-8') as f:
    json.dump(vocab, f, ensure_ascii=False, separators=(',', ':'), sort_keys=True)

print(f'Added: {added}', file=sys.stderr)
print(f'Merged (curated values promoted to front): {merged}', file=sys.stderr)
print(f'Total EN keys: {len(en_to_es)}', file=sys.stderr)
print(f'File: {os.path.getsize(VOCAB)/1024/1024:.2f} MB', file=sys.stderr)
