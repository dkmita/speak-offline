# Documentation

Planning docs for the SpeakOffline Spanish curriculum. Source-of-truth
for regenerating the card library in `SpeakOffline/cards.json`.

## Lesson structure (Duolingo-aligned)

The course mirrors Duolingo's Spanish-from-English Path: 8 sections, 286
units, ~2,000 cards. Each section file lists the units in order with their
grammar focus, vocab, and 3–6 sample sentences per unit.

- [LESSON_STRUCTURE.md](LESSON_STRUCTURE.md) — overview, schema notes, plus
  Sections 1 (Rookie, Intro) and 2 (Explorer, A1) in detail
- [LESSON_STRUCTURE_S3.md](LESSON_STRUCTURE_S3.md) — Section 3 (Traveler, A1 cap):
  stem-changing verbs, comparisons, preterite introduced
- [LESSON_STRUCTURE_S4.md](LESSON_STRUCTURE_S4.md) — Section 4 (Trailblazer, A2):
  imperfect, present perfect, future, formal commands
- [LESSON_STRUCTURE_S5.md](LESSON_STRUCTURE_S5.md) — Section 5 (Pathfinder, B1):
  conditional, subjunctive introduced, past perfect
- [LESSON_STRUCTURE_S6.md](LESSON_STRUCTURE_S6.md) — Section 6 (Wanderer, B1):
  relative pronouns, past subjunctive, passive voice
- [LESSON_STRUCTURE_S7.md](LESSON_STRUCTURE_S7.md) — Section 7 (Challenger, B2):
  conditional sentences, future perfect, complex tenses
- [LESSON_STRUCTURE_S8.md](LESSON_STRUCTURE_S8.md) — Section 8 (Navigator, B2 finale):
  possessive pronouns, verb+preposition pairs, polish

## Notation inside the section files

- ✅ **confirmed** — unit content was pulled directly from a per-unit source
  (The Owl and Me blog). About 7 of 286 units.
- 🧠 **inferred** — unit title is confirmed (duolingodata.com 286-unit list);
  vocab/grammar/samples are educated guesses based on the title and
  pedagogical sequence. About 279 of 286 units. Treat with care when
  regenerating cards.
- ⚠️ **partial** — mix of confirmed and inferred for that unit.
