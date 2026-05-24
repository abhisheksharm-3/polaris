# Polaris

Design intelligence + stack-aware skills for Claude Code. Auto-detects your project stack and routes to the right skill — no configuration needed.

## What's included

| Component | Source | Purpose |
|---|---|---|
| `polaris:ui-new` skill | UI UX Pro Max | Generate new UI from scratch with industry-specific design systems |
| `polaris:ui-polish` skill | Impeccable | Audit, refine, and quality-check UI with 27 anti-pattern rules |
| `polaris:ui-prototype` skill | Huashu Design | Create prototypes, slide decks, motion graphics, and infographics |
| `polaris:playwright-e2e` skill | playwright-skill | Browser automation and E2E testing with Playwright |
| Frontend baseline rules | Taste-Skill | Always-on design quality constraints (no AI purple, no emoji icons, etc.) |
| Next.js agents | abhisheksharm-3 gist | Four specialized agents for Next.js 15+ / React 19 workflows |
| Auto-detect hook | Custom | Detects stack at session start, injects the right rules automatically |

## Companion plugin (required)

Polaris handles design and stack workflows. For process skills (TDD, debugging, planning, code review), install **Superpowers** alongside it:

```
/plugin install superpowers@claude-plugins-official
```

## Installation

### Option 1: From GitHub marketplace (recommended)

```
/plugin marketplace add abhisheksharm-3/polaris
/plugin install polaris
```

### Option 2: Local development

```
claude --plugin-dir ./polaris
```

## Detected stacks

Polaris auto-injects rules and agent routing for:
- **Next.js** (detects `"next"` in package.json)
- **React** (detects `"react"` in package.json, no Next)
- **Python** (detects `pyproject.toml` or `requirements.txt`)
- **Rust** (detects `Cargo.toml`)
- **Go** (detects `go.mod`)
- **Playwright** (detects `"playwright"` or `"@playwright/test"` in package.json)

## Skill routing

| You want to... | Skill or agent used |
|---|---|
| Build new UI from scratch | `polaris:ui-new` → `polaris:ui-polish` |
| Audit or refine existing UI | `polaris:ui-polish` |
| Create a prototype or slide deck | `polaris:ui-prototype` |
| Write E2E tests | `polaris:playwright-e2e` |
| Build a Next.js feature | `polaris:feature-builder` agent |
| Post-AI-session cleanup | `polaris:code-cleanup` agent |
| Full codebase audit | `polaris:audit-refactor` agent |
| Remove AI-generated artifacts | `polaris:slop-remover` agent |

## Attribution

All skill content is MIT licensed. Source repositories:
- [UI UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)
- [Impeccable](https://github.com/pbakaus/impeccable)
- [Huashu Design](https://github.com/alchaincyf/huashu-design)
- [Taste-Skill](https://github.com/Leonxlnx/taste-skill)
- [playwright-skill](https://github.com/lackeyjb/playwright-skill)
- [Next.js Agents](https://gist.github.com/abhisheksharm-3/26caa5ebaeb08d58a0a60a866bb82473)

## License

MIT — see LICENSE file.
