# Review: `payments-runbook.md`

**Verdict: not ready to share.** Fix two problems before anyone on call uses it:

1. **The rollback steps are in the wrong order.** "Rollback is automatic" tells the reader to run
   `kubectl rollout undo`. The migration check that must come first appears two sections later,
   under "Rolling back". An engineer who follows the page from the top runs the undo before they
   read the warning, and the old code may then fail to read the new schema.
2. **The processor timeout has two values.** "Architecture" says 30 seconds. "Configuration" and
   "Notes" say 60. I cannot tell which is true. You need to confirm the value.

The findings below run from contract to structure to local issues, in the order they appear in
the text. Each one quotes the passage, names the criterion and its test, and gives a rewrite.
Your terms (`kubectl rollout undo`, ops bastion, payments on-call) stay as they are.

---

## Contract

**C1 Reader stated.** The page never says who it is for. "Overview" reads as background for a
new team member ("how we got to the current setup"). "Rollback is automatic" assumes someone on
call with bastion access.
Test: no sentence or `audience` field names the reader.
Rewrite (I inferred the reader, so please confirm):

```markdown
---
description: How to roll back a bad deploy of the payments service.
audience: Engineers on call for payments. Know kubectl and have ops bastion access; may never have deployed payments.
---
```

**C2 / C4 Question stated, answer first.** The reader's question is probably "A payments
deploy went bad. How do I roll it back safely?" The first paragraph is about the 2023 split from
the monolith, and it never mentions rollback.
Test: after the first paragraph, the reader still does not know the main point.
Rewrite of the opening paragraph:

> Roll back a bad payments deploy with `kubectl rollout undo deployment/payments` from the ops
> bastion. First check whether the deploy ran a database migration. The undo does not revert
> migrations, so if one ran, page the payments on-call before you roll back.

**C3 Scope stated.** Nothing says what the page covers or leaves out.
Test: there are no lines to point to.
Rewrite, after the opening paragraph: "This page covers rolling back a deploy and the settings
that control retries and timeouts. It does not cover forward fixes, migration repair or incident
communication." Adjust this to match what you actually leave out.

**C6 One kind of need.** The page mixes four kinds of document. "Overview" is explanation
(history). "Architecture" is explanation. "Configuration" is reference. The two rollback sections
are a how-to. Under pressure, an on-call reader has to skip half the page to reach the steps.
Test: each section is classified differently.
Rewrite: make the page a rollback how-to. Move the history and architecture to a service README
and link to it in one line. Keep the configuration only if a rollback step needs it.

---

## Structure

**S1 Headings summarize.** Read on their own, the headings are "Overview, Architecture, Rollback
is automatic, Configuration, Rolling back, Notes". They do not tell the reader how to roll back,
and they split rollback into two sections with an unrelated one between them.
Test: the headings alone do not form a correct outline.
Rewrite of the outline:

```markdown
# Rolling back the payments service
## Check whether the deploy ran a migration
## If it did, page the payments on-call first
## Roll back with `kubectl rollout undo`
## Confirm recovery on the dashboard
```

**S2 Heading kept by body.** "## Rollback is automatic" is followed by "Run `kubectl rollout
undo deployment/payments` from the ops bastion". That is a manual step.
Test: the body contradicts the heading.
Rewrite: "## Roll back with `kubectl rollout undo`"

**S2 Heading kept by body.** "## Overview" opens with "This section will discuss the payments
service and how we got to the current setup" and ends with a sentence about the worker. The
section gives history, not an overview of the service.
Test: the first sentence describes the section instead of delivering it.
Rewrite: delete the section from the runbook (see C6), or rename it "## Why payments runs on
Kubernetes" in the README it moves to.

**S5 / S7 One place per fact; condition before instruction.** The rollback procedure is split
between "Rollback is automatic" (the command) and "Rolling back" (the migration check that has
to happen first). Within "Rolling back", "Obviously you should check this first" comes after the
instruction it governs.
Test: the condition "if the bad deploy ran a migration" appears after the command it should
gate, and in a separate section.
Rewrite: merge both sections into one numbered procedure:

```markdown
## Roll back a bad deploy

1. Check whether the bad deploy ran a database migration. `kubectl rollout undo` does not
   revert migrations, and the old code may not be able to read the new schema.
2. If it ran a migration, page the payments on-call and wait for them before you continue.
3. From the ops bastion, run `kubectl rollout undo deployment/payments`.
4. Watch <dashboard link> until <metric> returns to <normal value>.
```

Step 1 also needs the *how*: the page never says how to tell whether a deploy ran a migration.
Add the command or the place to look.

**S6 No contradictions.** "Architecture": "it times out after 30 seconds". "Configuration":
`processor_timeout_seconds: 60`. "Notes": "the processor timeout is 60 seconds."
Test: the three statements about the processor timeout do not agree.
Rewrite: confirm the real value, state it once (see S5 below), and remove the others.

**S5 One place per fact.** The processor timeout is stated three times, and that repetition is
how the contradiction above got in.
Test: searching for "timeout" finds three claims.
Rewrite: keep it in "Configuration" only, and drop the "Notes" sentence.

**S3 Headings never empty.** "## Notes" names no topic. Its two sentences repeat the timeout and
make an unsupported ranking claim.
Test: cut to two words, the heading carries no topic.
Rewrite: delete the section (see S5 and L11).

**S4 One topic per paragraph.** The "Overview" paragraph covers the 2023 split, then ends with
"The worker processes charges from the queue and writes results to the ledger", which is an
architecture fact.
Test: the first sentence does not predict the last.
Rewrite: move the worker sentence into "Architecture" (or the README).

---

## Local

**L5 One name per concept.** "The worker" (Overview), "the consumer" (Architecture) and "the job
runner" (Architecture) could be one process or three. "The job runner also sends receipts" uses
"also" as if it were the same component as the consumer.
Test: three names, and the reader cannot tell how many things they refer to.
Rewrite: if they are one process, use your team's name for it everywhere ("The worker picks them
up and calls the card processor… The worker also sends receipts."). If they are separate, say so
and give each one a single role.

**L1 Pronoun has one antecedent.** "If the processor is slow, it times out after 30 seconds".
"It" could be the processor or the consumer.
Test: two candidates.
Rewrite: "If the card processor is slow, the consumer's call to it times out after <N> seconds
and the charge is retried."

**L1 Pronoun has one antecedent.** "It should recover within a few minutes" could refer to the
deployment, the dashboard or the service. "Obviously you should check this first": "this" could
be the migration, the schema or the on-call page.
Test: more than one candidate each time.
Rewrite: covered by the numbered procedure under S5 / S7 above.

**L10 / L12 Concrete values; hedges as conditions.** "It should recover within a few minutes but
sometimes it doesn't."
Test: "a few minutes" has no value, and "sometimes it doesn't" names neither the condition nor
what to do next.
Rewrite: "Error rate on <dashboard> returns to normal within <N> minutes. If it has not after
<N> minutes, page the payments on-call."

**L6 Terms defined or linked at first use.** "The dashboard" does not say which dashboard. "The
ops bastion" has no link or access note. For the inferred reader, who may never have touched
payments, these are the two terms that block the procedure.
Test: the reader cannot find either from the page.
Rewrite: link the dashboard by name and URL, and link the bastion access doc.

**L13 No sentences about the document.** "This section will discuss…", "It's worth noting
that…".
Test: the subject is the document, not the service.
Rewrite: delete both phrases. The first sentence disappears with the "Overview" section, and the
second becomes the claim itself (but see L11).

**L14 No condescension.** "Obviously you should check this first."
Test: "obviously" is present. A reader who missed the check is told they should have known.
Rewrite: covered by step 1 of the numbered procedure.

**L11 Every sentence earns its place.** "The worker is the most important part of the system."
The page does not say why, or what the on-call engineer should do differently because of it.
Test: delete it, and no step changes.
Rewrite: delete it, or replace it with the consequence ("If the worker is down, charges queue
but are not processed; check it first.") if that is the intended point.

**L9 Justified passive.** "Database migrations are not undone by the rollout undo."
Test: the actor (`kubectl rollout undo`) is known, and the passive pushes it to the end.
Rewrite: "`kubectl rollout undo` does not revert database migrations."

**E1 Every detail in the example serves its point.** The YAML example illustrates "set the retry
count in the YAML file, not in the Helm chart", but it also carries
`processor_timeout_seconds: 60`. That line is not needed for the point, and it is the source of
one side of the S6 contradiction.
Test: delete the timeout line, and the lesson is unchanged.
Rewrite:

```yaml
retries: 3
```

State the timeout in prose, once, with the confirmed value.

---

## Questions for you before sharing

- Is the processor timeout 30 or 60 seconds?
- Are the worker, the consumer and the job runner one process?
- How does an on-call engineer tell whether a deploy ran a migration?
- Which dashboard, and what does "recovered" look like on it?
- Does `kubectl rollout undo deployment/payments` need a namespace or context from the bastion?
  I am inferring this from the bare command. I have not verified it.
