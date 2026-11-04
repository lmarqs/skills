Written as a **retrospective technical document** (ADR-style record of an implementation), not a
forward-looking RFC — the migration is already in production, so the shape is context → architecture →
flows → risks → lessons learned → version history, with an operations section added because you said
"maintain it".

## One reclassification worth knowing about

You asked to document "how it turned out." I kept an **Alternatives considered** section anyway (§4).
It is reconstructed from the shape of the result, not transcribed from your decision meeting, and it is
labelled as such. The reason: a newcomer's real question is never "what is deployed" — the diagrams
answer that in a minute — it is "why not something simpler, and what will bite me." If a written record
of the original migration discussion exists, replace §4 with it; that version will be better than mine.

## What I could not know, and what I did about it

I had no repo, no IaC, no dashboards — only your description. So the document contains **14 labelled
assumptions (`[A-1]`…`[A-14]`)** with a register at the end, and I did not invent a single number about
your system. Two of them are load-bearing enough to check this week:

- **`[A-12]` — does an idempotency check exist before dispatch?** EventBridge gives no exactly-once
  guarantee, so without it every retry is a possible duplicate SMS or email to a real person. If this
  is missing, the new architecture is *less* reliable than the cron it replaced.
- **`[A-6]` / `[A-11]` — are DLQs configured on every rule target, is DLQ depth alarmed, and where do
  failures *inside* a function go?** The target DLQ does not catch those. An unalarmed DLQ is a silent
  data-loss buffer with a 14-day fuse.

## The risk I would put in front of the team first

**Silent drop (R-1).** An event whose `channel` matches no rule is discarded with no error anywhere —
no exception, no metric, no log. A typo, or publishing a new channel value before its rule ships, and
notifications simply stop existing. It is the most surprising failure mode in this architecture and
worth a catch-all rule plus a published-vs-triggered divergence alarm. §6.4 gives the ordering that
avoids it when adding a channel: rule first, publish second.

## Open questions I need answers to (they're listed in the document too)

1. **Target dispatch latency per channel** (p95 publication → provider acceptance), and is it measured?
   RNF-5 currently has no number, which means nothing can regress against it.
2. **Where are notification preferences and opt-outs enforced** — producer, function, or provider? No
   component in the architecture owns them, so either they live outside this system or nothing does.
3. **Volume, average and peak per channel.** Three risks (concurrency stampede, cold start, payload
   size) are unrated without it, and the cost comparison against the old pod is unprovable.
4. **Did the migration deliver the expected cost change?** The before/after figure is the single most
   persuasive line this document could carry, and I left it blank rather than guess.
5. **Any per-recipient ordering requirement?** If a "cancelled" must never overtake a "confirmed", the
   current design does not guarantee it and §4's conclusion changes (FIFO queues or Kafka).
6. **Is the old cron pod fully decommissioned?** A dormant one is a live double-send risk.
7. **Who owns each channel** — on-call, provider account, cost? §6 assumes someone is named.

## Caveats

- **§7 Lessons learned is a draft I derived from the architecture, not from your team.** The lessons a
  team actually trips over are the most valuable thing in a retrospective document and they cannot be
  inferred. Please overwrite that section with the real ones — the mid-migration surprises, the thing
  that took a week longer than expected.
- **Provider names, repo paths, dashboard links, and the author field are placeholders.** The Related
  documents block at the top is deliberately empty for you to fill; a technical doc with no links to
  the live system goes stale in a sprint.
- **AWS facts are verified** against current AWS docs (cited in §References, checked today). Worth
  noting one correction: the `PutEvents` limit is now **1 MB total entry size**, not the 256 KB most
  blog posts and older docs still repeat. Retry policy ranges (`MaximumEventAgeInSeconds` 60–86,400,
  `MaximumRetryAttempts` 0–185) are verified as *configurable ranges*; what your rules actually set is
  `[A-10]`, and I did not assume the AWS defaults were chosen deliberately.
- **Diagrams are Mermaid** (one static component view, one dynamic sequence, plus a small "before" view
  of the cron for contrast). They render in GitHub, GitLab, and Notion; if your wiki does not support
  Mermaid, tell me and I will export or restate them.
