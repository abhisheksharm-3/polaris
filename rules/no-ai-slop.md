# Anti-AI-Slop Writing Rules

<!-- Source: https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing -->
<!-- Local summary — always injected. A fresh copy of the source article is fetched at session start. -->

---

## Fetch Fresh Patterns Every Session

Before any writing or content-generation task, run:

```
WebFetch("https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing",
  "Extract all signs of AI writing: vocabulary lists, structural patterns, forbidden phrases, and style red flags.")
```

The live article is updated as AI writing evolves. The local summary below is a baseline — the fetched page is authoritative.

---

## Banned Vocabulary

Never use these words/phrases. They are the strongest signal of AI-generated text:

### Era 1 (2023–2024) — hard ban
`delve` · `intricate` · `tapestry` · `testament` · `underscore` · `pivotal` · `Additionally,` (as a sentence opener) · `stands as` · `serves as` · `vital role` · `crucial role` · `indelible mark` · `reflects broader trends`

### Era 2 (2024–2025) — hard ban
`align with` · `enhance` · `fostering` · `highlighting` · `showcasing` · `groundbreaking` · `vibrant` · `nestled` · `boasts` · `diverse array`

### Structure-signalling phrases — hard ban
`Not just X, but also Y` · `Not only X, but Y` · `Rather than X, Y` · `It is worth noting that` · `It is important to note` · `Challenges and Future` (as a section title) · `Future Outlook` (as a section title)

---

## Forbidden Structural Patterns

### The "Challenges & Future" Formula
AI reliably ends sections with: "Despite its [positive], X faces challenges… however, future improvements promise Y."
- **Never** write this arc unless the source material explicitly supports it.
- **Never** end with unprompted optimism about future prospects.

### The Rule of Three
Avoid reflexive three-item padding: "efficient, scalable, and maintainable." If three items are real, keep them. If you're padding to hit the pattern, cut to the strongest one.

### Fake Significance Inflation
- No "-ing phrases" appended to claim importance without evidence: `"…highlighting its historical significance"`
- No `"generating significant debate"` without citing the actual debate
- No `"is a testament to"` — show the thing itself

### Elegant Variation (Lexical Gymnastics)
Using five different words for the same concept to avoid repetition is an AI tell. Repeat the right word. Consistency beats variety.

### Negative Parallelism
Constructions like `"not just X, but also Y"` solve imaginary misconceptions. Don't defend against a misunderstanding the reader wasn't having.

---

## Forbidden Tone Patterns

### Weasel Attribution
- No `"Industry experts argue"` · `"Observers note"` · `"Some critics say"` without a real source
- No listing sources to prove notability instead of quoting what they actually said

### Promotional Register
Writing that reads like a press release or travel brochure: `"boasts a vibrant community"`, `"nestled in the heart of"`, `"a groundbreaking approach"`. Strip it. State facts.

### Copula Avoidance
AI avoids "is/are" and replaces with `serves as`, `marks`, `represents`, `features`. Use "is." It's fine.

```
BANNED: "The component serves as a wrapper that features advanced routing."
RIGHT:  "The component wraps routes and handles advanced routing."
```

---

## Forbidden Formatting Habits

| Pattern | Ban |
|---|---|
| Title Case In Every Heading | Use sentence case |
| **Bold:** every term in a bullet list | Bold only genuinely critical terms |
| Em dashes everywhere — for every — pause | Use commas and periods |
| Thematic breaks (`---`) before every section | Only where logically needed |
| Skipping heading levels (H2 → H4) | Maintain hierarchy |

---

## How to Write Without Sounding Like AI

1. **Say the thing directly.** "The API is slow." Not "The API faces performance challenges that stakeholders have noted."
2. **Use the right word once.** Don't rotate synonyms to avoid repetition.
3. **Earn significance.** Don't claim something is important — show why.
4. **Let sentences end.** Avoid trailing qualifiers: `"…which is crucial for modern applications."`
5. **Avoid hedging stacks.** One qualifier per claim. Not: `"It is generally considered that it may potentially…"`
6. **No unsolicited future speculation.** Don't predict roadmaps unless asked.
7. **Vary sentence length naturally.** Short. Then medium. Then a longer one when the idea needs room. Not uniformly medium-length throughout.

---

## Quick Self-Check Before Submitting Any Content

Scan for:
- [ ] Any word from the banned vocabulary list above
- [ ] Sentences that open with "Additionally," "Furthermore," "Moreover,"
- [ ] Three-item lists that exist only to look comprehensive
- [ ] A "challenges → future outlook" closing arc
- [ ] "serves as" / "stands as" / "acts as" instead of "is"
- [ ] Significance claims without evidence (`"indelible mark"`, `"testament to"`)
- [ ] Weasel attribution (`"experts argue"`, `"observers note"`)
- [ ] Uniform sentence length throughout
