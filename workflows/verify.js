export const meta = {
  name: 'verify',
  description: 'Find every issue in a target, then confirm each one through independent lenses',
  whenToUse: 'The verify phase of the bug, audit, qa, and security flows',
  phases: [
    { title: 'Find', detail: 'finders sweep the target from different angles, in rounds' },
    { title: 'Judge', detail: 'three lenses per finding, each trying to refute it' },
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
        required: ['file', 'line', 'severity', 'summary', 'evidence'],
        properties: {
          file: { type: 'string' },
          line: { type: 'integer' },
          severity: { type: 'string', enum: ['high', 'medium', 'low'] },
          summary: { type: 'string' },
          evidence: { type: 'string' },
        },
      },
    },
  },
}

const VERDICT = {
  type: 'object',
  required: ['refuted', 'reason'],
  properties: {
    refuted: { type: 'boolean' },
    reason: { type: 'string' },
  },
}

const target = (args && args.target) || 'the current changeset'
const extra = (args && args.context) || ''

const ANGLES = [
  { key: 'correctness', agent: 'polaris:reviewer', ask: 'wrong results, unhandled states, broken invariants' },
  { key: 'security', agent: 'polaris:security-architect', ask: 'injection, broken authorization, secret exposure, unsafe input' },
  { key: 'edges', agent: 'polaris:tester', ask: 'edge cases, misuse, races a real user or attacker would hit' },
  { key: 'over-engineering', agent: 'polaris:reviewer', ask: 'what should not exist at all: unneeded abstraction, dead flexibility, a dependency a few lines would replace' },
]

// The over-engineering angle is not optional. Every Polaris review reports it, and a sweep that
// only hunts defects will happily confirm that an unnecessary abstraction is correct.

const key = f => `${f.file}:${f.line}:${f.severity}`
const seen = new Set()
const confirmed = []
let dryRounds = 0
let round = 0

// Loop until dry, not until a count. A fixed cap stops whether the work converged or not, and the
// last round is where the findings the first round's noise hid finally surface. Dedup against
// everything seen rather than against what was confirmed, or a finding the judges rejected comes
// back every round and the loop never ends.
while (dryRounds < 2 && round < 4) {
  round += 1
  phase('Find')
  const rounds = await parallel(
    ANGLES.map(a => () =>
      agent(
        `Sweep ${target} for ${a.ask}. Round ${round}.\n${extra}\n` +
          `Report only what you can point at with a file and a line. Do not repeat these, already found:\n` +
          [...seen].join('\n'),
        { label: `find:${a.key}:r${round}`, phase: 'Find', agentType: a.agent, schema: FINDINGS, effort: 'high' },
      ),
    ),
  )

  const fresh = rounds
    .filter(Boolean)
    .flatMap(r => r.findings || [])
    .filter(f => !seen.has(key(f)))

  if (fresh.length === 0) {
    dryRounds += 1
    log(`round ${round}: nothing new (${dryRounds} of 2 dry)`)
    continue
  }
  dryRounds = 0
  fresh.forEach(f => seen.add(key(f)))
  log(`round ${round}: ${fresh.length} new, ${confirmed.length} confirmed so far`)

  phase('Judge')
  const judged = await parallel(
    fresh.map(f => () =>
      // Three lenses, not three copies. Redundant verifiers agree with each other; different ones
      // catch what a single reading cannot. Each is told to refute, so surviving means surviving
      // an attempt, not passing a glance.
      parallel(
        ['does this actually reproduce', 'is the reasoning sound', 'is the fix implied by it correct'].map(
          lens => () =>
            agent(
              `A reviewer claims: ${f.summary}\nAt ${f.file}:${f.line}\nEvidence given: ${f.evidence}\n\n` +
                `Try to refute it, through this lens: ${lens}. Read the code. If you cannot prove it wrong, say so.`,
              { label: `judge:${f.file}:${f.line}`, phase: 'Judge', agentType: 'polaris:verifier', schema: VERDICT },
            ),
        ),
      ).then(votes => {
        const real = votes.filter(Boolean)
        const kept = real.filter(v => !v.refuted).length
        return { finding: f, survives: real.length > 0 && kept * 2 > real.length, votes: real }
      }),
    ),
  )

  confirmed.push(...judged.filter(Boolean).filter(j => j.survives).map(j => j.finding))
}

if (round >= 4 && dryRounds < 2) {
  log('stopped at the round ceiling without converging; the list is incomplete')
}

return {
  target,
  rounds: round,
  converged: dryRounds >= 2,
  found: seen.size,
  confirmed: confirmed.sort((a, b) => ['high', 'medium', 'low'].indexOf(a.severity) - ['high', 'medium', 'low'].indexOf(b.severity)),
}
