# Review levels implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox
> (`- [ ]`) syntax.

**Goal:** Add a `level` argument to `workflows/review.js` that picks the dimension subset and the
reviewer effort, and batch the Confirm stage to one verifier per dimension instead of one per
finding.

**Architecture:** One data structure (`LEVELS`) holds the whole table. The existing `DIMENSIONS`
list stays as written and levels reference its `key` values, so the diff is a filter rather than a
restructure. The confirm threshold is a severity list per level, and the lens count is a lens list
per level, so `critical` runs the same code path as the other three with three entries instead of
one. Net change is roughly 40 lines in one file, plus three doc edits.

**Tech Stack:** The workflow runtime's injected globals: `args`, `agent`, `parallel`, `pipeline`,
`log`. No new dependency.

## Global Constraints

- One code file changes: `workflows/review.js`. No new file, agent, script, or hook. (Spec: Scope)
- No inline comments. The two existing comments in `review.js` sit at lines 47-48 and 52-53 as
  `//` block comments above a declaration; keep both and add none. (`rules/core.md` comment law,
  enforced by `hooks/guard-edit`)
- `over-engineering` is in every level's dimension set. A level without it deadlocks against
  `hooks/guard-review:9`. (Spec: AC8)
- No change to `rules/flows.json`, `verify.js`, `build.js`, or `.claude-plugin/plugin.json`.
  (Spec: Non-goals)
- Every prose line passes the writing standard; check with
  `bash scripts/check-patterns.sh prose <file>`. (Spec: Docs that go stale)

---

### Task 1: The level table and the resolution

**Files:**
- Modify: `workflows/review.js` (after `DIMENSIONS`, and the `target` line at 38)

**Interfaces:**
- Consumes: `args.level`, read the same way `args.target` is read today.
- Produces: `level` (a resolved string) and `L` (the level's row) for the rest of the file.

- [ ] **Step 1: Add `LEVELS` and the two lens lists below `DIMENSIONS`**

Insert after the `DIMENSIONS` array (current line 50), before the pipeline comment:

```js
const ONE_LENS = ['read the code and decide whether each claim holds']
const THREE_LENSES = ['does this actually reproduce', 'is the reasoning sound', 'is the fix implied by it correct']

const LEVELS = {
  low: { keys: ['correctness', 'over-engineering'], effort: 'low', confirm: [], lenses: ONE_LENS },
  mid: { keys: ['correctness', 'over-engineering', 'security', 'tests'], effort: 'medium', confirm: ['high'], lenses: ONE_LENS },
  high: { effort: 'high', confirm: ['high', 'medium'], lenses: ONE_LENS },
  critical: { effort: 'high', confirm: ['high', 'medium', 'low'], lenses: THREE_LENSES },
}
```

Three encodings, one per column of the spec's table:

- **Dimension subset:** `keys`, a list of `DIMENSIONS[].key` values. Absent means every dimension,
  which is what `high` and `critical` take. Referencing the keys leaves `DIMENSIONS` untouched;
  restructuring it into per-level lists would duplicate the `agent` and `ask` of each row four
  times and put the same dimension's wording in four places.
- **Effort:** `effort`, passed straight through to the reviewer's `agent()` options.
- **Confirm threshold:** `confirm`, the severities eligible for confirmation. One value per level,
  tested with `L.confirm.includes(f.severity)`, so `low` needs no branch: an empty list makes every
  finding ineligible and no verifier is dispatched.
- **Lens count:** `lenses`. `critical` differs from `high` by holding three entries instead of one,
  so the majority rule runs over one vote at the lower levels and three at `critical` without a
  second code path.

- [ ] **Step 2: Resolve the level below `LEVELS`**

Add this immediately after the `LEVELS` block from Step 1, not next to the `target` line at 38.
`const` declarations sit in a temporal dead zone until evaluated, so reading `LEVELS` or
`DIMENSIONS` above their declarations throws at run time even though the file parses.

```js
const asked = args ? args.level : undefined
const level = Object.hasOwn(LEVELS, asked) ? asked : 'high'
const L = LEVELS[level]
const dims = DIMENSIONS.filter(d => !L.keys || L.keys.includes(d.key))
if (asked !== undefined && level !== asked) log(`review level ${JSON.stringify(asked)} not recognized; running high`)
```

Why `Object.hasOwn` rather than `LEVELS[asked]` truthiness: `LEVELS['constructor']` is truthy
through the prototype chain and would resolve a bogus level to itself. `Object.hasOwn` coerces
`null` to the string `'null'` and `''` to `''`, neither of which is an own key, so both fall to
`high`. An absent `level` key gives `undefined`, which also falls to `high` and skips the log,
because nothing was rejected. AC10 and AC11 are both table lookup with no model call.

`log` is the runtime's logger, injected the same way `agent` and `parallel` are. `verify.js` calls
it at lines 85, 90, and 119, and `build.js` at 57 and 107, both at workflow top level, so it is
available here.

**Check:** `bash scripts/check-flows.sh` still passes, and `node --check workflows/review.js`
reports no syntax error.

---

### Task 2: The batched Confirm stage

**Files:**
- Modify: `workflows/review.js` (the `VERDICT` schema at 32-36, and the pipeline at 54-72)

**Interfaces:**
- Consumes: one dimension's `{ dimension, findings }` from the first pipeline stage.
- Produces: a flat array of findings for that dimension, each carrying `dimension`, `state`
  (`confirmed`, `refuted`, or `unconfirmed`), and `why`.

- [ ] **Step 3: Replace `VERDICT` with a keyed verdict list**

The current schema returns one verdict, so a batched verifier has nowhere to put the rest. Replace
lines 32-36 with:

```js
const VERDICTS = {
  type: 'object',
  required: ['verdicts'],
  properties: {
    verdicts: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'real', 'reason'],
        properties: {
          id: { type: 'integer' },
          real: { type: 'boolean' },
          reason: { type: 'string' },
        },
      },
    },
  },
}
```

`id` is the finding's 1-based position in the eligible list the prompt numbered. Position, not
`file:line`, because two findings from one dimension can land on the same line and a `file:line` key
would merge their verdicts. The `real` polarity is the one `review.js` already uses; `verify.js`
uses `refuted`, and the two files are not being unified here.

- [ ] **Step 4: Replace the second pipeline stage**

Replace lines 62-71 (the `parallel(r.findings.map(...))` stage) with:

```js
  r => {
    const eligible = r.findings.filter(f => L.confirm.includes(f.severity))
    const rest = r.findings
      .filter(f => !L.confirm.includes(f.severity))
      .map(f => ({ ...f, dimension: r.dimension, state: 'unconfirmed', why: 'below the confirm threshold for this level' }))
    if (eligible.length === 0) return rest
    const claims = eligible
      .map((f, i) => `${i + 1}. ${f.summary}\n   At ${f.file}:${f.line}\n   Proposed fix: ${f.fix}`)
      .join('\n')
    return parallel(
      L.lenses.map((lens, n) => () =>
        agent(
          `A ${r.dimension} reviewer raised these against ${target}:\n${claims}\n\n` +
            `Read the code and try to refute each one, through this lens: ${lens}.\n` +
            `Return one verdict per numbered claim, carrying its number as id. A finding that is ` +
            `true but trivial is not real; say so.`,
          {
            label: L.lenses.length > 1 ? `confirm:${r.dimension}:l${n + 1}` : `confirm:${r.dimension}`,
            phase: 'Confirm',
            agentType: 'polaris:verifier',
            schema: VERDICTS,
          },
        ),
      ),
    ).then(votes => {
      const cast = votes.filter(Boolean).flatMap(v => v.verdicts || [])
      return rest.concat(
        eligible.map((f, i) => {
          const mine = cast.filter(v => v.id === i + 1)
          if (mine.length === 0) return { ...f, dimension: r.dimension, state: 'unconfirmed', why: 'no verdict returned' }
          const kept = mine.filter(v => v.real).length
          const dissent = mine.find(v => !v.real) || mine[0]
          return { ...f, dimension: r.dimension, state: kept * 2 > mine.length ? 'confirmed' : 'refuted', why: dissent.reason }
        }),
      )
    })
  },
```

Four things this stage settles:

1. **Verdict to finding.** By `id` against the 1-based index of `eligible`. Matching is a filter,
   not a lookup, so a verifier that returns two verdicts for one id contributes two votes to that
   finding rather than silently dropping one.
2. **Fewer verdicts than findings.** A finding whose id drew no verdict gets
   `state: 'unconfirmed'` with `why: 'no verdict returned'`. It is not `refuted`: the verifier
   failed to answer, which says nothing about the finding, and burying an unanswered high-severity
   claim in `refuted` is the worst of the three outcomes. The finding still reaches the report, in
   the same bucket as a finding below the threshold.
3. **The majority rule at `critical`.** Three lenses per dimension, aggregated per finding with
   `kept * 2 > mine.length`, the same form as `workflows/verify.js:110`. The lenses are the three
   `verify.js` names: does this actually reproduce, is the reasoning sound, is the fix implied by it
   correct. With `ONE_LENS` the same expression reduces to a single vote deciding, so the lower
   levels need no separate branch. The three prompts for one dimension differ only in the lens
   string, which is AC6.
4. **No verifier for an empty dimension.** The `eligible.length === 0` early return covers both a
   reviewer that raised nothing and a reviewer whose findings all sit below the threshold, which is
   AC9.

- [ ] **Step 5: Pass the level's effort to the reviewers**

In the first pipeline stage, change `effort: 'high'` (line 60) to `effort: L.effort`, and change the
`DIMENSIONS` argument of `pipeline` (line 55) to `dims`. Nothing else in the stage changes.

**The pipeline stays a pipeline.** The comment at 52-53 says a dimension's findings go to
confirmation the moment that dimension finishes, and batching is per dimension, so the property
holds unchanged: the batch is one dimension's findings, never a join across dimensions, and no
barrier is introduced. Leave the comment as written; it is still true. Batching only replaces the
inner `parallel` over findings with a `parallel` over lenses.

**Check:** `node --check workflows/review.js`, and confirm by reading the file that the second stage
contains no `r.findings.map` over `agent`.

---

### Task 3: The returned object

**Files:**
- Modify: `workflows/review.js` (lines 74-84)

- [ ] **Step 6: Group by state and omit `confirmed` when nothing is confirmable**

Replace lines 74-84 with:

```js
const all = results.flat().filter(Boolean)
const rank = { high: 0, medium: 1, low: 2 }
const bySeverity = (a, b) => rank[a.severity] - rank[b.severity]
const inState = s => all.filter(f => f.state === s)

const out = {
  target,
  level,
  reviewed: dims.map(d => d.key),
  raised: all.length,
  unconfirmed: inState('unconfirmed').sort(bySeverity),
}

if (L.confirm.length > 0) {
  out.confirmed = inState('confirmed').sort(bySeverity)
  out.refuted = inState('refuted').map(f => ({ file: f.file, line: f.line, summary: f.summary, why: f.why }))
}

return out
```

AC2 needs `confirmed` absent at `low`, and the single `if` is the whole special case: at `low`,
`L.confirm` is empty, so neither `confirmed` nor `refuted` is ever populated and neither key is set.
The `state` field on each finding does the sorting work, so no branch reaches back into the confirm
stage. AC12's `level` and `reviewed` come from the resolved level and `dims`, which is exactly the
set that ran.

**Check:** read the return block and confirm `confirmed` is assigned in one place only.

---

### Task 4: The `meta` block

**Files:**
- Modify: `workflows/review.js` (lines 1-9)

- [ ] **Step 7: Replace the `meta` block**

`meta` feeds the skill listing, and its current wording promises every dimension and per-finding
confirmation. Replace lines 1-9 with:

```js
export const meta = {
  name: 'review',
  description: 'Review a changeset at one of four levels, then confirm the findings that level asks about',
  whenToUse: 'The review phase of the review flow, and a fresh-eyes pass before a merge',
  phases: [
    { title: 'Review', detail: 'one reviewer per dimension the level selects, in parallel' },
    { title: 'Confirm', detail: 'one verifier per dimension, judging that dimension eligible findings together' },
  ],
}
```

The `Confirm` detail avoids an apostrophe inside the single-quoted string. If the build prefers the
possessive, use a double-quoted string for that value: `"judging that dimension's eligible findings
together"`.

**Check:** `bash scripts/check-flows.sh` passes, and the level names in `description` match the four
keys in `LEVELS`.

---

### Task 5: The prose docs

**Files:**
- Modify: `CHANGELOG.md` (a new section above `## 1.10.0`)
- Read and decide: `README.md` (lines 112 and 187-193)

- [ ] **Step 8: The CHANGELOG entry**

Add a new version section above the `## 1.10.0 — 2026-08-03` heading, headed `## 1.11.0 —
2026-08-03`. A new `level` argument is a feature, not a fix, so this is a minor bump per
`commands/release.md:16-17`, dated the way every other heading in the file is.
`.claude-plugin/plugin.json` is out of scope here, so the changelog names a version the manifest
does not carry until `/release` bumps it.

What the entry states, under a `New:` list, in the user's terms and not the diff's:

- `review` now runs at one of four levels: `low`, `mid`, `high`, or `critical`. Each picks a
  smaller dimension set and less effort; `high` is the default and matches today's behavior.
- Verifying findings no longer scales with how many were raised: one verifier per dimension, and
  three at `critical`, one per refutation lens. A worst-case run is now capped at 2, 8, 14, or 28
  agents, down from unbounded.
- Findings below a level's threshold are still reported, marked unconfirmed, instead of dropped.

Keep the arithmetic to the four ceilings in the spec's agent-count table. Do not restate the level
table in prose; `.polaris/specs/review-levels.md` and `LEVELS` hold it.

- [ ] **Step 9: The README lines**

Read `README.md:112` and `187-193` and confirm what they describe. Both are about `/review-pr`, a
prose-driven command the spec's non-goals keep level-free, and neither mentions `workflow:review`.
The README documents no workflow anywhere, so there is no line to add the argument to. Make no
README edit and record that here. This is the one place the spec's stale-docs table points at
something that turned out not to be stale; see the note at the end of this plan.

**Check:** `bash scripts/check-patterns.sh prose CHANGELOG.md` reports no findings.

---

### Task 6: Acceptance run

- [ ] **Step 10: Run each level and read the log and the returned object**

The spec names two existing seams and no new test script. Run `workflow:review` four times against a
small real changeset and check:

| Run | Read | Passes |
|---|---|---|
| `level: 'low'` | the run log, then the returned object | AC1, AC2 |
| `level: 'mid'` | reviewer labels and `effort`, then `unconfirmed` | AC3, AC4 |
| `level: 'high'` | verifier count per dimension, then `unconfirmed` | AC5, AC9 |
| `level: 'critical'` | the three prompts for one dimension, then `refuted` | AC6, AC7 |
| no `level` key | reviewer count and `effort` | AC10 |
| `level: 'LOW'` | the log line | AC11 |

AC8 and AC12 are read on every run: one reviewer labelled `review:over-engineering`, and `level`
plus `reviewed` on the returned object. A `critical` run needs a dimension where two of three lenses
refute one finding, so pick a changeset with at least one weak finding rather than hoping for one.

- [ ] **Step 11: Commit**

```bash
git add workflows/review.js CHANGELOG.md .polaris/specs/review-levels.md
git commit -m "feat: give review four levels and a batched confirm stage"
```

---

## Self-Review

- **Spec coverage:** AC1 and AC2 from Step 1's empty `confirm` list plus Step 6's single `if`. AC3
  from Step 5. AC4, AC5, and AC9 from Step 4's threshold filter and early return. AC6 and AC7 from
  Step 4's lens list and majority. AC8 from the constraint that every level's `keys` includes
  `over-engineering`. AC10 and AC11 from Step 2. AC12 from Step 6.
- **Placeholder scan:** none. Every literal in Steps 1, 3, 4, 6, and 7 is final text.
- **Type consistency:** `LEVELS[].keys` are `DIMENSIONS[].key` values, `LEVELS[].confirm` holds the
  same `high | medium | low` enum as the `FINDINGS` severity, and `VERDICTS.verdicts[].id` is an
  integer index into the eligible list. No `severity` schema change.
- **Diff size:** roughly 40 lines net in one file. `DIMENSIONS`, `FINDINGS`, `target`, `rank`, and
  both existing comments survive untouched.

## Where the spec did not hold

`README.md:112` and `187-193` are listed as going stale, with the instruction to add the level
argument where the command is listed. Those lines describe `/review-pr`, which the same spec's
non-goals keep level-free, and the README documents no workflow at all, so `workflow:review` has no
README line to update. Step 9 makes no edit. Everything else in the spec is implementable as
written.
