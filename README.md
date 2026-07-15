# Polaris

An opinionated quality foundation for Claude Code. Polaris holds one standard across every
project: code that is simple, secure, self-explanatory, and low in complexity, and prose (comments,
commit messages, PR text, docs) that reads like a careful human wrote it. It auto-detects your
stack and enforces the standard through a callable gate and opt-in hooks.

## What's included

| Component | Purpose |
|---|---|
| `rules/core.md` | Language-agnostic engineering standard: simplicity, root-cause fixes, the docs protocol, the Karpathy surgical-vs-aggressive rule |
| `rules/writing.md` | The anti-slop writing standard for all prose output |
| `rules/patterns.json` | Machine-readable banned words and code tokens, shared by the gate and the hooks |
| `rules/stacks/*` + `stack-map.json` | Per-stack overlays (ts, react, nextjs, python, go, rust) and the map from a detected stack to its skills, docs, and overlay |
| `quality-gate` skill + `/gate` | Check or fix a changeset: a deterministic pass plus a judgment pass, with `file:line` findings |
| `output-styles/polaris-writing.md` | Applies the writing standard at the system-prompt level |
| Agent fleet (27) | A role agent for every SDLC phase and domain: product, researcher, architect, api-designer, data-modeler, security-architect, ux, ui, frontend-logic, backend, integrations, infra, data-engineer, reviewer, verifier, tester, e2e, perf, bug-fixer, tech-writer, shipper, devops, sre, plus code-cleanup, audit-refactor, feature-builder, prod-audit. Each wires host skills and carries a model tier |
| `code-cleanup`, `audit-refactor` agents | Recent-code quality pass and whole-codebase audit, both stack-aware |
| `/handoff` + templates | Generate a feature or audit handoff doc from real repo state, into `.polaris/` |
| `prod-audit` agent | Strict, evidence-backed production-readiness audit; reports findings and residual risk |
| `rules/model-routing.md` | Model tier policy: Opus for planning, QA, and review; Sonnet for code; Haiku only for trivial. Agents carry a matching `model` |
| Injection guardrail | `guard-input` flags prompt-injection markers in fetched and MCP tool results, so untrusted content is treated as data, not instructions |
| Hooks | `session-start` injects the standard and detected overlays; `guard-commit-pr` blocks commits and PRs that violate the writing standard; `guard-edit` surfaces slop on edit (opt-in); `guard-input` flags injection in tool results |
| `/init` | Setup interview writing `.polaris/config.json`, companion install, and CLAUDE.md generation |

## Companions

Polaris installs its companions for you. `superpowers` and `frontend-design` are declared as
native plugin dependencies and install with Polaris. The stack skill library (from
`github.com/Mindrally/skills`, Apache-2.0) and other skills sync on first run.

## Installation

From the marketplace:

```
/plugin marketplace add abhisheksharm-3/polaris
/plugin install polaris
```

Local development:

```
claude --plugin-dir ./polaris
```

## Setup

Run `/init` (or `/polaris:init`) at a project root. It asks how you want the standard applied
(dead code, backward compatibility, architecture, naming, PR standards, or a one-step auto mode),
writes `.polaris/config.json`, installs companions, and sets up `CLAUDE.md`. The gate, hooks, and
agents all read that config.

## The quality gate

Run `/gate` to check the current changeset, or `/gate --fix` to fix and re-verify. Scope it with
`--scope code|writing|both`. The gate runs a fast deterministic pass (`scripts/check-patterns.sh`
over `patterns.json`) plus a judgment pass against the standard, then reports pass or fail with
`file:line` findings and the fix.

## Detected stacks

Polaris injects the right overlay for Next.js, React, Python, Rust, Go, and Playwright, detected
from the project manifests at session start.

## Testing

The deterministic checker and the commit guard have shell fixtures. Run `bash tests/run-tests.sh`.

## Attribution

Skill content is MIT or Apache-2.0 licensed. Sources include the Mindrally skill library
(Apache-2.0), UI UX Pro Max, Impeccable, Huashu Design, and playwright-skill.

## License

MIT. See the LICENSE file.
