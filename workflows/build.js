export const meta = {
  name: 'build',
  description: 'Implement a plan slice by slice, review and QA each one, and loop until it comes back clean',
  whenToUse: 'The build phase of the feature and foggy flows',
  phases: [
    { title: 'Split', detail: 'break the plan into slices that can be built independently' },
    { title: 'Build', detail: 'one implementer per slice, each running the gate before it reports' },
    { title: 'Check', detail: 'review and QA per slice, then fix and recheck until clean' },
  ],
}

const SLICES = {
  type: 'object',
  required: ['slices'],
  properties: {
    slices: {
      type: 'array',
      items: {
        type: 'object',
        required: ['name', 'agent', 'scope', 'done'],
        properties: {
          name: { type: 'string' },
          agent: { type: 'string' },
          scope: { type: 'string' },
          done: { type: 'string' },
          touches: { type: 'array', items: { type: 'string' } },
        },
      },
    },
  },
}

const OUTCOME = {
  type: 'object',
  required: ['ok', 'summary'],
  properties: {
    ok: { type: 'boolean' },
    summary: { type: 'string' },
    problems: { type: 'array', items: { type: 'string' } },
  },
}

const plan = (args && args.plan) || 'the approved plan in .polaris/plans/'
const MAX_FIXES = 3

// The Check stage is two agents per slice and the fix loop is a third, so effort here multiplies by
// slice count. A level names it rather than leaving it to the session, which is how every dispatch
// in this file came to run at high.
const LEVELS = {
  low: { plan: 'medium', build: 'low', check: 'low', fix: 'low' },
  mid: { plan: 'high', build: 'medium', check: 'medium', fix: 'medium' },
  high: { plan: 'high', build: 'medium', check: 'high', fix: 'high' },
}
const askedLevel = args ? args.level : undefined
const level = typeof askedLevel === 'string' && Object.hasOwn(LEVELS, askedLevel) ? askedLevel : 'high'
const rules = LEVELS[level]
if (askedLevel !== undefined && level !== askedLevel) log(`build level ${JSON.stringify(askedLevel)} not recognized; running high`)

phase('Split')
const split = await agent(
  `Read ${plan}. Break it into slices that can be built independently.\n` +
    `Each slice names the Polaris fleet agent that should build it, what it covers, and what done means ` +
    `in terms something can check. List the files each slice touches so overlapping ones can be isolated.\n` +
    `Fewer, larger slices beat many small ones: every slice costs a dispatch, a review, and a QA pass.`,
  { label: 'split', phase: 'Split', agentType: 'polaris:architect', schema: SLICES, effort: rules.plan },
)

const slices = (split && split.slices) || []
if (slices.length === 0) return { built: [], note: 'the plan produced no slices' }
log(`${slices.length} slices`)

// Two slices editing the same file in parallel corrupt each other, and a worktree costs real disk
// and setup time, so isolate only the ones that actually collide.
const counts = {}
slices.forEach(s => (s.touches || []).forEach(f => (counts[f] = (counts[f] || 0) + 1)))
const collides = s => (s.touches || []).some(f => counts[f] > 1)

// Pipeline: a slice goes to review the moment it is built, rather than waiting for the slowest
// implementer. Each slice carries its own fix loop, so one stubborn slice does not stall the rest.
const built = await pipeline(
  slices,
  s =>
    agent(
      `Build this slice.\nName: ${s.name}\nScope: ${s.scope}\nDone means: ${s.done}\n\n` +
        `Run the Polaris quality gate before you report done, and report what it said.`,
      {
        label: `build:${s.name}`,
        phase: 'Build',
        agentType: s.agent.startsWith('polaris:') ? s.agent : `polaris:${s.agent}`,
        schema: OUTCOME,
        effort: rules.build,
        ...(collides(s) ? { isolation: 'worktree' } : {}),
      },
    ).then(r => ({ slice: s, build: r })),
  async ({ slice, build }) => {
    let problems = []
    let rounds = 0

    // Review and QA together, then fix and check again. Capped, because a slice that will not come
    // clean in three rounds is a plan problem, and looping on it hides that behind spend.
    while (rounds < MAX_FIXES) {
      const checks = await parallel([
        () =>
          agent(
            `Review the slice "${slice.name}" (${slice.scope}). Report only real defects, with file and line, ` +
              `and include the over-engineering axis: what in this slice should not exist.`,
            { label: `review:${slice.name}`, phase: 'Check', agentType: 'polaris:reviewer', schema: OUTCOME, effort: rules.check },
          ),
        () =>
          agent(
            `Try to break the slice "${slice.name}". Done was defined as: ${slice.done}. ` +
              `Drive the real thing, not a description of it.`,
            { label: `qa:${slice.name}`, phase: 'Check', agentType: 'polaris:tester', schema: OUTCOME, effort: rules.check },
          ),
      ])

      problems = checks.filter(Boolean).filter(c => !c.ok).flatMap(c => c.problems || [c.summary])
      if (problems.length === 0) return { slice: slice.name, ok: true, rounds, build: build && build.summary }

      rounds += 1
      log(`${slice.name}: ${problems.length} problems, fix round ${rounds}`)
      await agent(
        `Fix these in the slice "${slice.name}", at the root cause rather than the symptom:\n` +
          problems.map(p => `- ${p}`).join('\n') +
          `\n\nRun the quality gate before reporting.`,
        { label: `fix:${slice.name}:${rounds}`, phase: 'Check', agentType: 'polaris:bug-fixer', schema: OUTCOME, effort: rules.fix },
      )
    }

    return { slice: slice.name, ok: false, rounds, problems }
  },
)

const done = built.filter(Boolean)
const stuck = done.filter(s => !s.ok)

return {
  slices: done.length,
  clean: done.filter(s => s.ok).map(s => s.slice),
  // Named, not swallowed. A build that reports success with a slice still failing is the one
  // outcome worse than a build that fails.
  stuck: stuck.map(s => ({ slice: s.slice, afterRounds: s.rounds, problems: s.problems })),
  ok: stuck.length === 0,
}
