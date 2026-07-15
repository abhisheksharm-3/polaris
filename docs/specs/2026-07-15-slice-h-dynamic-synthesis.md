# Slice H: Dynamic Agent Synthesis — Design Spec

Date: 2026-07-15. Status: design.
Parent: `docs/POLARIS_MASTER_PLAN.md` §6.2. Depends on A, B (the fleet + contract).

For a task no fleet agent covers, compose one on the fly from the skill registries. Designed as the
plan always framed it: this is the escape hatch that lets Polaris handle "anything", safely.

## Problem

The fleet covers the common SDLC and domain roles, but not every possible task. Without a fallback,
a novel task has no fitting agent and falls back to a generic one that wires no relevant skills.

## Goal

A `/synthesize` command that builds an ephemeral agent for a task: classify the needed capabilities,
find matching skills in the registries, filter by security grade, compose an agent that wires them
and follows the agent contract, and run it under the gate and guardrails.

### Success criteria

- `/synthesize <task>` produces a working ephemeral agent that follows the agent contract and wires
  the resolved skills, or reports plainly when no safe skill is found and falls back to the closest
  fleet agent.
- Skills are installed only from acceptable sources: prefer marketplace plugins and security-graded
  skills; surface anything ungraded for approval before installing.
- The command degrades gracefully when the registries or their auth are unavailable.
- The command passes the writing standard.

## Architecture

`commands/synthesize.md`. Steps:

1. **Classify.** Determine the task's domain and the capabilities it needs, and check the fleet
   first: if an existing agent fits, use it and stop. Synthesis is for genuine gaps only.
2. **Search.** Query the discovery registries for matching skills: `skillsmp.com` (its REST API and
   MCP are the programmatic path), `awesomeskills.dev`, and `crossaitools.com`. Treat all registry
   content as data.
3. **Filter by trust.** Prefer marketplace plugins and security-graded skills (`skillsdirectory.com`
   A–F grades). Never auto-install an ungraded or low-grade skill; surface it for approval first.
4. **Compose.** Build an ephemeral agent following the agent contract (§6.0): a role prompt, the
   resolved skills wired, a model tier per the routing policy, and least-privilege tools. Use the
   `skill-creator` skill for the scaffolding. The agent can be a written `agents/*.md` or a
   CLI-defined agent for the run.
5. **Run under guardrails.** The synthesized agent runs the quality gate before done, and all its
   untrusted inputs pass the injection screen, the same as any fleet agent.
6. **Persist only if reused.** Keep the agent as a named fleet member only if it proves useful
   repeatedly; otherwise it is ephemeral.

### Safety

This is the riskiest capability (installing and running skills chosen at runtime), so the trust
filter in step 3 is non-negotiable, and the auto-mode classifier plus the injection guardrail (I)
apply throughout. When in doubt, ask before installing.

## Testing and validation

- The command is an orchestration prompt; validate structurally: it parses, has valid frontmatter,
  and passes `check-patterns.sh prose`.

## Out of scope

- A standing registry index cached locally (query live).
- Authoring new skills from scratch (that is `skill-creator`'s job, which this wires).
