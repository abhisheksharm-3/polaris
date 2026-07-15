# Polaris Routing

<!-- Injected every session. Classify the task, then use the tools this table names. -->

Classify each task, then reach for the tools named here. Match the smallest thing that fits: do not
run the full cycle for a one-line change, and do not hand-run a feature that wants the cycle.

## Task classes and what to use

| Task looks like | Use | Ponytail | Model |
|---|---|---|---|
| Trivial one-off (rename, typo, a one-liner, a fact lookup) | Do it directly, then `/gate` if code changed | full | haiku ok |
| A single-file fix or small change | The fitting specialist agent, then `/gate` | full | sonnet |
| A new feature, component, page, or endpoint | `/flow` (or `feature-builder` for a contained one) | **ultra** | per phase |
| A bug or unexpected behavior | `bug-fixer` (+ `systematic-debugging`), reproduce first | full | sonnet |
| Review a change | `reviewer` per lens; run `/ponytail-review` on the diff | `/ponytail-review` | opus |
| Audit a whole codebase | `audit-refactor` or `prod-audit`; run `/ponytail-audit` | `/ponytail-audit` | opus |
| Break or QA a feature | `tester`, `e2e`, then `bug-fixer` and `verifier` | full | opus |
| Clean up recent code or remove slop | `code-cleanup` (`/gate --fix`), and `/ponytail-review` | **ultra** | sonnet |
| Research, onboarding, or an explanation | `/research`, `/onboard`, `/explain` | full | opus |
| A task no fleet agent fits | `/synthesize` | ultra | per task |
| A vague or underspecified prompt | `/enhance` first, or ask | full | sonnet |
| Cross-session context ("where was I") | `/catchup`, `/recall` | full | sonnet |

## Ponytail intensity

Ponytail's laziness ladder (`rules/core.md`) applies to all code writing. When ponytail is
installed it auto-injects into every subagent spawned via the Agent tool, so the whole fleet runs
it without being told. Its levels are `lite`, `full` (the default), `ultra`, and `off`:

- **`/ponytail ultra`**: greenfield code, anything that tempts a new dependency or a new
  abstraction, a large surface, or cleanup where over-engineering is the failure to hunt. It ships
  the one-liner and challenges the rest of the requirement.
- **`/ponytail full`**: the default; the ladder enforced, stdlib and native first. Routine work.
- **`/ponytail lite`**: builds what was asked and names the lazier alternative in one line, you
  choose. Use when the shape is already fixed and you want the suggestion, not the enforcement.
- **`/ponytail off`**: only when minimalism is actively unwanted for a task.

Its other commands: `/ponytail-review` audits a diff for over-engineering, `/ponytail-audit` scans
the whole repo, `/ponytail-debt` collects deferred shortcuts into a ledger, `/ponytail-gain` shows
the impact scoreboard. When ponytail is not installed, apply the ladder from `core.md` at the
matching pressure.

## Escalation

Start small and escalate only when the task proves larger: a single-file fix that turns out to span
subsystems moves up to `/flow`. Say when you escalate and why.
