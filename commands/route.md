---
description: Route a situation to the one right Polaris command or agent, and say why, then stop
argument-hint: "<the situation you are in>"
allowed-tools: Read, Grep, Glob
---

<!-- Adapted from mattpocock/skills (MIT): ask-matt -->

# Route

Given the situation in `$ARGUMENTS`, name the one Polaris command or agent that fits, say in a line
why, and stop. This routes; it does not run anything. Read `.polaris/config.json` first if the choice
depends on how the project is set up.

Match the situation to the closest row, then hand the user that command.

## Building something

| Situation | Use |
|---|---|
| An idea, task, or PRD to take all the way to shipped | `/flow` |
| A large, foggy effort with more open questions than answers | `/recon` |
| A feasibility question you cannot answer on paper | `/spike` |
| The team keeps arguing about what a term means | `/domain` |
| You want to know what to build next | `/research` |
| A vague prompt you want sharpened before running it | `/enhance` |

## Fixing something

| Situation | Use |
|---|---|
| A bug that resists diagnosis | `/debug` |
| A pile of bugs or issues to sort and prioritize | `/triage` |
| A production incident happening now | `/incident` |
| A security surface to threat-model and harden | `/harden` |
| A dependency or framework upgrade to do safely | `/modernize` |

## Checking something

| Situation | Use |
|---|---|
| A changeset to hold to the standard before it ships | `/gate` |
| An open pull request to review | `/review-pr` |
| A whole codebase to audit across four categories | `/audit` |
| Docs that have drifted from the code | `/docs-drift` |
| How some part of this codebase works | `/explain` |

## Keeping track

| Situation | Use |
|---|---|
| Starting the day, need to know where you left off | `/catchup` |
| A full start-of-day or end-of-day sweep of every source into a durable Notion briefing | `/sweep` |
| Reconcile this session's work into the tracker | `/track` |
| Write a handoff for someone picking this up | `/handoff` |
| Cut a release | `/release` |
| A fact worth keeping across sessions | `/remember` (save), `/recall` (retrieve) |

## When nothing fits

| Situation | Use |
|---|---|
| A command probably fits but you cannot tell which | `/route` (this) |
| No Polaris command fits the task at all | `/synthesize` |
