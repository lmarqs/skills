# Review: `payments-runbook.md`

**Verdict: not ready to share.** Three problems would hurt an on-call engineer mid-incident:

1. The rollback steps are split across two sections. The migration check, which has to come
   *before* the rollback, sits two sections *after* the rollback command.
2. The text gives two processor timeouts: 30 seconds under Architecture, 60 seconds under
   Configuration and Notes.
3. The heading "Rollback is automatic" sits above manual rollback steps.

The page also never says who it is for, so the findings below assume the most likely reader:
an on-call engineer who knows Kubernetes but not the payments service. If the reader is
someone else, tell me and I'll re-check the explicitness findings (C1, L6).

I can't verify facts about your system. Questions only you can answer are marked **Author
decides**.

Findings are ordered contract, then structure, then local, so the biggest problems come first.

---

## Contract

**C1 Reader stated.** The page never names its reader. "Page the payments on-call" suggests
the reader is *not* payments on-call, while "the ops bastion" and "the dashboard" assume
someone who already knows the payments setup.
Test: no sentence or `audience` field names the reader.
Rewrite (frontmatter):

```markdown
---
description: How to roll back a bad deploy of the payments service, and where its settings live.
audience: Engineers on call for production. Know Kubernetes and kubectl; have not worked on payments.
---
```

**C2 / C4 Question and answer first.** A runbook answers "How do I recover from a bad
payments deploy?" The opening paragraph gives the 2023 history of the service instead. The
answer (check for a migration, then run `kubectl rollout undo`) first appears in the third
section, and half of it is in the fifth.
Test: after the first paragraph, the reader knows why payments left the monolith but not how
to roll it back.
Rewrite (opening paragraph):

> To roll back a bad payments deploy, first check whether the deploy ran a database
> migration. If it did, page the payments on-call before doing anything else. If it did not,
> run `kubectl rollout undo deployment/payments` from the ops bastion. This page covers
> rollback and the service's configuration file.

**C3 Scope stated.** Nothing says what the page covers or where the rest lives, such as
incident communication, deploying, or the reason for the 2023 split.
Test: there is no scope line and no out-of-scope line.
Rewrite: put the scope sentence in the opening paragraph above. Add one line saying where
anything left out lives, for example "Service history and design decisions: <link>."

**C6 One kind of need.** The page mixes an explanation (Overview: why the service was split
out and why Kubernetes was chosen), reference (Architecture, Configuration) and a how-to
(the two rollback sections). The history doesn't help someone in the middle of a rollback.
Test: Overview is explanation, Architecture and Configuration are reference, and Rollback is
a how-to.
Rewrite: move the history paragraph to a design doc or ADR and link to it. Keep the rollback
how-to at the top and a short reference section after it.

## Structure

**S1 Headings summarize.** Read alone, the headings are "Overview, Architecture, Rollback is
automatic, Configuration, Rolling back, Notes". Rollback appears twice, with Configuration
in between, and "Overview" and "Notes" say nothing about their content.
Test: the headings alone don't form a correct outline, and the one heading that makes a
claim makes a false one (see S2).
Rewrite (outline):

```markdown
## Roll back a bad deploy
### 1. Check whether the deploy ran a migration
### 2. Undo the rollout
### 3. Confirm recovery
## How a charge flows through the service
## Configuration lives in `config/payments.yaml`
```

**S2 Heading kept by body.** "## Rollback is automatic" is followed by "Run `kubectl rollout
undo deployment/payments` from the ops bastion". That is a manual step.
Test: the first instruction under the heading contradicts it.
Rewrite: "## Roll back a bad deploy". **Author decides:** if part of the rollback really is
automatic, such as a failed readiness probe halting the rollout, say which part, and say
when the manual command is still needed.

**S2 Heading kept by body.** "## Overview" is followed by "This section will discuss the
payments service and how we got to the current setup", and the paragraph is history. The one
overview sentence ("The worker processes charges from the queue and writes results to the
ledger") is its last.
Test: the first sentence describes the document rather than the service, and the paragraph
is mostly history.
Rewrite: drop the heading and use the answer-first opening under C2 / C4. Move the worker
sentence into the Architecture section.

**S5 / S7 One place per fact; conditions before the instruction.** The rollback procedure is
split. "Rollback is automatic" says to run the undo. Two sections later, "Rolling back" says
"If the bad deploy ran a migration, page the payments on-call before rolling back". A reader
working top to bottom runs the undo before reaching the condition that should have stopped
them.
Test: the "if" clause comes after the imperative it governs, and in a different section.
Rewrite: merge both sections into the numbered "Roll back a bad deploy" outline above, with
the migration check as step 1.

**S5 / S6 One place per fact; no contradictions.** The processor timeout appears three times
with two values:
- Architecture: "it times out after 30 seconds"
- Configuration: `processor_timeout_seconds: 60`
- Notes: "Remember the processor timeout is 60 seconds."

Test: collect every claim about the processor timeout. They disagree.
Rewrite: **Author decides** which value is true. State it once, in Configuration, next to
the key that sets it. In Architecture write "it times out after `processor_timeout_seconds`
(see Configuration)". Delete the Notes line.

**S3 Headings specific, never empty.** "## Notes" holds two unrelated sentences. One repeats
the timeout and the other is an unsupported ranking (see L11).
Test: cut down to two words, the heading names no topic.
Rewrite: delete the section once its timeout line moves to Configuration.

## Local

**L5 One name per concept.** Architecture names three actors: "the consumer", "the job
runner" and, from Overview, "the worker". Each is said to take from the queue or do the
queue's work. The reader can't tell whether these are one process or three, and that
decides what they restart or check.
Test: three names, and no sentence says whether they are the same thing.
Rewrite: **Author decides.** If they are one process: "The worker takes each charge from the
queue, calls the card processor, writes the result to the ledger and sends the receipt." Use
"worker" everywhere after that. If they are separate, name each once and give each its own
sentence.

**L1 Pronoun has one antecedent.** "If the processor is slow, it times out after 30 seconds
and the charge is retried." "It" could be the processor or the consumer. The consumer's call
is what actually times out.
Test: two candidates.
Rewrite: "If the card processor is slow, the worker's call to it times out after
`processor_timeout_seconds` and the worker retries the charge, up to `retries` times."
(The link to `retries` is an inference. Confirm that the two settings relate this way.)

**L1 Pronoun has one antecedent.** "Obviously you should check this first." "This" could
mean whether a migration ran, whether the old code can read the new schema, or the
dashboard. The sentence also doesn't say *how* to check.
Test: no single antecedent, and no method.
Rewrite: "Check whether the deploy ran a migration: <command or place to look>." **Author
decides** the method.

**L6 Terms defined at first use.** For a reader new to payments, "the ops bastion", "the
dashboard", "the ledger" and "the queue" are each used with "the", as if the reader already
knows which one.
Test: each is used without a name, link or location.
Rewrite: link each at first use, e.g. "check the [payments health dashboard](<url>)" and
"from the ops bastion (`ssh <host>`)."

**L12 Hedge stated as a condition.** "It should recover within a few minutes but sometimes
it doesn't." The reader isn't told how many minutes, what "recovered" looks like, or what to
do if it doesn't happen.
Test: the hedge names neither when the claim fails nor a next step.
Rewrite: "Within N minutes, <metric> on the dashboard returns to <value>. If it hasn't
after N minutes, page the payments on-call." **Author decides** N and the signal.

**L10 Concrete values.** "a few minutes" and "the dashboard" have the same problem as L12.
The rewrite above fixes both.

**L13 No sentences about the document.** "This section will discuss…" and "It's worth noting
that…" describe the text rather than the service.
Test: the subject of each is the document.
Rewrite: delete both openers. The C2 / C4 rewrite already replaces the first.

**L14 No condescension.** "Obviously you should check this first." If the check were obvious,
the runbook wouldn't need to say it. A stressed on-call reader who missed it feels blamed.
Test: contains "obviously".
Rewrite: the L1 rewrite above, without "obviously".

**L11 Every sentence earns its place.** "the worker is the most important part of the
system." The sentence gives no reason and no action, and nothing in the runbook depends on
it.
Test: delete it and the reader loses nothing they can act on.
Rewrite: delete it. If it implies an action (for example, "check the worker first when
charges stall"), write that action instead.

**E2 Contrast is needed.** "set the retry count in the YAML file, not in the Helm chart". The
reader learns the Helm chart is wrong but not why. Does a Helm value get ignored, get
overwritten on deploy, or override the YAML? Each answer means something different to the
reader.
Test: the text doesn't say what goes wrong with the Helm chart.
Rewrite: if readers really do reach for the chart: "Set the retry count in
`config/payments.yaml`. A `retries` value in the Helm chart <is ignored / is overwritten by
the YAML on deploy>." **Author decides** the reason. If they don't reach for the chart,
drop the contrast: "Set the retry count in `config/payments.yaml`."

**E1 Every detail serves the point.** The example is meant to show where the retry count
goes, but it also sets `processor_timeout_seconds: 60`. That extra line is where the
contradicting 60-second value comes from (S5 / S6).
Test: delete the timeout line and the example still shows where the retry count goes.
Rewrite: either show only `retries: 3`, or say the example shows both settings and keep the
timeout value consistent with the single value you settle on.

---

## Suggested shape after fixes

```markdown
---
description: How to roll back a bad deploy of the payments service, and where its settings live.
audience: Engineers on call for production. Know Kubernetes and kubectl; have not worked on payments.
---

# Payments service runbook

To roll back a bad payments deploy, first check whether it ran a database migration. If it
did, page the payments on-call. If not, run `kubectl rollout undo deployment/payments` from the
ops bastion. This page covers rollback and configuration. Service history: <link>.

## Roll back a bad deploy
### 1. Check whether the deploy ran a migration
### 2. Undo the rollout
### 3. Confirm recovery within N minutes

## How a charge flows through the service

## Configuration lives in `config/payments.yaml`
```
