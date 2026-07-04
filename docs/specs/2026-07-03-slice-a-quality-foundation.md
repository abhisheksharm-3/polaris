# Slice A: Quality Foundation — Design Spec

Date: 2026-07-03. Status: design, pending user review.
Parent: `docs/POLARIS_MASTER_PLAN.md`.

Slice A turns Polaris's scattered, stack-locked, advisory rules into one canonical quality
standard that everything else references. It is the bedrock for subsystems B, C, and D.

---

## 1. Problem

The current quality rules have three defects:

1. **Scattered.** The same rules live in `rules/general.md`, `rules/no-ai-slop.md`, and
   duplicated inside `agents/code-cleanup.md` and `agents/slop-remover.md` (those two overlap
   ~80%).
2. **Falsely universal.** `general.md` calls itself "Universal" but is TypeScript/Next-locked.
   `audit-refactor.md` opens with "You are a Next.js Codebase Auditor." Neither serves the
   backend and Python agents the wider vision needs.
3. **No teeth.** Rules are injected as advice at session start. Nothing verifies that emitted
   code or prose actually meets them, yet the vision requires that every line, including
   commit messages and PR text, passes.

---

## 2. Goal

One canonical standard, one engine that enforces it, three ways to apply it. Changing a rule
once changes it everywhere. The standard is stack-aware by routing to the host skill library,
not by hand-authoring a module per language.

### Success criteria

- A single standard exists as `rules/core.md`, `rules/writing.md`, `rules/stacks/` (overlays
  only), and `rules/patterns.json`. No rule is duplicated across files.
- A setup interview writes a per-project `.polaris/config.json` capturing the configurable
  choices (dead code, backward compat, architecture, naming, PR standards) plus a one-step auto
  mode. The gate, hooks, and agents read it and adjust behavior accordingly.
- `skills/quality-gate/` runs check and fix, is stack-aware, runs a mechanical pass and a
  judgment pass, and reports pass/fail with `file:line` findings and fixes.
- Hooks: `session-start` loads core + writing + detected overlays only; `guard-commit-pr`
  blocks writing-standard violations in commits and PRs; `guard-edit` surfaces violations on
  edit (opt-in).
- `agents/code-cleanup.md` (merged) and `agents/audit-refactor.md` (evolved) are stack-aware
  and delegate checking to the gate.
- Running the gate on a real repo (`sage-frontend`) produces correct findings. This doubles as
  the validation pass for any backend overlays.

---

## 3. Architecture

### 3.1 File layout

```
rules/
  core.md              language-agnostic engineering principles + docs protocol +
                       Karpathy mode-dependent rules
  writing.md           the one prose standard (comments, commits, PR text, docs);
                       merges no-ai-slop.md with the blog-writer guardrails
  stack-map.json       technology -> host skill(s) + doc entry point + overlay path
  patterns.json        machine-readable banned words and per-stack forbidden tokens;
                       feeds the mechanical check pass and the hooks
  stacks/
    typescript.md      Polaris overlay: types-in-types-file, no-barrel, no as-any...
    react.md           Polaris overlay: client/server boundary, frontend anti-patterns
    nextjs.md          Polaris overlay: App Router, Server Action safety, caching
                       (more overlays added only when Polaris has an opinion to add)

skills/
  quality-gate/
    SKILL.md           the check + fix engine

output-styles/
  polaris-writing.md   enforces the anti-slop writing standard at the system-prompt level
                       (force-for-plugin: true so it applies whenever Polaris is enabled)

lspServers (optional) typescript / pyright / rust-analyzer, to feed the gate real
                       language-server diagnostics instead of only regex + judgment
                       (binaries installed separately; declared in .lsp.json)

agents/
  code-cleanup.md      merged from code-cleanup + slop-remover; stack-aware; calls the gate
  audit-refactor.md    evolved: stack-aware, reads the standard

hooks/
  session-start        evolved: inject core + writing + detected overlays only
  guard-commit-pr      PreToolUse(Bash): block bad commit / PR messages
  guard-edit           PostToolUse(Edit|Write): surface violations (opt-in)
  hooks.json           register the new hooks

commands/
  gate.md              thin /gate wrapper over the quality-gate skill
  init.md              evolved: runs the setup interview, writes .polaris/config.json

templates/
  config.default.json  default project config; copied and edited during setup

companions.json        manifest of companion plugins and skills to auto-install

scripts/
  check-patterns.sh    shared deterministic checker; reads patterns.json;
                       used by the gate mechanical pass and by the hooks
  ensure-companions.sh idempotent installer; reads companions.json, installs missing
```

The setup interview writes `.polaris/config.json` into the target project (committed there,
not into the Polaris plugin repo). The plugin ships the default template and schema.

Retired: `rules/general.md` and `rules/no-ai-slop.md` are decomposed into the above. Deleted:
`agents/slop-remover.md` (absorbed into `code-cleanup.md`, triggers preserved).

### 3.2 Single-source principle

Two representations of the standard, one source each:

- **Prose for judgment.** `core.md`, `writing.md`, and the overlays. The model reads these.
- **Data for machines.** `patterns.json`. Deterministic checks and hooks read this. A banned
  word added here is enforced by the gate and by the commit hook at once.

Nothing is stated in both a way that could drift. `patterns.json` holds only what a regex can
decide; everything requiring judgment lives in prose.

### 3.3 Two enforcement surfaces the docs confirmed

Beyond the gate and hooks, two real Claude Code primitives strengthen enforcement:

- **Output style for the writing standard.** An output style modifies the system prompt for the
  whole session. Polaris ships `output-styles/polaris-writing.md` with `force-for-plugin: true`
  so the anti-slop writing standard applies automatically whenever Polaris is enabled, with
  `keep-coding-instructions: true` so normal engineering behavior stays. This makes the writing
  bar the default voice, not just a post-hoc check.
- **LSP diagnostics for the gate (optional).** Plugins can ship LSP servers (typescript, pyright,
  rust-analyzer). When present, the gate's mechanical pass reads real language-server diagnostics
  instead of relying only on regex and model judgment. The language-server binaries install
  separately, so this is optional and degrades gracefully to the regex + judgment passes.

---

## 3.5 Layer 0: project config and setup

The standard has a fixed part (the same everywhere) and a configurable part (a per-project
choice). Layer 0 captures the configurable part so the other layers can read it.

### 3.5.1 The setup interview

Runs from the evolved `init` command, or automatically the first time Polaris runs in a
project with no `.polaris/config.json`. It uses the AskUserQuestion flow to ask:

1. **Dead code** — delete on sight / flag for review / keep.
2. **Backward compatibility** — none (zero users, change freely) / maintain.
3. **Architecture and structure** — describe in words / mirror a GitHub repo / mirror a local
   project / let Polaris decide.
4. **Naming standards** — Polaris defaults / your own rules / infer from the reference.
5. **PR and commit standards** — your conventions / Polaris defaults.

Plus **one-step (auto) mode**: skip the questions, let Polaris choose defaults and infer the
rest from the existing code. Sensible defaults: dead code = delete for greenfield, backward
compat = none if no release tags or published package is detected else maintain, naming =
Polaris defaults, architecture = inferred from the existing tree.

When the user points at a **reference project** (GitHub URL or local path), Polaris reads it,
infers its directory structure and naming conventions, and writes them into the config as the
architecture and naming rules to mirror. For GitHub, fetch the tree; for local, read the path.

### 3.5.2 `.polaris/config.json`

Written into the target project and committed there. Shape:

```
{
  "mode": "custom" | "auto",
  "deadCode": "delete" | "flag" | "keep",
  "backwardCompat": "none" | "maintain",
  "architecture": {
    "source": "describe" | "github" | "local" | "polaris",
    "reference": "<url | path | null>",
    "conventions": "<inferred or described structure notes>"
  },
  "naming": { "source": "polaris" | "custom" | "inferred", "rules": { } },
  "pr": { "source": "custom" | "polaris", "standards": "<notes>" }
}
```

### 3.5.3 How the config changes behavior

Every layer reads it and adjusts:

- `backwardCompat: "maintain"` — the gate and agents stop flagging compat shims and aliases.
- `deadCode: "keep"` — orphan and dead-code findings become notes, not failures. `"flag"` —
  reported but not auto-fixed.
- `architecture` / `naming` — the gate's judgment pass and the agents check against these rules
  (or the mirrored reference) instead of the Polaris defaults.
- `pr` — the shipper and the commit hook use these standards (relevant from subsystem D on).

The fixed bar (simplicity, root-cause fixes, the prose standard, boundary security) is never
configurable and always enforced.

---

## 4. Layer 1: the canonical standard

### 4.1 `core.md`

Language-agnostic engineering principles (moved out of general.md and de-duplicated):

- The code bar from the master plan §2.1 (simple first, root cause not symptom,
  self-explanatory, secure and performant, no workarounds).
- One file one responsibility; no duplicate code; comments are WHY only.
- The Karpathy mode-dependent rule (surgical during features, aggressive during cleanup).
- Dead-code and backward-compatibility policy are read from `.polaris/config.json`, not
  hardcoded. The old "zero users, no backwards compat, delete on sight" dogma from
  `general.md` becomes the greenfield default, overridable per project.
- **The docs protocol** (the resolution order): detect version, load the host skill (install
  if missing), then fetch fresh docs in order llms.txt / llms-full.txt, then version-specific
  official docs, then targeted search. Never rely on training data for version-specific APIs.

### 4.2 `writing.md`

The single prose standard, merging `no-ai-slop.md` with the blog-writer guardrails the user
supplied. Contents:

- Banned vocabulary with concrete replacements.
- Banned sentence structures (not-only-but-also, importance preamble, rule-of-three padding,
  serves-as instead of is, challenges-and-future closer).
- Banned analytical moves (vague attribution, significance inflation, unsupported debate).
- Formatting bans (title case headings, bold-everything, em-dash spray, thematic-break spam).
- The positive rule: every paragraph contains at least one thing specific enough to be wrong
  (a number, a named thing, a concrete outcome).
- The scope line: this applies to code comments, commit messages, PR titles and bodies, and
  all docs, no exception.

The session hook that fetched the live Wikipedia signs-of-AI-writing article is kept as an
optional refresh, not a hard dependency.

### 4.3 `stack-map.json`

Maps a detected technology to its resources:

```
{
  "nextjs":  { "skills": ["nextjs-react-typescript", "optimized-nextjs-typescript"],
               "docs": "https://nextjs.org/docs", "overlay": "stacks/nextjs.md" },
  "fastapi": { "skills": ["fastapi-python"],
               "docs": "https://fastapi.tiangolo.com", "overlay": null },
  "go":      { "skills": ["go", "go-api-development"],
               "docs": "https://go.dev/doc", "overlay": null }
}
```

Detection to key: the session-start detector already knows nextjs/react/python/rust/go; extend
it to emit keys this map understands. Unmapped technologies fall back to docs-only.

### 4.4 `patterns.json`

Machine-readable, per-scope and per-stack:

```
{
  "prose": {
    "banned_words": ["delve", "tapestry", "pivotal", ...],
    "banned_regex": ["\\bnot only\\b.*\\bbut also\\b", " — .* — "]
  },
  "code": {
    "any":   { "regex": "\\bas any\\b", "stacks": ["typescript"] },
    "tsignore": { "regex": "@ts-(ignore|expect-error)", "stacks": ["typescript"] },
    "console": { "regex": "console\\.(log|debug)", "stacks": ["typescript","react"] },
    "todo":  { "regex": "//\\s*(TODO|FIXME)", "stacks": ["*"] },
    "barrel": { "filename": "index.ts", "check": "reexport", "stacks": ["typescript"] }
  }
}
```

Exact schema is finalized during implementation; this is the shape.

---

## 5. Layer 2: the `quality-gate` skill

The engine. The mega-flow and every agent will lean on this, so it is the highest-value piece.

**Inputs.** A git diff (default), explicit paths, or "the code just written."

**Steps.**
1. Resolve the changeset's files. Detect the stacks present. Load `.polaris/config.json` (fall
   back to the greenfield defaults if absent).
2. Load resources per `stack-map.json`: host skills (install missing), fresh docs per the docs
   protocol, Polaris overlays, and the relevant slices of `patterns.json`. Apply the config
   (§3.5.3) to decide which checks are active and what architecture and naming rules apply.
3. **Mechanical pass.** Run `scripts/check-patterns.sh` over the changeset. Fast, deterministic,
   high confidence. Catches banned words, `as any`, `@ts-ignore`, `console.log`, TODO, barrels,
   em-dash spray in prose.
4. **Judgment pass.** The model reads the diff against `core.md`, `writing.md`, and the loaded
   overlays and skill guidance. Catches root-cause-vs-symptom, single responsibility, defensive
   checks in trusted paths, naming, architecture leaks.
5. Emit findings.

**Output.** Pass or fail, plus findings: severity, `file:line`, the rule, the fix.

**Modes.**
- `--check` (default): report only.
- `--fix`: apply fixes, then re-run to confirm green.
- `--scope code|writing|both` (default both).

**Interface.** Exposed as a skill (so agents and the flow can invoke it) and as `/gate` (a thin
command wrapper for humans).

---

## 6. Layer 3: the hooks

### 6.1 `guard-commit-pr` (PreToolUse on Bash)

When the intercepted command is `git commit -m ...` or `gh pr create ...`, extract the message
and run the prose slice of `scripts/check-patterns.sh`. On a violation (banned word, em-dash
spray, banned structure), block with the reason and the offending token. This is the "every
commit and PR passes" rule made real. Covers the `-m` and `--body`/`--title` forms, which is
how Claude writes them in practice.

### 6.2 `guard-edit` (PostToolUse on Edit|Write)

After an edit, run the mechanical pass on the changed file and surface findings as a reminder.
Off by default, enabled per project by a config flag. Non-blocking, because auto-blocking every
edit is noisy. It may graduate to blocking after it proves itself.

### 6.3 `session-start` (evolved)

Stop injecting everything. Always load `core.md` and `writing.md` (small). Detect stacks and
load only their overlays. Keeps context lean as the standard grows.

Companion install uses two mechanisms (master plan §4.2, grounded in the real plugin docs):

- **Marketplace plugins** (superpowers, frontend-design, karpathy) are declared as native plugin
  `dependencies` in `.claude-plugin/plugin.json` and resolved automatically on install. Because
  they live in other marketplaces, `marketplace.json` lists them under
  `allowCrossMarketplaceDependenciesOn`.
- **The loose skill bulk** (`Mindrally/skills` and registry-resolved skills) is not a plugin, so
  on first run `ensure-companions.sh` (idempotent, re-runnable from `init`) syncs the ones listed
  in `companions.json` into `~/.claude/skills/`, then no-ops. This replaces the current behavior
  that only warns when superpowers is absent.

---

## 7. The agents

### 7.1 `code-cleanup` (merged)

Absorbs `slop-remover` entirely. Keeps every slop-remover trigger phrase ("remove AI slop from
this PR", "remove AI code slop") and its extra category (inline-lambda extraction). Becomes
stack-aware. Stops carrying its own copy of the rules; instead it invokes the gate in `--fix`
mode and reports what changed. `agents/slop-remover.md` is deleted.

### 7.2 `audit-refactor` (evolved)

Its four-category structure (security, performance, architecture, structure) and its
read-only-then-approve-then-refactor flow stay. It stops being Next-specific: the checks come
from the loaded stack overlays and skills, so it audits a Go or Python repo too. It reads the
one standard rather than restating it.

---

## 8. Testing

- **Mechanical layer and hooks.** Fixture files under a test dir: a sample with `as any`, a
  commit message containing "delve", a prose block with em-dash spray. A small shell test runs
  `check-patterns.sh` and asserts the expected hits. Deterministic.
- **`guard-commit-pr`.** Feed good and bad sample messages to the hook script; assert block
  versus allow.
- **Gate skill and agents (judgment).** Run against `sage-frontend` and review findings by
  hand. This is also the validation pass for any backend overlay before it is trusted.

---

## 9. Migration and ordering

1. Write `core.md`, `writing.md`, `patterns.json`, `stack-map.json` from the existing content.
2. Write the config schema and `templates/config.default.json`; write `companions.json` and
   `scripts/ensure-companions.sh`.
3. Write `scripts/check-patterns.sh` and its fixtures and tests.
4. Build `skills/quality-gate/` on top of the standard, the config, and the script.
5. Add `/gate`. Evolve `init` to run the setup interview and write `.polaris/config.json`.
6. Evolve `session-start`; add `guard-commit-pr` and `guard-edit`; update `hooks.json`.
7. Merge `code-cleanup`, delete `slop-remover`, evolve `audit-refactor`.
8. Retire `general.md` and `no-ai-slop.md`.
9. Validate on `sage-frontend` (run setup, then the gate).
10. Bump plugin version; update README.

---

## 10. Out of scope for Slice A

- The agent fleet (B), handoff and audit docs (C), orchestration flow (D), memory (E), prompt
  enhancing (F).
- Deep backend overlays. Backend stacks are served by the companion skills plus fresh docs
  until a live project justifies a Polaris overlay.
