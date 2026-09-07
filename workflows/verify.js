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

// Effort and the round ceiling are one dial, because rounds multiply the fan-out: every round is
// one agent per angle, and thinking tokens bill as output. A level names both rather than leaving
// effort to the session, which is how this workflow came to run every agent of every round at high.
// judgeBudget is the total number of judge dispatches across every round, and it exists because
// the finder side was bounded and the judge side was not. Rounds x angles caps the finders at 16,
// but judges were 3 lenses per finding with no cap on findings, so one productive round could
// dispatch 60 and a full run could reach roughly 207. That is a fan-out nobody asked for and it is
// the workflow's own over-engineering axis pointed at itself.
//
// lenses is the same dial: three different lenses beat three copies, but only for a finding whose
// verdict could change what happens next. A low-severity finding gets one reading.
const LEVELS = {
  low: { effort: 'low', maxRounds: 1, dry: 1, judge: 'low', lenses: 1, judgeBudget: 6 },
  mid: { effort: 'medium', maxRounds: 2, dry: 2, judge: 'medium', lenses: 2, judgeBudget: 18 },
  high: { effort: 'high', maxRounds: 4, dry: 2, judge: 'high', lenses: 3, judgeBudget: 36 },
}
const LENSES = ['does this actually reproduce', 'is the reasoning sound', 'is the fix implied by it correct']
const RANK = { high: 0, medium: 1, low: 2 }
const askedLevel = args ? args.level : undefined
const level = typeof askedLevel === 'string' && Object.hasOwn(LEVELS, askedLevel) ? askedLevel : 'high'
const rules = LEVELS[level]
if (askedLevel !== undefined && level !== askedLevel) log(`verify level ${JSON.stringify(askedLevel)} not recognized; running high`)

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
let judgesSpent = 0

// Severity decides how many lenses a finding earns, inside the budget. A high-severity claim is
// what the sweep exists to catch, so it gets the full panel; a low one gets a single reading, since
// a second opinion on a trivial finding changes nothing and costs the same as a first one on a real
// one. Findings are judged worst-first for the same reason: the budget runs out on the cheap ones.
const lensesFor = f => (f.severity === 'high' ? rules.lenses : f.severity === 'medium' ? Math.min(2, rules.lenses) : 1)

// Loop until dry, not until a count. A fixed cap stops whether the work converged or not, and the
// last round is where the findings the first round's noise hid finally surface. Dedup against
// everything seen rather than against what was confirmed, or a finding the judges rejected comes
// back every round and the loop never ends.
while (dryRounds < rules.dry && round < rules.maxRounds) {
  round += 1
  phase('Find')
  const rounds = await parallel(
    ANGLES.map(a => () =>
      agent(
        `Sweep ${target} for ${a.ask}. Round ${round}.\n${extra}\n` +
          `Report only what you can point at with a file and a line. Do not repeat these, already found:\n` +
          [...seen].join('\n'),
        { label: `find:${a.key}:r${round}`, phase: 'Find', agentType: a.agent, schema: FINDINGS, effort: rules.effort },
      ),
    ),
  )

  const fresh = rounds
    .filter(Boolean)
    .flatMap(r => r.findings || [])
    .filter(f => !seen.has(key(f)))

  if (fresh.length === 0) {
    dryRounds += 1
    log(`round ${round}: nothing new (${dryRounds} of ${rules.dry} dry)`)
    continue
  }
  dryRounds = 0
  fresh.forEach(f => seen.add(key(f)))
  log(`round ${round}: ${fresh.length} new, ${confirmed.length} confirmed so far`)

  phase('Judge')

  // Spend the budget worst-first, and say what it did not reach. A sweep that silently stops
  // judging reads as "everything else was fine", which is the one wrong answer here.
  const ordered = [...fresh].sort((a, b) => RANK[a.severity] - RANK[b.severity])
  const toJudge = []
  for (const f of ordered) {
    const want = lensesFor(f)
    if (judgesSpent + want > rules.judgeBudget) continue
    judgesSpent += want
    toJudge.push(f)
  }
  const unjudged = ordered.filter(f => !toJudge.includes(f))
  if (unjudged.length > 0) {
    log(`round ${round}: judge budget spent (${judgesSpent}/${rules.judgeBudget}); ${unjudged.length} finding(s) reported unjudged`)
    confirmed.push(...unjudged.map(f => ({ ...f, state: 'unjudged', why: 'the judge budget for this level was spent on higher-severity findings' })))
  }

  const judged = await parallel(
    toJudge.map(f => () =>
      // Different lenses, not repeated copies. Redundant verifiers agree with each other; different
      // ones catch what a single reading cannot. Each is told to refute, so surviving means
      // surviving an attempt, not passing a glance.
      parallel(
        LENSES.slice(0, lensesFor(f)).map(
          lens => () =>
            agent(
              `A reviewer claims: ${f.summary}\nAt ${f.file}:${f.line}\nEvidence given: ${f.evidence}\n\n` +
                `Try to refute it, through this lens: ${lens}. Read the code. If you cannot prove it wrong, say so.`,
              { label: `judge:${f.file}:${f.line}`, phase: 'Judge', agentType: 'polaris:verifier', schema: VERDICT, effort: rules.judge },
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
  if (judgesSpent >= rules.judgeBudget) {
    log(`judge budget exhausted after round ${round}; stopping the sweep rather than finding what it cannot judge`)
    break
  }
}

if (round >= rules.maxRounds && dryRounds < rules.dry) {
  log('stopped at the round ceiling without converging; the list is incomplete')
}

return {
  target,
  rounds: round,
  converged: dryRounds >= rules.dry,
  found: seen.size,
  judgesSpent,
  judgeBudget: rules.judgeBudget,
  confirmed: confirmed.sort((a, b) => ['high', 'medium', 'low'].indexOf(a.severity) - ['high', 'medium', 'low'].indexOf(b.severity)),
}
