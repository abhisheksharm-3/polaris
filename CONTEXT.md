# Polaris building blocks

The vocabulary for the units Polaris is built from. Which folder a file lives in decides what it
is: `commands/`, `agents/`, and `skills/` are auto-discovered by directory, not listed in any
manifest.

## Language

**Command**: A user-invoked entry point, one file at `commands/<name>.md`, run by typing `/<name>`.
It drives a whole workflow and dispatches agents and skills to do the work. Claude never triggers it
on its own. Frontmatter is `description` / `argument-hint` / `allowed-tools`.
_Avoid_: mode, slash-skill

**Agent**: A single-job worker, one file at `agents/<name>.md`, dispatched through the Task tool with
its own model and system prompt (reviewer, backend, product). A command or Claude dispatches it; a
user does not slash-invoke it. Frontmatter is `name` / `description` (with dispatch examples) / `model`.
_Avoid_: subagent, fleet member

**Skill**: A reusable procedure, one folder at `skills/<name>/SKILL.md`, loaded through the Skill
tool. It carries instructions to follow, not a lifecycle to orchestrate. Claude auto-loads it when
its description matches the task (merge-conflicts on a live conflict), or a user invokes it by name.
Frontmatter is `name` / `description`.
_Avoid_: command, plugin

**Fleet**: The full set of agents under `agents/`, taken together.
_Avoid_: team, swarm
