# The vocabulary loop: journal

The owner's goal (2026-11-16): run the vocabulary loop with Sonnet writers, have Opus fix every vocabulary or
grammar gap it exposes, and continue to a corpus of 5,000 vocabulary words. After every 50 new words: stop, think
hard about whether the direction is right, write it here, and act on it in the next batch.

## How it runs

1. **Write.** A batch of briefs from `briefs.txt` (one line each: what the app does, never which words to use).
   Each goes to a Sonnet writer with the open prompt (`tool/notation/notation.sh prompt --open --width 1280`:
   grammar and core only, any word allowed) and the instruction to write two to four screens under `### name`
   lines. Answers are kept unedited in `corpus/<batch>/answers/<slug>.txt`. One answer per brief, one pass, no
   retries; the writer reads nothing but the prompt and its brief.
2. **Count.** `tool/notation/notation.sh vocabulary tool/vocabulary/corpus --design-system design_systems/cards
   --out tool/vocabulary/all` expands every answer of every batch with today's parser and aliases, and
   `count.py` gives the size: the distinct words written (a parameter, flag, event or variant counted per type
   it was written on). Because the whole corpus is recounted each time, a fix shows up as old words resolving.
3. **Fix.** The words several answers reached for, and every grammar issue, go to an Opus fixer on a branch: an
   alias where we have the thing under another name, the natural line made to work where the notation was
   narrower than the grammar suggests, a new word or component where we have nothing. Reviewed, tested and
   merged before the next batch is counted.
4. **Review.** After each batch (every 50 new words or more): what the numbers say, whether the last review's
   decisions worked, and what changes for the next batch. Reviews end in decisions.

## What is measured

- **Corpus size**: distinct words (the goal: 5,000).
- **Resolved share**: of those, how many are core, a component or an alias. This is the number the fixes move.
- **Lines that stand in**: the share of an answer's lines whose first word we do not have (what a reader sees).
- **Grammar issues per 1,000 lines**: the grammar is not open, so each is a defect in the grammar, the core, or
  the prompt.
- **Does not validate / render errors** per screen.

## Baseline (batch 0: `corpus/2026-11-16-sonnet`, 20 large apps, before any fix from this journal)

20 files, 105 screens, 4,657 lines. **477 distinct words**: 166 types (64 core, 16 Cards components, 9 aliases,
77 unknown), 158 unknown parameters, 50 flags, 28 events, 28 verbs, 15 formula functions, 8 variants, 24 alias
uses. Resolved 113 (23.7%). 4.0% of lines stand in. 184 grammar issues (39.5 per 1,000 lines). 70 validation
errors.

Reading of the baseline:
- The share of *lines* we cannot read is small (4%); the share of *distinct words* we cannot read is large
  (76%). Models reuse the core heavily and reach outside it in many small, different ways: mostly parameters on
  words we already have (158), not new types (77).
- So the first fixes are parameters and flags on core words (`size=`, `selected=`, `leading=`, `fuzzy`), a
  `Table` in the shape models write, and the grammar's narrow spots (a choice between actions, binding to a
  field). New drawn components (`SeatMap`, `Waveform`) come later and are one answer each.
- 20 large apps gave 477 words. To reach 5,000 the briefs must be many and varied rather than long: the next
  batches use short briefs across unrelated domains.

## Reviews

(newest last)
