# What I did, and what I need from you

Written as the retrospective shape (a technical document for something already built), not an RFC:
you are recording a decision, not making one. The document is in `document.md`.

**The honest headline: the structure is done, the facts are not.** I had one paragraph and no access to
the repository, the infrastructure code, the dashboards, or the incident history. So I wrote the
skeleton a newcomer needs and I did not fill it with plausible-looking numbers. Every claim carries one
of four labels — `[platform]`, `[inferred]`, `[assumed]`, `[measured]` — and **nothing is `[measured]`
yet**. The 23 open questions at the end are the work that turns it into something you can hand over
without a caveat. Most of them you can answer in an afternoon from the code and the console.

## What I reclassified

You described the change as "monolithic cron in a pod → EventBridge triggering Lambdas per notification
type". Sorted, that is a set of prior decisions and one document goal, not a set of requirements:

| What you said | How I filed it | Why |
| --- | --- | --- |
| EventBridge as the bus; Lambda as the runtime; one function per notification type | **Prior decisions**, each with a cost to reverse | Decided inside the team. None of them excludes an alternative, so each has a row in the comparison section with alternatives beside it |
| AWS; Kubernetes for everything else | **Prior decisions** predating the migration | Not reopened, but recorded, because the second runtime is a cost the migration paid |
| "Event-driven flow" | **The design**, not a requirement | The requirement underneath it is "deliver on the event, not on the tick" (N1), and I wrote it that way so it can be argued with |
| "So new folks can understand and maintain it" | **The goal of this document**, not a goal of the system | It is the audience line at the top and the "First week for a new maintainer" section. The system's own goals had to be reconstructed from the topology — flagged as such, and Q5 asks for what you actually wrote down at the time |

I also had to **invent the motivations** (lower latency, channel isolation, independent deploy and
scale). They follow from what you built, but they are my reconstruction, not your record. If a design
note or migration ticket exists, it beats my guess — Q5, Q22.

## Where I pushed back, and what I added that you did not ask for

Three things, all recorded in the document rather than quietly designed in:

1. **"We migrated to event-driven" and "it was a cron" cannot both be fully true.** A cron fires on a
   clock; events fire on facts. Any notification that is inherently time-based (a reminder 24h ahead, a
   payment due in three days) has no fact to react to at the moment it must be sent. So either every
   notification you send is reactive, or something still runs on a clock (a scheduled rule, EventBridge
   Scheduler, a surviving job) and publishes events for what is due. I assumed the second and drew it as
   a dashed component in Figure 1. **This is the single question most worth answering before anyone else
   reads the document** (Q18), because it adds or removes a component with its own failure modes.
2. **Two requirements you did not ask for: N3 (idempotency) and F4 (consent and preference check).**
   Both are in because the roles that pay for their absence are the person receiving the notification
   and the on-call engineer. N3 is not defensive engineering: EventBridge can invoke a target twice for
   one event, and Lambda's async queue is eventually consistent, so duplicates arrive *even when your
   code is correct* — verified against AWS docs, cited in Sources. Without an idempotency key, someone
   eventually gets two one-time codes. F4 is there because messaging is one of the few areas where the
   law reaches into the architecture, and I could not fill the constraints table at all (see below).
   If you think either is out of scope, say so and I will move it to a stakeholder conflict in the
   document rather than delete it.
3. **The comparison section is mine, and it names an option nobody proposed.** A retrospective still
   benefits from recording what the shape was chosen over, because a maintainer who does not know that
   cannot tell load-bearing from habit. Eight options, including the baseline (keep the cron), the
   smallest change, and buying a managed notification platform. Two conclusions worth your attention:
   the built shape is sound on what the migration was for, and thin on backpressure — and the nearest
   cheap improvement (a queue between each rule and its function) needs nothing undone and can go one
   channel at a time.

## The gap I could not close at all

**The constraints table is empty, and it is the most consequential hole in the document.** Consent,
opt-out, unsubscribe, SMS quiet hours, carrier rules, provider retry etiquette — all of these are
imposed from outside your organization, all of them can rule a design out, and none of them can be
guessed. I need the jurisdictions you send to (Q9) and the provider contracts (Q10). Until then, treat
everything the document says about retry behaviour as an engineering statement, not a compliance one.

## What I verified rather than assumed

The delivery semantics section is the one part of the document that is solid, because I checked it
against current AWS documentation on 2026-09-08 instead of writing from memory:

- EventBridge retries a target for up to 24 hours, then publishes `FailedInvocations` — and **may stop
  retrying early** if the target is throttling persistently.
- Lambda retries a function error **twice** (1 min, then 2 min); throttling and system errors go back on
  the queue for **up to 6 hours** with backoff from 1s to a 5-minute ceiling.
- On expiry or exhaustion, **Lambda discards the event**. And under sustained overload, events can be
  **deleted from the queue without ever reaching the function** — silent loss with no visible backlog.
  A dead-letter queue is the only thing that turns that into something you can alarm on.
- A publish call returning HTTP 200 is not an accepted event: entries fail individually inside a
  successful request, and an event sent to a bus that does not exist is dropped with a 200 and a
  `FailedEntryCount` of zero.
- Publish limit: 10 entries per request, under 1 MB total.

Figure 3 maps those into the five ways one notification can die, four of them silently.

## Assumptions stated in the document, most load-bearing first

| Assumption | Confirms/refutes | If wrong |
| --- | --- | --- |
| Something still runs on a clock to publish time-based notifications | Infrastructure code (Q18) | Figure 1 loses a component; the "what replaced the scheduling" section shortens to one line |
| Each function has a dead-letter queue, alarmed | Each function's async invocation config (Q14) | The top risk in the table is open, not mitigated, and improvement 1 becomes urgent |
| The bus is a custom bus, not the account default | EventBridge console (Q12) | Rules also see every AWS service event, which is noisier to reason about |
| A send-record store exists, with an idempotency check before the provider call | Function code (Q15) | Figure 2 is wrong and N3 is aspirational |
| The producer inspects `FailedEntryCount` and resends | Producer code (Q16) | Notifications are being dropped at the front door today |
| The old pod is gone entirely | Cluster workloads (Q7) | Scope section is wrong; a newcomer will assume something is retired that is not |
| Function names are `notify-email` / `notify-push` / `notify-sms` | Infrastructure code (Q12) | Cosmetic, but a newcomer greps for the wrong thing |

## What I would have asked you first, in this order

Because this was a one-shot run, these went into the document as labelled assumptions and into the open
questions table. If we were talking, I would have asked them one at a time, with the recommended answer
attached:

1. **What triggers time-based notifications now?** *My guess: a scheduled rule or EventBridge Scheduler
   publishes events for what is due.* Changes the component diagram.
2. **Do the functions have dead-letter queues, and are they alarmed?** *My guess: at most some of them
   do.* Changes whether the document describes a mitigated system or an exposed one.
3. **Is there an idempotency key and a send-record store?** *My guess: outcomes are recorded, the
   pre-send duplicate check is not.* Changes whether Figure 2 is accurate.
4. **Which consent/opt-out regime applies, and to which channels?** No guess offered; I do not know your
   jurisdictions. Changes whether F4 is a requirement or a wish.
5. **What did the old system's volume, latency, and schedule interval look like?** *My guess: retained in
   metrics for at least 30 days.* Turns the whole before-state from inference into measurement, and it
   is the only way to show the migration achieved anything.

## Caveats on using the document as-is

- **Do not hand it to a new joiner without Q1, Q7, Q14, Q18 answered.** Those four change what the
  document *says*, not just what it cites, and a newcomer cannot tell which parts to distrust.
- The diagrams are Mermaid and render inline; they are drawn from the described topology, so expect to
  correct them the first time someone traces a real notification through the code. Step 3 of the "first
  week" section makes that an explicit onboarding task.
- Component and function names are placeholders. Search for `notify-` before publishing.
- The section titled "Lessons the platform teaches" is deliberately *not* called "Lessons learned". What
  the team learned by doing the migration is the highest-value section for a newcomer and the only one
  that cannot be reconstructed. Q23 is a 30-minute conversation with the people who did it; do it soon,
  while they still remember.
