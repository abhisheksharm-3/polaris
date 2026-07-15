# Polaris Model Routing

<!-- Injected every session. The floor per task class; agents set `model` in frontmatter to match. -->

Every agent and every cycle step runs on a model chosen from this policy, not left to default. The
policy sets the model floor per task class: harder or higher-stakes work must not run on a weaker
model.

| Task class | Model |
|---|---|
| Breaking and adversarial QA, interview and intake, planning, spec, architecture, threat model, review, RCA, adversarial verification | Opus |
| Code writing (implementation) | Sonnet |
| Genuinely trivial one-off tasks (mechanical edits, formatting, single-fact lookups) | Haiku |

Rules:

- The floor is a minimum, not a cap. Go higher when a task is unusually hard, never lower than the
  class allows.
- Code writing is Sonnet. QA, planning, interviewing, review, and anything adversarial is Opus.
  Haiku is reserved for the trivial and is the exception, not a cost-saving default.
- Standing agents set `model` in their frontmatter to their class. Ad-hoc subagent calls pick the
  model per this policy. A project may raise a floor in its config, never lower it.
