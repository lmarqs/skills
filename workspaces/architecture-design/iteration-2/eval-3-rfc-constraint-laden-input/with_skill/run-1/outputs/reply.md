# What I did with your list, and what I need back

The RFC is in `document.md`. Status **proposed**, held there by three blocking questions. Read the
decision section and the three questions first; the rest supports them.

**One requirement in your list of six was a requirement.** "Every action in the admin panel has to end
up queryable by compliance" is the whole document. The other five were other kinds of thing, and
sorting them was most of the work.

## Reclassified

| You said | I filed it as | Why |
| --- | --- | --- |
| Must use Kafka, the platform team decided | **Prior decision**, not a constraint | A team inside the company decided it, so it does not exclude an option. Kafka gets a row in the tradeoff table and so does the no-broker alternative. It survived — see the pushback below |
| Endpoints follow the company API standard | **Prior decision** | Same test. Cost to reverse is low here, because this is a new surface with no clients |
| It should be fast | **Two non-functional requirements**, N1 and N2 | "Fast" was hiding a choice. Fast to record (latency added to a staff operator's click) and fast to query (how long an analyst waits) pull in opposite directions: cheap ten-year retention answers queries slowly, and an interactive store costs the most where the data is oldest. One number would have decided that silently |
| Test coverage above 90% | **Prior decision**, a delivery practice | Not a quality of the running system. Worth saying more bluntly: on this service coverage measures the wrong thing. A suite can execute every line of the recording path and still not prove an action survives a broker outage. The gate that matters is the fault-injection run in F2, and I put it in CI beside your coverage gate rather than instead of it |
| Must run on AWS | **Prior decision**, recorded as shared by all options | Reversing it is out of proportion to this decision, so it gets no row; the effect is that the managed services named are the AWS ones |
| Nice to have: a UI for browsing logs | **Wish** | Nothing fails if it never ships, so it left the requirements, became a pro for the options that deliver it, and sits in launch phase 3. Caveat below |

## Where I pushed back

**On Kafka's position in the path, not on Kafka.** The plain reading of "must use Kafka" is that the
admin panel publishes an event after committing the action. That loses actions in the window between
the commit and the publish — silently, and precisely during the crashes and broker maintenance an
auditor asks about. Two independent writes cannot be made atomic, so there is no mitigation for it;
it is in the table as a rejected row. The design writes the record into an outbox table inside the
action's own transaction and has a relay publish from there to Kafka. Your prior decision stands,
Kafka keeps its fan-out value for later consumers, and the failure mode is gone. If you want the
simpler thing, the no-broker row is right there and it is cheaper to operate — I kept Kafka on the
platform-team relationship, not on a requirement.

**On two requirements you did not ask for.** F4, that records cannot be altered by the people whose
actions they record, and F5, that reads of audit records are restricted and recorded. F4 serves the
auditor: without it the store is a convenience for compliance rather than evidence, since the same
production access that performs the actions can rewrite the record of them. F5 serves the data
protection officer, because before/after payloads are personal data. Both are recorded as stakeholder
conflicts in the decision, and both are conditional on B2 below. If compliance does not need them,
say so and the document shrinks a lot.

## Three questions I would have asked before designing anything

Each changes the decision, so each holds the status at proposed. My recommended answer is attached so
agreeing is cheap.

1. **B1 — which regulation, contract or policy sets the retention period, and how long?** Everyone
   assumes one exists; nothing cited it. My recommendation: get the citation from compliance before
   the cold storage tier is built, and design for ten years in the meantime. A period beyond about
   three years is what makes the two-tier store clearly cheaper than a single hot store; no obligation
   at all makes the smallest-change option competitive.
2. **B2 — does compliance need the record to be tamper-evident against engineering and administrator
   access, or is an append-only table in the panel's own database, with write grants revoked,
   acceptable?** This is the question that decides whether you need this document at all. My
   recommendation: assume yes, because "trust our access controls" is not an answer an auditor can
   verify — but ask, because if the answer is no, the smallest-change row in the tradeoff table meets
   your goals in days rather than weeks and this RFC should be replaced by a one-page decision. The
   record schema is identical either way, so nothing is wasted by asking late; it is just cheaper to
   ask now.
3. **B3 — does "every action" include reads of personal data, or only state changes?** Reads are
   often the audit question, and including them raises volume by an order of magnitude or more, which
   reopens the store choice. My recommendation: state changes for phase 1, and decide reads with
   compliance before phase 3.

A fourth, non-blocking but legal: an immutable record and an erasure obligation collide. The design
stores personal values encrypted under a per-subject key so that discarding the key removes the
readable content without breaking the record chain. I assumed that satisfies the obligation. Your
data protection officer should confirm before object lock is switched on.

## Assumptions you should check, in order of how much they would cost if wrong

The document contains **no measured numbers**. There was no codebase, dashboard, cost report or ticket
queue in front of me, so every figure is labeled *assumed* with you as its origin, and each names the
instrument that would replace it. This is the largest caveat in the whole document, and the first task
in the roadmap is the measurement pass. Specifically:

- **The panel writes to a single transactional database that can commit an extra row in the action's
  transaction.** The whole design rests on this. If it is false, the completeness story changes and
  the fail-closed variant becomes the only complete option. Five minutes with the schema settles it.
- **Action volume is in the low thousands per day with a business-hours peak.** This is why I chose a
  partitioned relational table over a search cluster or a document store — at that volume the cluster
  is answering a load a table handles without effort. Two orders of magnitude higher and the store row
  reopens. Thirty days of the panel's access log grouped by route and hour would settle it.
- **The inventory of state-changing actions is enumerable from the panel's routes.** This is the quiet
  failure mode: an action nobody listed is an action nobody records, and no reconciliation job can
  detect what was never in scope. The defense is a CI check that fails when a mutating route has no
  recording, and it is task 2.
- **N1's 10% latency band and N2's 5 s query target are both invented.** They exist so the recording
  path is not a free-for-all and so an analyst iterates within one sitting. Both are negotiable, and
  the confirmation step measures the baselines before they count as commitments.
- **Kafka's decision author and date, the API standard's author, and whether CI actually enforces the
  coverage gate** are all unattributed in my prior decisions table. Fill in the names; a prior decision
  without an author cannot be revisited.

## Two more caveats

**I renamed the thing.** You asked for an RFC for the "audit-log service"; the document is titled after
the problem — making admin panel actions answerable to compliance — because a title naming the product
decides the build-versus-buy question in the header. A bought audit product is a row in the table, and
it loses on retention pricing, not on principle.

**The UI is in phase 3, and that may be wrong.** Your compliance team's need is self-service, and raw
endpoints are self-service only for analysts who call APIs. I put a saved-query stopgap in phase 2 and
the browsing UI in phase 3, ahead of nothing except the retention tier. If the stopgap does not land
with the analysts, pull the UI forward — the decision section says so, and it is a two-way door.

**What can start now, before the three questions close:** measuring the panel's current latency,
enumerating the mutating routes, and building the outbox. Every surviving option shares that record
schema, and an action that happens today without being recorded cannot be recovered later. That
irreversibility is the reason not to wait on B1.
