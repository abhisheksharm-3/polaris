---
description: Run a domain-modeling session that builds a ubiquitous-language glossary and an ADR ledger
argument-hint: "<the domain, feature, or term to model>"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

<!-- Adapted from mattpocock/skills (MIT): domain-modeling -->

# Domain

Model the domain in `$ARGUMENTS` into shared language: one canonical term per concept, defined once,
so the team and the code use the same words. Read `.polaris/config.json` first. This is a working
session, not a one-shot generate: you and the human sharpen terms together until each is precise.

## What it produces

- **A glossary at `CONTEXT.md` in the repo root.** This is the one Polaris doc that lives with the
  code, not under `.polaris/`, because it is meant to sit beside `src/` and be cross-referenced with
  live code as the language and the code drift apart. (Rule 7: `doc-organization.md` says every doc
  lives under `.polaris/`; the glossary is the deliberate exception, since a glossary read against the
  code has to live where the code is.)
- **An ADR ledger at `docs/adr/NNNN-slug.md`.** One file per decision, numbered in order. To add one,
  scan `docs/adr/` for the highest number and increment.

Create either only when there is something to write: the first resolved term creates `CONTEXT.md`, the
first real decision creates `docs/adr/`. No empty scaffolding.

## Glossary format

```
# {Context}

One sentence describing what this context is.

## Language

**Term**: A one- or two-sentence definition of what it is, not what it does.
_Avoid_: rejected synonym, another rejected synonym
```

Be opinionated: pick one canonical term per concept and reject the rest on the `_Avoid_` line. Exclude
general programming concepts; a glossary holds domain terms, nothing else. No implementation detail. It
is a glossary and only a glossary.

## ADR format

Each ADR is one to three sentences: the context, the decision, and why. Optional sections, only when
they earn their place:

- **Status** (frontmatter): proposed, accepted, deprecated, or superseded by ADR-NNNN.
- **Considered options** — the alternatives you weighed.
- **Consequences** — what the decision commits you to.

## Multi-context repos

A root `CONTEXT-MAP.md` marks a multi-context repo. There, each context gets its own
`src/<ctx>/CONTEXT.md` and `src/<ctx>/docs/adr/`, and the map lists the contexts and how they relate
(which calls which, which owns which data).

## The session loop

Run these continuously as the human talks, not as a checklist you finish once:

1. **Challenge conflicts.** When a term the human uses clashes with one already in the glossary, say
   so and resolve it to one meaning.
2. **Sharpen the fuzzy.** When a term is vague or carries two meanings, split or narrow it to one
   precise canonical term.
3. **Stress-test relationships.** Probe how terms relate with concrete edge-case scenarios, not
   abstractions: "an order with no line items, is that still an order?"
4. **Cross-reference the code.** Read the actual code and surface where it contradicts the glossary,
   the wrong name, a stale meaning, two names for one thing.
5. **Write inline.** The moment a term resolves, update `CONTEXT.md` then and there. Do not batch
   edits to the end.
6. **Offer an ADR only when all three hold:** the decision is hard to reverse, surprising without the
   context, and the result of a real trade-off. If any one is missing, skip it; not every choice is an
   ADR.
