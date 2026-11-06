# Review: payments runbook

Not ready to share. An on-call engineer following it top to bottom would roll back before
checking for a migration, which the runbook itself says can leave the old code unable to read
the schema. It also gives two values for the processor timeout and calls a manual rollback
"automatic". Fix the four findings under "Contract" and "Structure" first; the local ones are
quick edits.

I assumed the reader is an engineer on call for payments during a bad deploy, since that is
what a runbook serves. If the team will use it as onboarding material instead, tell me and the
contract findings change.

## Contract

**C1/C2/C3 Reader, question and scope.** The text opens with "# Payments Service" and "This
section will discuss the payments service and how we got to the current setup."
Test: no sentence names the reader, what they already know, the problem the runbook solves, or
what it leaves out. The title describes a service, not a task.
Rewrite: add frontmatter and a title that names the task:

```markdown
---
description: How to roll back a bad deploy of the payments service.
audience: Engineers on call for payments. Know kubectl and have bastion access; may not know the payments internals.
---

# Rolling back a payments deploy
```

**C4/C6 Answer first, one kind of document.** The rollback command first appears in the third
section, after the service's 2023 history and its architecture.
Test: after the first paragraph the reader knows why payments left the monolith, and nothing
about what to do. Overview and Architecture are explanation; the rollback sections are a
how-to.
Rewrite: open with the procedure. Move the history and architecture to a separate explanation
doc and link it in one line; drop the history from the runbook entirely, since the on-call
engineer does not need it to roll back (C5).

## Structure

**S7/S5 The migration check comes after the rollback.** "## Rollback is automatic" says "Run
`kubectl rollout undo deployment/payments`"; two sections later, "## Rolling back" says "If
the bad deploy ran a migration, page the payments on-call before rolling back".
Test: the condition follows the instruction it governs, and the one procedure is split across
two sections with nearly the same heading. A reader who stops after the first one, as a
reader in an incident will, skips the check.
Rewrite: one section, condition first, as numbered steps:

```markdown
## Roll back

1. Check whether the bad deploy ran a database migration: <how to check>.
2. If it did, page the payments on-call (<how to page>) and wait for them before rolling
   back. `rollout undo` does not undo migrations, and the old code may fail to read the new
   schema.
3. From the ops bastion, run `kubectl rollout undo deployment/payments`.
4. Watch <dashboard name and link>. It recovers within <N> minutes. If it has not, <next step>.
```

**S2 Heading kept by body.** "## Rollback is automatic" is followed by "you need to roll back.
Run `kubectl rollout undo ...`".
Test: the body describes a manual rollback, so the first sentence breaks the heading's promise.
Rewrite: "## Roll back" as above.

**S6/S5 Contradiction: processor timeout.** Architecture says "it times out after 30 seconds";
the config example sets `processor_timeout_seconds: 60`; Notes says "Remember the processor
timeout is 60 seconds."
Test: the same fact appears in three places with two values. A reader cannot tell which is
true.
Rewrite: confirm the real value, state it once in Configuration, and delete the other two.

## Local

**L5 One name per concept.** The text names "the worker", "the consumer" and "the job runner".
Test: the worker "processes charges from the queue", the consumer "picks them up", and the job
runner "also sends receipts", which implies it is the component just described. The reader
cannot tell whether these are one process or three, which matters when deciding what a
rollback restarts.
Rewrite: pick the deployment's own name for it and use only that; if they are separate
processes, say so and say which ones `deployment/payments` covers.

**L10/L12 Values the reader needs to act.** "then check the dashboard. It should recover
within a few minutes but sometimes it doesn't."
Test: the reader does not know which dashboard, how long "a few minutes" is, or what to do when
it does not recover. "Page the payments on-call" and "check this first" have the same gap.
Rewrite: see step 4 above; name the dashboard, the time and the escalation.

**E1/E2 Config example.** "set the retry count in the YAML file, not in the Helm chart:" is
followed by an example that also sets `processor_timeout_seconds`.
Test: the timeout line does not serve the point about retries, and it carries the contradicted
value. The "not in the Helm chart" contrast is useful only if the reader is told what happens
when they set it there.
Rewrite: "Set the retry count in `config/payments.yaml`. A value in the Helm chart <is ignored
/ is overridden>." Show only `retries: 3`.

Also counted, smaller:

- L1, 2: "it times out" (the processor or the consumer?), "It should recover" (the deployment
  or the charge success rate?).
- L13, 2: "This section will discuss", "It's worth noting that".
- L14, 1: "Obviously you should check this first."
- S10, 1: the text ends on "the worker is the most important part of the system", which gives
  the reader nothing to do. Delete the Notes section; with the timeout stated once, nothing in
  it remains.
