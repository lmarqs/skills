# Review: payments-runbook.md

**Verdict: not ready to share.** It contradicts itself on two facts an on-call engineer would act on: whether rollback is automatic, and what the processor timeout is. It also puts the migration warning after the rollback command. Someone following it top to bottom during an incident could roll back over a schema change before they reach the warning.

## Blocking issues (fix before sharing)

1. **The heading "Rollback is automatic" contradicts its own body.** The section tells the reader to run `kubectl rollout undo` by hand. A reader who skims headings during an incident will assume nothing needs doing. Rename it to something like "Roll back a bad deploy".

2. **The migration check comes after the rollback command.** "Rollback is automatic" (line 16) gives the command. "Rolling back" (line 32), two sections later, says to page on-call *before* rolling back if a migration ran, then adds "Obviously you should check this first." Merge the two sections into one ordered procedure with the check as step 1:
   1. Check whether the bad deploy ran a database migration. *(Say how: which command, table, or deploy log shows it.)*
   2. If it did, stop and page the payments on-call. `rollout undo` does not revert migrations, and the old code may not be able to read the new schema.
   3. Otherwise, from the ops bastion, run `kubectl rollout undo deployment/payments` *(add the namespace/context if it isn't the default)*.
   4. Watch *(name the dashboard and link it)* for *(the metric and the healthy value)*.
   5. If it hasn't recovered within *(N minutes)*, *(what to do: escalate to whom, by what channel)*.

3. **The processor timeout is given as 30 s and 60 s.** Architecture (line 13) says 30 seconds. The config example (line 29) and Notes (line 40) say 60. Find out which is right and state it once. If 60 is only an illustrative value in the example, say so, or use the real value.

4. **The recovery guidance has no threshold and no next step.** "It should recover within a few minutes but sometimes it doesn't" gives the reader no point at which to escalate and no instruction for when they do. See step 5 above.

## Clarity issues

5. **One component has three or four names.** "The worker" (lines 8 and 41), "the consumer" (line 12), and "the job runner" (line 14). The reader can't tell whether these are one process or several. If they are one, pick a name, ideally the deployment or pod name the reader will see in `kubectl`, and use it everywhere. If they are separate, say what each one does.

6. **"It times out" (line 13) has an unclear subject.** Is it the consumer's call to the processor or the processor itself? Also say what happens after retries run out (dead-letter queue? failed charge?), and whether retrying a charge can double-charge the customer. That is the first question a payments on-call will ask. *(I can't tell from the doc whether charges are idempotent. Confirm it and state it.)*

7. **The Overview is history, not orientation.** Lines 5 to 7 cover why payments left the monolith and the decision to use Kubernetes. A runbook reader needs to know what the service does, who owns it, and where it runs. Drop the history or move it to a design doc. Replace the section with: purpose, owning team, on-call contact or rotation, cluster/namespace, links to the dashboard and repo. "This section will discuss" is filler. Just say it.

8. **The Configuration section gives a rule without its reason or effect.** "Set the retry count in the YAML file, not in the Helm chart" needs a reason (does Helm override it? is the Helm value ignored?). It also needs to say what it takes for a change to apply: a redeploy, a restart, or a hot reload.

9. **The Notes section adds nothing new.** The timeout repeats line 29 (and conflicts with line 13). "The worker is the most important part of the system" is an unsupported claim with no action attached. Delete the section, or turn it into something actionable (for example, "If the worker is down, charges queue up but are not lost," if that's true).

## Wording

- Cut "Obviously" (line 36), "It's worth noting that" (line 40), "Remember" (line 40), and "After a lot of discussion" (line 7). They add no information, and "obviously" makes a reader who missed the step feel at fault.
- "check the dashboard" (line 19): which dashboard? Link it.

## Missing content a runbook reader will need

- How to tell a deploy is bad: symptoms, alerts, error-rate threshold.
- Access prerequisites: how to reach the ops bastion and which kube context/namespace to use.
- The payments on-call contact: rotation name, pager service, or channel.
- How to confirm whether a migration ran (needed for step 1 above).
- Restoring receipts or reprocessing failed charges after recovery, if that is ever needed.

## Suggested structure

1. Payments service: what it is, owner, on-call, links
2. Components: API → queue → worker → card processor / ledger / receipts, one name each
3. Detecting a bad deploy
4. Roll back a bad deploy: the ordered steps above
5. Configuration: where, why, and how changes take effect
