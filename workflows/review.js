export const meta = {
  name: 'review',
  description: 'Review a changeset across every dimension, then confirm each finding before it is reported',
  whenToUse: 'The review phase of the review flow, and a fresh-eyes pass before a merge',
  phases: [
    { title: 'Review', detail: 'one reviewer per dimension, in parallel' },
    { title: 'Confirm', detail: 'each finding refuted or upheld before it reaches the report' },
  ],
}

const FINDINGS = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['file', 'line', 'severity', 'summary', 'fix'],
        properties: {
          file: { type: 'string' },
          line: { type: 'integer' },
          severity: { type: 'string', enum: ['high', 'medium', 'low'] },
          summary: { type: 'string' },
          fix: { type: 'string' },
        },
      },
    },
  },
}

const VERDICT = {
  type: 'object',
  required: ['real', 'reason'],
  properties: { real: { type: 'boolean' }, reason: { type: 'string' } },
}

const target = (args && args.target) || 'the working diff against the default branch'

const DIMENSIONS = [
  { key: 'correctness', agent: 'polaris:reviewer', ask: 'wrong behavior, unhandled states, broken invariants' },
  { key: 'security', agent: 'polaris:security-architect', ask: 'injection, authorization, secrets, unsafe input, egress' },
  { key: 'performance', agent: 'polaris:perf', ask: 'work done per request that need not be, and behavior under load' },
  { key: 'maintainability', agent: 'polaris:reviewer', ask: 'what the next reader will misunderstand, and what will rot' },
  { key: 'tests', agent: 'polaris:tester', ask: 'behavior the tests do not cover, and tests that assert the bug' },
  { key: 'accessibility', agent: 'polaris:ux', ask: 'keyboard, contrast, labels, focus, and states a screen reader cannot see' },
  // Mandatory, and the reason guard-review sends back a review that omits it. Every other
  // dimension asks whether the code is right; only this one asks whether it should exist.
  { key: 'over-engineering', agent: 'polaris:reviewer', ask: 'what should not exist at all: an abstraction with one user, a config nobody sets, a dependency a few lines replace' },
]

// Pipeline, not a barrier. A dimension's findings go to confirmation the moment that dimension
// finishes, so the slowest reviewer does not hold the fastest one's findings hostage.
const results = await pipeline(
  DIMENSIONS,
  d =>
    agent(
      `Review ${target} for ${d.ask}.\nReport only what you can point at with a file and a line, ` +
        `each with the fix you would make. Say nothing rather than pad the list.`,
      { label: `review:${d.key}`, phase: 'Review', agentType: d.agent, schema: FINDINGS, effort: 'high' },
    ).then(r => ({ dimension: d.key, findings: (r && r.findings) || [] })),
  r =>
    parallel(
      r.findings.map(f => () =>
        agent(
          `A ${r.dimension} reviewer claims: ${f.summary}\nAt ${f.file}:${f.line}\nProposed fix: ${f.fix}\n\n` +
            `Read the code and try to refute it. A finding that is true but trivial is not real; say so.`,
          { label: `confirm:${f.file}:${f.line}`, phase: 'Confirm', agentType: 'polaris:verifier', schema: VERDICT },
        ).then(v => ({ ...f, dimension: r.dimension, verdict: v })),
      ),
    ),
)

const all = results.flat().filter(Boolean)
const real = all.filter(f => f.verdict && f.verdict.real)
const rank = { high: 0, medium: 1, low: 2 }

return {
  target,
  reviewed: DIMENSIONS.map(d => d.key),
  raised: all.length,
  confirmed: real.sort((a, b) => rank[a.severity] - rank[b.severity]),
  refuted: all.filter(f => !(f.verdict && f.verdict.real)).map(f => ({ file: f.file, line: f.line, summary: f.summary, why: f.verdict && f.verdict.reason })),
}
