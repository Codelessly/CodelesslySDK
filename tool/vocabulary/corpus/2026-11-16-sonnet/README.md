# The first vocabulary corpus: 20 app briefs, Sonnet, 2026-11-16

What a model writes when it is taught the notation's grammar and core only, and told the vocabulary is open
(codelessly_api `docs/design/19-open-vocabulary.md`).

## What is here

| | |
|---|---|
| `prompt.txt` | The prompt the answers were written from: an open-vocabulary preface, then the page prompt as it was before the behaviour words were added (grammar, core types, formulas, the page frames and overlays), 18,888 bytes. Today's equivalent is `tool/notation/notation.sh prompt --open --width 1280`. |
| `briefs/<app>.txt` | The 20 briefs, one per app (the app, its style, and: write every screen under a `### <screen name>` line, starting with `App` or `Page`; overlays after the screen that opens them; every interaction written, not described; output only the notation). They are the briefs of the milestone's sixth prompt set (`docs/projects/2026-11-milestone-1/prompts-dsl-6` in the editor repository), cut down to the app and the style. |
| `answers/<app>.txt` | Sonnet's answer to each brief: 105 screens, 4,657 lines that start with a word and 1,031 statements (state, if, each…). Nothing was edited here. |
| `vocabulary.json`, `VOCABULARY.md` | What `tool/notation/notation.sh vocabulary` says of the answers with the aliases in place (codelessly_api's built-in table and `design_systems/cards/vocabulary.json`). |
| `no-aliases/` | The same with `--no-aliases`: the count before any name was mapped. |

## How it was produced

`prompt.txt` and the briefs were written by a script (the open preface in front of the core prompt; from each brief of
the prompt set its `App:` and `Style:` lines and the instruction above). Each brief was answered by Claude Sonnet from
that prompt, one answer per brief, kept as `answers/<app>.txt` (they were `<app>.sonnet.txt`). How the requests were
sent (system or user message, sampling settings, whether any answer was asked for twice) was not recorded with the
files: the next corpus should say.

## How to count it again

```
tool/notation/notation.sh vocabulary tool/vocabulary/corpus/2026-11-16-sonnet
tool/notation/notation.sh vocabulary tool/vocabulary/corpus/2026-11-16-sonnet --no-aliases --out tool/vocabulary/corpus/2026-11-16-sonnet/no-aliases
```

and, to look at the pages (each app becomes a site folder; a stand-in is a plain column, so an unknown word that has
no text and nothing under it shows as empty room):

```
tool/notation/notation.sh vocabulary tool/vocabulary/corpus/2026-11-16-sonnet --out /tmp/vocab --sites /tmp/vocab/sites
tool/render/render.sh /tmp/vocab/sites/seat-booking --out /tmp/vocab/renders/seat-booking --sizes 1440x900,390x844 --full-page
```

## What it said (2026-11-16)

4,657 lines start with a word. 81.3% are a core word, 11.6% a Cards component, 3.1% an alias of a word we have, 4.0% a
word we do not have (6.5% before the aliases). The words, the parameters on words we have, the verbs, the formula
functions and the grammar issues are ranked in `VOCABULARY.md`; what was done about them is in the design note.

Counted again after the parser read what the grammar issues asked for (a choice between actions, binding to a
field, ids, the foot of an app window, `focus` and `copy`: codelessly_api CHANGELOG, Unreleased): 117 grammar
issues where there were 184, 185 lines of a word we do not have where there were 187 (147 an alias, 3.2%), 76
problems that do not validate where there were 70 (lines dropped before and read now). The answers are unchanged.

## The next corpus

A new folder beside this one, named `<date>-<model>`, with its own `prompt.txt` (the prompt it was actually written
from), `briefs/`, `answers/` and this tool's output. Do not edit an old corpus: the count is only comparable while the
answers are as they came.
