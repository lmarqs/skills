I drafted `document.md` as a retrospective technical doc (context → architecture with static + dynamic
diagrams → risks → lessons learned → improvement points → version history), but I want to flag what it
is and isn't, since this is meant for onboarding and maintenance and a wrong assumption here is costly.

**What I had to work with:** just the one-paragraph description — cron-in-a-pod → EventBridge
triggering per-type Lambdas (email, push, sms) — already in production. No repo, ticket, dashboard, or
AWS access, and none were named in the task for me to treat as unavailable-but-known; they're simply
absent. So beyond that one paragraph, I don't know: the actual event bus/rule names, the Lambda function
names or repos, which provider each channel actually calls (SES/SNS/FCM/APNs/Twilio/etc.), whether a
DLQ, retry policy, or alarms are configured, what observability stack is in use, real traffic volume or
latency numbers, how the cutover was actually done, or anything the team learned from running it in
production so far.

**What I did instead of guessing:** I built the architecture and flow sections around the standard shape
this exact pattern takes (bus → rule-per-type → Lambda → provider → optional DLQ), and marked every part
of that beyond your one paragraph as **[inferred]** (a reasonable expectation, not confirmed) or **[not
verified — confirm]** (a real unknown). I deliberately left "Lessons learned" empty rather than invent
plausible-sounding incidents — that section only has value if it reflects what actually happened.

**Questions to close before this doc goes out to new hires:**

1. What are the real names of the event bus, the rules, and the three Lambda functions (and their
   repos)?
2. Which provider does each channel actually call (SES? SNS? FCM/APNs? a third-party vendor)?
3. Is a dead-letter queue configured per rule/Lambda, and is anything alerting on it?
4. What's the observability stack (CloudWatch, Datadog, something else), and where do the dashboards
   live?
5. Any real production incidents, DLQ replays, or provider throttling since go-live?
6. How was the cutover from the old cron done — big-bang, or a parallel/shadow period comparing outputs?
7. Are the three Lambda handlers idempotent against retries/replays?

I'd treat the current draft as a skeleton to hand to whoever built this, not as something to circulate
to new engineers as-is — the flagged sections are exactly where a maintainer could be misled if they're
taken as fact.
