# Slice A: Quality Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Polaris's scattered, stack-locked, advisory rules into one canonical quality standard with a callable gate, opt-in enforcement hooks, per-project config, and native companion install.

**Architecture:** One standard split into prose (markdown the model reads) and data (`patterns.json` the scripts and hooks read). A `quality-gate` skill runs a deterministic pass (a shell checker over `patterns.json`) plus a judgment pass. Hooks apply the same data at commit/PR and edit time. An output style makes the writing standard the default voice. The two quality agents merge to two and delegate checking to the gate.

**Tech Stack:** Claude Code plugin (markdown agents/skills/commands, `hooks.json`, `plugin.json`), Bash + `jq` for the deterministic checker and hooks, JSON for `patterns.json` / `stack-map.json` / `companions.json` / config.

## Global Constraints

- All authored prose (this plan's output files, comments, commit messages) must pass the anti-slop writing standard: no banned vocabulary, no "not only X but Y", no em-dash spray, no rule-of-three padding. Verbatim source: `rules/no-ai-slop.md` (current repo) plus the blog-writer guardrails in `docs/POLARIS_MASTER_PLAN.md`.
- The deterministic checker and hooks require `jq`. Each script checks for `jq` and exits with a clear message if absent.
- Plugin-shipped agents support only these frontmatter fields: `name`, `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation` (only `"worktree"`). Never use `hooks`, `mcpServers`, or `permissionMode` in a plugin agent.
- The checker never scans `rules/` or `patterns.json` for banned words: those files contain the banned words as data and would false-positive.
- Scripts reference the plugin root via `${CLAUDE_PLUGIN_ROOT}` and the project via `${CLAUDE_PROJECT_DIR}` / `${PWD}`, never hardcoded paths.
- Model routing: no model field needed on Slice A agents unless a task says so; the routing policy lands with Subsystem B.
- Source of truth for scope: `docs/specs/2026-07-03-slice-a-quality-foundation.md`.

---

### Task 1: Machine-readable patterns and the deterministic checker

**Files:**
- Create: `rules/patterns.json`
- Create: `scripts/check-patterns.sh`
- Create: `tests/fixtures/bad-prose.md`, `tests/fixtures/bad-ts.ts`, `tests/fixtures/clean.ts`, `tests/fixtures/clean-prose.md`
- Create: `tests/run-tests.sh`

**Interfaces:**
- Produces: `scripts/check-patterns.sh <scope> <file...>` where `scope` is `prose` | `code` | `both`. Exit `0` = clean, exit `1` = violations found. Prints one line per finding: `<file>:<line>: <rule-id>: <message>`. Reads rule data from `${CLAUDE_PLUGIN_ROOT}/rules/patterns.json` (falls back to a path relative to the script when `CLAUDE_PLUGIN_ROOT` is unset, for tests).
- Produces: `tests/run-tests.sh` runs the fixture suite and exits non-zero on any failure.

- [ ] **Step 1: Write `patterns.json` with a small real rule set**

```json
{
  "prose": {
    "banned_words": ["delve", "tapestry", "pivotal", "underscore", "testament", "vibrant", "showcase", "seamless", "leverage", "intricate", "robust", "nestled", "boasts", "groundbreaking"],
    "banned_regex": [
      { "id": "not-only-but", "pattern": "not only .* but( also)?", "message": "banned structure: not only X but Y" },
      { "id": "em-dash-spray", "pattern": " — .* — ", "message": "em-dash spray; use commas or periods" }
    ]
  },
  "code": {
    "ts": [
      { "id": "as-any", "pattern": "\\bas any\\b", "message": "no as any; use a proper type" },
      { "id": "ts-ignore", "pattern": "@ts-(ignore|expect-error)", "message": "no ts-ignore without a documented framework bug" },
      { "id": "console", "pattern": "console\\.(log|debug)", "message": "remove debug logging" },
      { "id": "todo", "pattern": "//\\s*(TODO|FIXME)", "message": "no deferred TODO/FIXME" }
    ]
  }
}
```

- [ ] **Step 2: Write the fixtures**

`tests/fixtures/bad-prose.md`:
```markdown
This section will delve into the topic. It is not only fast but also cheap.
```

`tests/fixtures/bad-ts.ts`:
```typescript
const x = foo() as any;
console.log(x); // TODO: fix
```

`tests/fixtures/clean.ts`:
```typescript
export function add(a: number, b: number): number {
  return a + b;
}
```

`tests/fixtures/clean-prose.md`:
```markdown
This section explains the checker. It is fast and cheap.
```

- [ ] **Step 3: Write the failing test harness**

`tests/run-tests.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK="${DIR}/../scripts/check-patterns.sh"
fail=0

expect_exit() {
  local want="$1"; shift
  "$@" >/dev/null 2>&1
  local got=$?
  if [ "$got" != "$want" ]; then echo "FAIL: want exit $want got $got: $*"; fail=1;
  else echo "ok: $*"; fi
}

# prose: bad flagged, clean passes
expect_exit 1 "$CHECK" prose "${DIR}/fixtures/bad-prose.md"
expect_exit 0 "$CHECK" prose "${DIR}/fixtures/clean-prose.md"
# code: bad flagged, clean passes
expect_exit 1 "$CHECK" code "${DIR}/fixtures/bad-ts.ts"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/clean.ts"

exit $fail
```

- [ ] **Step 4: Run the harness to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL (check-patterns.sh does not exist yet)

- [ ] **Step 5: Implement `scripts/check-patterns.sh`**

```bash
#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "check-patterns: jq is required" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
PATTERNS="${ROOT}/rules/patterns.json"
[ -f "$PATTERNS" ] || { echo "check-patterns: patterns.json not found at $PATTERNS" >&2; exit 2; }

scope="${1:-both}"; shift || true
found=0

scan_prose() {
  local file="$1"
  case "$file" in */rules/*|*patterns.json) return 0;; esac
  while IFS= read -r word; do
    grep -niwE "$word" "$file" 2>/dev/null | while IFS=: read -r ln _; do
      echo "$file:$ln: banned-word: '$word'"
    done
  done < <(jq -r '.prose.banned_words[]' "$PATTERNS")
  jq -c '.prose.banned_regex[]' "$PATTERNS" | while read -r rule; do
    pat=$(echo "$rule" | jq -r '.pattern'); id=$(echo "$rule" | jq -r '.id'); msg=$(echo "$rule" | jq -r '.message')
    grep -nEi "$pat" "$file" 2>/dev/null | while IFS=: read -r ln _; do echo "$file:$ln: $id: $msg"; done
  done
}

scan_code() {
  local file="$1"
  jq -c '.code.ts[]' "$PATTERNS" | while read -r rule; do
    pat=$(echo "$rule" | jq -r '.pattern'); id=$(echo "$rule" | jq -r '.id'); msg=$(echo "$rule" | jq -r '.message')
    grep -nE "$pat" "$file" 2>/dev/null | while IFS=: read -r ln _; do echo "$file:$ln: $id: $msg"; done
  done
}

for file in "$@"; do
  [ -f "$file" ] || continue
  out=""
  case "$scope" in
    prose) out="$(scan_prose "$file")";;
    code)  out="$(scan_code "$file")";;
    both)  out="$(scan_prose "$file"; scan_code "$file")";;
  esac
  if [ -n "$out" ]; then echo "$out"; found=1; fi
done

exit $found
```

Make executable: `chmod +x scripts/check-patterns.sh tests/run-tests.sh`

- [ ] **Step 6: Run the harness to verify it passes**

Run: `bash tests/run-tests.sh`
Expected: all `ok:` lines, exit 0

- [ ] **Step 7: Commit**

```bash
git add rules/patterns.json scripts/check-patterns.sh tests/
git commit -m "feat: machine-readable patterns and deterministic checker with fixtures"
```

---

### Task 2: The canonical standard (core.md + writing.md)

**Files:**
- Create: `rules/core.md`
- Create: `rules/writing.md`

**Interfaces:**
- Produces: `rules/core.md` and `rules/writing.md`, the prose half of the standard, read by the gate, the hooks' context, and the agents.

- [ ] **Step 1: Author `rules/core.md`**

Assemble from existing content, no new invention:
- The language-agnostic parts of the current `rules/general.md`: Philosophy (drop the hardcoded "zero users / no backwards compat / delete on sight" absolute — that becomes config, see Task 6), Implementation Standards (No Workarounds, One File One Responsibility, No Orphan Code, No Duplicate Code, Comments Policy).
- The docs protocol verbatim from `docs/POLARIS_MASTER_PLAN.md` §4.1 (detect version, then llms.txt / llms-full.txt, then version docs, then search; never training data).
- The Karpathy mode-dependent rule verbatim from master plan §2.3 (surgical during features, aggressive during cleanup).
- A one-line pointer: dead-code and backward-compat policy are read from `.polaris/config.json`, greenfield defaults.

Do NOT include TypeScript/React/Next specifics (those move to Task 3).

- [ ] **Step 2: Author `rules/writing.md`**

Merge the current `rules/no-ai-slop.md` with the blog-writer guardrails captured in master plan §2.2 and the original request. Required sections: Banned vocabulary (with replacements), Banned sentence structures, Banned analytical moves, Forbidden formatting habits, the positive rule ("every paragraph contains one thing specific enough to be wrong"), and the scope line (applies to comments, commit messages, PR titles/bodies, docs, marketing copy). Keep the banned-word list in sync with `rules/patterns.json` from Task 1.

- [ ] **Step 3: Validate consistency**

Run: `comm -13 <(jq -r '.prose.banned_words[]' rules/patterns.json | sort -u) <(grep -oiE '\b(delve|tapestry|pivotal|underscore|testament|vibrant|showcase|seamless|leverage|intricate|robust|nestled|boasts|groundbreaking)\b' rules/writing.md | tr 'A-Z' 'a-z' | sort -u)`
Expected: every word in `patterns.json` appears in `writing.md` (manual scan; the command lists words in patterns.json not found in writing.md — should be empty). Fix any gap.

- [ ] **Step 4: Verify the checker skips the standard**

Run: `bash scripts/check-patterns.sh prose rules/writing.md`
Expected: exit 0 (the checker excludes `rules/`, so listing banned words as data does not self-flag)

- [ ] **Step 5: Commit**

```bash
git add rules/core.md rules/writing.md
git commit -m "feat: canonical standard core.md and merged writing.md"
```

---

### Task 3: Stack overlays and stack-map

**Files:**
- Create: `rules/stacks/typescript.md`, `rules/stacks/react.md`, `rules/stacks/nextjs.md`
- Create: `rules/stack-map.json`

**Interfaces:**
- Produces: overlays with Polaris opinions per stack; `stack-map.json` mapping a detected key to `{ skills, docs, overlay }`, consumed by the gate (Task 5) and session-start (Task 7).

- [ ] **Step 1: Author `rules/stacks/typescript.md`**

Move the TypeScript-specific opinions out of the current `rules/general.md`: Types-Live-Only-In-Type-Files, No Barrel Exports, Extract Complex Inline Types, No Inline Async Imports, the TypeScript naming table. These are Polaris opinions the generic skill lacks.

- [ ] **Step 2: Author `rules/stacks/react.md` and `rules/stacks/nextjs.md`**

`react.md`: the Frontend Design Baseline and Anti-Patterns from `general.md` (typography, color/layout, animation performance, anti-patterns), plus client/server-boundary opinions. `nextjs.md`: App Router, Server Action safety, caching, and image opinions drawn from the current `agents/audit-refactor.md` Next.js checks.

- [ ] **Step 3: Write `rules/stack-map.json`**

```json
{
  "nextjs":     { "skills": ["nextjs-react-typescript", "optimized-nextjs-typescript"], "docs": "https://nextjs.org/docs", "overlay": "stacks/nextjs.md" },
  "react":      { "skills": ["react"], "docs": "https://react.dev", "overlay": "stacks/react.md" },
  "typescript": { "skills": ["typescript"], "docs": "https://www.typescriptlang.org/docs/", "overlay": "stacks/typescript.md" },
  "python":     { "skills": ["python"], "docs": "https://docs.python.org/3/", "overlay": null },
  "go":         { "skills": ["go", "go-api-development"], "docs": "https://go.dev/doc", "overlay": null },
  "rust":       { "skills": ["rust"], "docs": "https://doc.rust-lang.org/", "overlay": null }
}
```

- [ ] **Step 4: Validate JSON**

Run: `jq . rules/stack-map.json >/dev/null && echo ok`
Expected: `ok`

- [ ] **Step 5: Commit**

```bash
git add rules/stacks/ rules/stack-map.json
git commit -m "feat: stack overlays (ts/react/nextjs) and stack-map"
```

---

### Task 4: The writing output style

**Files:**
- Create: `output-styles/polaris-writing.md`

**Interfaces:**
- Produces: an output style that applies the writing standard at the system-prompt level whenever Polaris is enabled.

- [ ] **Step 1: Author the output style**

```markdown
---
name: Polaris writing
description: Enforces the Polaris anti-slop writing standard on all prose output
keep-coding-instructions: true
force-for-plugin: true
---

Every line of natural language you emit (code comments, commit messages, PR titles and bodies, docs) must pass the Polaris writing standard.

[Then a condensed form of rules/writing.md: the banned vocabulary, the banned structures, the formatting bans, and the positive rule. Keep it tight; the full standard lives in rules/writing.md.]
```

- [ ] **Step 2: Verify frontmatter validity**

Run: `head -6 output-styles/polaris-writing.md`
Expected: frontmatter shows `keep-coding-instructions: true` and `force-for-plugin: true`

- [ ] **Step 3: Commit**

```bash
git add output-styles/polaris-writing.md
git commit -m "feat: polaris-writing output style (force-for-plugin)"
```

---

### Task 5: The quality-gate skill and /gate command

**Files:**
- Create: `skills/quality-gate/SKILL.md`
- Create: `commands/gate.md`

**Interfaces:**
- Consumes: `scripts/check-patterns.sh` (Task 1), the standard (Tasks 2-3), `.polaris/config.json` (Task 6, optional at read time).
- Produces: an invocable skill that reports pass/fail plus findings, with modes `--check` (default), `--fix`, `--scope code|writing|both`; and `/gate` as a thin wrapper.

- [ ] **Step 1: Author `skills/quality-gate/SKILL.md`**

Frontmatter: `name: quality-gate`, a `description` covering "check, gate, verify code quality, remove slop, quality pass". Body follows the spec §5:
1. Resolve the changeset (git diff, explicit paths, or "just-written"). Detect stacks. Load `.polaris/config.json` (greenfield defaults if absent).
2. Load resources per `stack-map.json`: host skills, fresh docs (docs protocol), overlays, and the `patterns.json` slice.
3. Mechanical pass: run `scripts/check-patterns.sh <scope> <files>`; collect findings.
4. Judgment pass: read the diff against `core.md`, `writing.md`, overlays; check root-cause-vs-symptom, single responsibility, defensive checks, naming, architecture leaks.
5. Emit findings: severity, `file:line`, rule, fix.
Modes and the config-driven behavior (backwardCompat, deadCode) exactly as spec §3.5.3.

- [ ] **Step 2: Author `commands/gate.md`**

A thin command that invokes the quality-gate skill on the current changeset, passing through `--check`/`--fix`/`--scope` arguments.

- [ ] **Step 3: Smoke-test the mechanical path end to end**

Run: `bash scripts/check-patterns.sh both tests/fixtures/bad-ts.ts`
Expected: prints the `as-any`, `console`, and `todo` findings, exit 1 (confirms the engine the skill calls works)

- [ ] **Step 4: Commit**

```bash
git add skills/quality-gate/SKILL.md commands/gate.md
git commit -m "feat: quality-gate skill and /gate command"
```

---

### Task 6: Project config, setup, and companions

**Files:**
- Create: `templates/config.default.json`
- Create: `companions.json`
- Create: `scripts/ensure-companions.sh`
- Modify: `commands/init.md`
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**Interfaces:**
- Produces: `.polaris/config.json` written into the target project by `init`; `ensure-companions.sh` idempotently syncs the skill bulk; native `dependencies` for marketplace companions.

- [ ] **Step 1: Write `templates/config.default.json`**

```json
{
  "mode": "custom",
  "deadCode": "delete",
  "backwardCompat": "none",
  "architecture": { "source": "polaris", "reference": null, "conventions": "" },
  "naming": { "source": "polaris", "rules": {} },
  "pr": { "source": "polaris", "standards": "" },
  "guardEdit": false
}
```

- [ ] **Step 2: Write `companions.json`**

```json
{
  "plugins": [
    { "name": "superpowers", "marketplace": "claude-plugins-official" },
    { "name": "frontend-design", "marketplace": "claude-plugins-official" },
    { "name": "andrej-karpathy-skills", "marketplace": "karpathy-skills" }
  ],
  "skillBulk": { "source": "https://github.com/Mindrally/skills", "dest": "~/.claude/skills/", "license": "Apache-2.0" }
}
```

- [ ] **Step 3: Write `scripts/ensure-companions.sh`**

```bash
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
DEST="${HOME}/.claude/skills"
MARKER="${DEST}/.polaris-mindrally-synced"

[ -f "$MARKER" ] && exit 0
command -v git >/dev/null 2>&1 || { echo "ensure-companions: git required to sync skill bulk" >&2; exit 0; }

mkdir -p "$DEST"
TMP="$(mktemp -d)"
if git clone --depth 1 https://github.com/Mindrally/skills "$TMP" 2>/dev/null; then
  # copy skill folders that are not already present
  for d in "$TMP"/*/; do
    name="$(basename "$d")"
    [ -e "${DEST}/${name}" ] || cp -R "$d" "${DEST}/${name}"
  done
  touch "$MARKER"
  echo "ensure-companions: synced Mindrally skill bulk"
fi
rm -rf "$TMP"
exit 0
```

Make executable: `chmod +x scripts/ensure-companions.sh`

- [ ] **Step 4: Add native dependencies to `plugin.json`**

Add to `.claude-plugin/plugin.json`:
```json
"dependencies": [
  { "name": "superpowers", "marketplace": "claude-plugins-official" },
  { "name": "frontend-design", "marketplace": "claude-plugins-official" }
]
```
(Add `andrej-karpathy-skills` once its marketplace is confirmed addable; otherwise it stays in `companions.json` for the ensure step.)

- [ ] **Step 5: Add cross-marketplace allowlist to `marketplace.json`**

Add to `.claude-plugin/marketplace.json` root:
```json
"allowCrossMarketplaceDependenciesOn": ["claude-plugins-official", "karpathy-skills"]
```

- [ ] **Step 6: Evolve `commands/init.md`**

Add the setup interview (spec §3.5.1): ask dead-code, backward-compat, architecture (describe / github / local / polaris), naming, PR standards, plus one-step auto mode. Write answers to `.polaris/config.json` in the target project from `templates/config.default.json`. Run `ensure-companions.sh`. Keep the existing CLAUDE.md generation.

- [ ] **Step 7: Validate JSON files**

Run: `jq . templates/config.default.json companions.json .claude-plugin/plugin.json .claude-plugin/marketplace.json >/dev/null && echo ok`
Expected: `ok`

- [ ] **Step 8: Commit**

```bash
git add templates/config.default.json companions.json scripts/ensure-companions.sh commands/init.md .claude-plugin/
git commit -m "feat: project config, setup interview, native + synced companions"
```

---

### Task 7: Hooks (guard-commit-pr, guard-edit, session-start)

**Files:**
- Create: `hooks/guard-commit-pr`
- Create: `hooks/guard-edit`
- Modify: `hooks/session-start`
- Modify: `hooks/hooks.json`
- Create: `tests/fixtures/commit-bad.txt`, `tests/fixtures/commit-good.txt`
- Modify: `tests/run-tests.sh`

**Interfaces:**
- Consumes: `scripts/check-patterns.sh`, `scripts/ensure-companions.sh`.
- Produces: a `PreToolUse` hook that denies `git commit`/`gh pr create` with a message that violates the prose standard; a `PostToolUse` hook that surfaces edit violations when the project opts in; an evolved `session-start`.

- [ ] **Step 1: Extend the test harness for the commit guard**

`tests/fixtures/commit-bad.txt`: `feat: delve into the new tapestry of features`
`tests/fixtures/commit-good.txt`: `feat: add pattern checker with fixtures`

Add to `tests/run-tests.sh` (before `exit $fail`):
```bash
GUARD="${DIR}/../hooks/guard-commit-pr"
# simulate PreToolUse payload for a git commit -m with a bad/good message
bad_payload=$(jq -n --arg c "git commit -m \"$(cat "${DIR}/fixtures/commit-bad.txt")\"" '{tool_input:{command:$c}}')
good_payload=$(jq -n --arg c "git commit -m \"$(cat "${DIR}/fixtures/commit-good.txt")\"" '{tool_input:{command:$c}}')
echo "$bad_payload"  | "$GUARD" | grep -q '"permissionDecision":"deny"' && echo "ok: bad commit denied"  || { echo "FAIL: bad commit not denied"; fail=1; }
echo "$good_payload" | "$GUARD" | grep -q '"permissionDecision":"deny"' && { echo "FAIL: good commit denied"; fail=1; } || echo "ok: good commit allowed"
```

- [ ] **Step 2: Run harness to verify the new checks fail**

Run: `bash tests/run-tests.sh`
Expected: FAIL on the two new lines (guard does not exist yet)

- [ ] **Step 3: Implement `hooks/guard-commit-pr`**

```bash
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
CHECK="${ROOT}/scripts/check-patterns.sh"

input="$(cat)"
cmd="$(echo "$input" | jq -r '.tool_input.command // ""')"
case "$cmd" in
  *"git commit"*|*"gh pr create"*) : ;;
  *) exit 0 ;;
esac

# extract the message text after -m or --body/--title, best-effort
msg="$(echo "$cmd" | grep -oE '(-m|--body|--title)[= ]+"[^"]*"' | sed -E 's/(-m|--body|--title)[= ]+"//; s/"$//')"
[ -z "$msg" ] && exit 0

tmp="$(mktemp)"; printf '%s\n' "$msg" > "$tmp"
out="$(CLAUDE_PLUGIN_ROOT="$ROOT" bash "$CHECK" prose "$tmp" 2>/dev/null)"
rm -f "$tmp"

if [ -n "$out" ]; then
  reason="Commit/PR message violates the writing standard: ${out}"
  jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
fi
exit 0
```
Note: the checker skips `rules/` and `patterns.json`, but a `mktemp` file is neither, so the message is scanned normally.

- [ ] **Step 4: Run harness to verify it passes**

Run: `bash tests/run-tests.sh`
Expected: `ok: bad commit denied`, `ok: good commit allowed`, exit 0

- [ ] **Step 5: Implement `hooks/guard-edit` (opt-in, non-blocking)**

```bash
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
# opt-in: only run when the project config enables it
cfg="${CLAUDE_PROJECT_DIR:-$PWD}/.polaris/config.json"
[ -f "$cfg" ] || exit 0
jq -e '.guardEdit == true' "$cfg" >/dev/null 2>&1 || exit 0

input="$(cat)"
file="$(echo "$input" | jq -r '.tool_input.file_path // ""')"
[ -f "$file" ] || exit 0
out="$(CLAUDE_PLUGIN_ROOT="$ROOT" bash "${ROOT}/scripts/check-patterns.sh" code "$file" 2>/dev/null)"
[ -z "$out" ] && exit 0
jq -n --arg c "Polaris: possible slop in $file:
$out" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
exit 0
```

- [ ] **Step 6: Evolve `hooks/session-start`**

Change the current script so it: loads `rules/core.md` + `rules/writing.md` always; detects stacks (keep existing detection, map to `stack-map.json` keys); loads only the detected overlays instead of everything; and on first run calls `ensure-companions.sh`. Keep the existing JSON output shape (`hookSpecificOutput.additionalContext`).

- [ ] **Step 7: Register hooks in `hooks/hooks.json`**

```json
{
  "hooks": {
    "SessionStart": [
      { "matcher": "startup|clear|compact", "hooks": [ { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start", "async": false } ] }
    ],
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/guard-commit-pr\"" } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/guard-edit\"" } ] }
    ]
  }
}
```
Make hooks executable: `chmod +x hooks/guard-commit-pr hooks/guard-edit`

- [ ] **Step 8: Validate and commit**

Run: `jq . hooks/hooks.json >/dev/null && bash tests/run-tests.sh`
Expected: JSON valid, all tests `ok`, exit 0

```bash
git add hooks/ tests/
git commit -m "feat: guard-commit-pr and guard-edit hooks, stack-aware session-start"
```

---

### Task 8: Merge and evolve the quality agents

**Files:**
- Modify: `agents/code-cleanup.md`
- Modify: `agents/audit-refactor.md`
- Delete: `agents/slop-remover.md`

**Interfaces:**
- Consumes: the quality-gate skill (Task 5), the standard (Tasks 2-3).
- Produces: two stack-aware agents that delegate checking to the gate.

- [ ] **Step 1: Rewrite `agents/code-cleanup.md`**

Absorb `slop-remover`: fold its unique category (inline-lambda extraction) and every trigger phrase from its description ("remove AI slop from this PR", "remove AI code slop") into `code-cleanup`'s `description`. Replace the Next.js-specific body with: invoke the `quality-gate` skill in `--fix` mode on the recent changeset, then report what changed. Frontmatter uses only allowed plugin-agent fields (drop any unsupported ones). Follow the agent contract from master plan §6.0.

- [ ] **Step 2: Delete `agents/slop-remover.md`**

Run: `git rm agents/slop-remover.md`

- [ ] **Step 3: Evolve `agents/audit-refactor.md`**

Remove "You are a Next.js Codebase Auditor". Keep the four-category structure and read-only-then-approve-then-refactor flow, but source the checks from the loaded stack overlays and the gate rather than hardcoded Next.js checks, so it audits any stack. Reference the standard instead of restating it.

- [ ] **Step 4: Verify no dangling references to slop-remover**

Run: `grep -rn "slop-remover" --include=*.md --include=*.json . | grep -v docs/`
Expected: no results outside `docs/` (the plan and specs may still mention the merge history)

- [ ] **Step 5: Commit**

```bash
git add agents/
git commit -m "feat: merge slop-remover into code-cleanup, make audit-refactor stack-aware"
```

---

### Task 9: Retire old rules, refresh README, bump version, validate

**Files:**
- Delete: `rules/general.md`, `rules/no-ai-slop.md`
- Modify: `README.md`
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

**Interfaces:**
- Produces: a clean, single-source standard with no retired files, an updated README, and a bumped version.

- [ ] **Step 1: Confirm content migrated, then delete the retired files**

Run: `grep -rn "general.md\|no-ai-slop.md" hooks/ scripts/ skills/ agents/`
Expected: no code path still reads them (session-start now reads core.md + writing.md). Then:
```bash
git rm rules/general.md rules/no-ai-slop.md
```

- [ ] **Step 2: Update `README.md`**

Describe the evolved Polaris: the canonical standard, the quality gate, the hooks, the config/setup, companions. Remove references to the retired files. Must pass the writing standard.

- [ ] **Step 3: Bump the version**

Set `version` in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` to `0.3.0`.

- [ ] **Step 4: Validate the whole checker suite once more**

Run: `bash tests/run-tests.sh`
Expected: all `ok`, exit 0

- [ ] **Step 5: Validate against a real repo**

Run: `bash scripts/check-patterns.sh code $(git -C ../sage/sage-frontend ls-files '*.ts' '*.tsx' | sed 's#^#../sage/sage-frontend/#' | head -50)`
Expected: the checker runs and reports real findings (or none) without error. Review a sample by hand to confirm findings are correct; this is the validation pass for the standard. Note: adjust the path if `sage-frontend` lives elsewhere.

- [ ] **Step 6: Run the README through its own standard**

Run: `bash scripts/check-patterns.sh prose README.md`
Expected: exit 0

- [ ] **Step 7: Commit**

```bash
git add README.md .claude-plugin/ rules/
git commit -m "chore: retire general.md/no-ai-slop.md, refresh README, bump to 0.3.0"
```

---

## Notes for the executor

- Work stays on `main` (project rule). Commit after each task.
- `hooks/run-hook.cmd` already exists and wraps hook scripts cross-platform; new hooks are invoked directly in `hooks.json` per the examples, matching the existing session-start entry's pattern. If a hook needs the `.cmd` wrapper on Windows, route it the same way session-start is routed.
- Prose files (core.md, writing.md, overlays, agents, README) are authored from named existing sources, not invented. When a step says "from general.md" or "from master plan §X", copy that content and adapt, do not paraphrase loosely.
- After Task 9, the plugin is milestone M1 complete and ready to use.
