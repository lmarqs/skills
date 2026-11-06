# Review: `payments-runbook.md`

**Verdict: not ready to share.** Someone following the rollback steps in order can run
`kubectl rollout undo` before reaching the migration warning, and that can break payments. The
doc also gives two different processor timeouts. Fix the four blockers below first. The rest
are smaller improvements.

## Blockers

### 1. The rollback steps come before the warning that should stop them

"Rollback is automatic" (line 16) tells the reader to run `kubectl rollout undo`. The warning
that a migration makes this unsafe is three sections later, under "Rolling back" (line 32). An
on-call engineer in the middle of an incident runs the first command they find. If the bad
deploy ran a migration, the old code may not be able to read the new schema, and rolling back
then makes the outage worse.

**Fix:** Combine the two sections into one rollback procedure and put the migration check first:

1. Check whether the bad deploy ran a migration (say exactly how: which command, table, or CI
   log to look at).
2. If it did, page payments on-call (say how: PagerDuty service name or rotation link) and stop.
3. If it did not, run `kubectl rollout undo deployment/payments` from the ops bastion.
4. Verify (see blocker 3).

Delete "Obviously you should check this first." The reader needs to know how to check, and
"obviously" doesn't tell them.

### 2. The heading "Rollback is automatic" is wrong

The section describes a manual command. A reader who skims headings will assume nothing needs
doing. Rename it to something like "Roll back a bad deploy".

### 3. The processor timeout is given as both 30 and 60 seconds

- Architecture (line 13): "times out after 30 seconds"
- Configuration (line 29): `processor_timeout_seconds: 60`
- Notes (line 40): "the processor timeout is 60 seconds"

Find the real value and state it in one place. Better still, point to the config key instead
of repeating the number, so the doc stays correct when the value changes.

### 4. Rollback has no success check and no next step if it fails

"Check the dashboard. It should recover within a few minutes but sometimes it doesn't." does
not say:

- which dashboard (give a link),
- what "recovered" looks like (which metric, what threshold),
- how long to wait before treating it as failed,
- what to do when it doesn't recover (escalate to whom, or what to try next).

## Other issues

5. **One component, three names.** "The worker" (lines 8, 41), "the consumer" (line 12) and
   "the job runner" (line 14) all seem to be the process that reads from the queue. If they
   are the same thing, use one name. If they are different, say what each one does. As written,
   a reader can't tell whether receipts are sent by the charge processor or by something else.

6. **The Overview is history, not orientation.** The monolith split and the move to Kubernetes
   don't help anyone running the service. Replace it with what the service does, who owns it,
   how to reach on-call, and links to the dashboard, repo and alerts. Move the history to an
   ADR or a "Background" link if you want to keep it. Also cut "This section will discuss".

7. **Retries may double-charge.** "Times out ... and the charge is retried" (line 13), with
   `retries: 3`. If the processor accepted the charge but replied slowly, a retry can charge
   the customer twice. If charges carry an idempotency key, say so. If they don't, readers
   need to know that this is a known risk and how to find duplicate charges. Confirm which one
   is true before sharing.

8. **The Configuration section leaves out the reason and the next step.** It says to set the
   retry count in the YAML file and not in the Helm chart, but not why (does Helm override it?
   is the YAML file the source of truth?). It also doesn't say how a config change reaches
   production (redeploy? restart? hot reload?).

9. **Missing access details for the kubectl command.** There's no cluster context or namespace,
   and nothing on how to get onto the ops bastion or what permissions are needed. Add
   `-n <namespace>` / `--context <cluster>` or say where to find them.

10. **Notes adds nothing.** It repeats the timeout (wrongly, if 30s is correct) and says "the
    worker is the most important part of the system" without saying what follows from that.
    Delete the section, or turn that sentence into something the reader can act on (for example,
    "if the worker is down, no charges are processed. Treat it as SEV1").

11. **The title doesn't say it's a runbook.** "Payments Service" reads like an overview page.
    Call it something like "Payments Service Runbook" and put the incident procedures near the
    top, since that's what people will open it for.

## Suggested structure

```
# Payments Service Runbook
Owner, on-call rotation, dashboard, repo, alerts (links)

## What it does
API -> queue -> worker -> card processor -> ledger; worker also sends receipts.
Processor timeout and retry behaviour (with config keys), idempotency.

## Roll back a bad deploy
1. Check for a migration ... 2. If yes, page ... 3. Undo ... 4. Verify ... 5. If not recovered ...

## Change configuration
Where settings live, why the YAML file wins over Helm, how changes roll out.
```

## Open questions for the author

- Which timeout is correct, 30s or 60s?
- Are worker, consumer and job runner the same process?
- How does someone check whether a deploy ran a migration?
- Are retried charges idempotent?
