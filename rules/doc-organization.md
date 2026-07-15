# Polaris Doc Organization

<!-- Injected every session. Keeps every doc Polaris produces in one place, named consistently. -->

All docs Polaris produces live under `.polaris/` in the project root. Nothing scatters into the
repo. The layout:

```
.polaris/
  config.json          the project config (from setup)
  handoffs/            YYYY-MM-DD-<topic>-handoff.md
  audits/              YYYY-MM-DD-<topic>-audit.md
  specs/               YYYY-MM-DD-<topic>-spec.md
  plans/               YYYY-MM-DD-<topic>-plan.md
  reports/             YYYY-MM-DD-<topic>-report.md
```

Rules:

- One directory per kind, dated kebab-case names, one topic per file.
- Create the subdirectory on demand; do not write a doc anywhere else.
- Before adding a doc, check whether an existing one covers the topic and update it instead of
  making a near-duplicate.
- A doc's prose passes the writing standard (`rules/writing.md`).
