**Verdict: Go.** Document is at `document.md`.

Pushback / reclassifications, upfront since they affect how much to trust the recommendation:

- **"12 seconds" and "finance team complains constantly" are unverified.** I had no access to the
  service's code, any APM/latency dashboard, or the actual complaint tickets — they're named in your
  message but not reachable from this session. I treated the 12s figure as given, not measured, and
  flagged it throughout rather than building the RFC as if it were confirmed data.
- **I didn't take "rewrite" as settled before picking the language.** The method this doc follows
  requires ruling out the prior question — is this actually a language problem, or is 12s coming from
  something a rewrite wouldn't fix (a slow query, serial I/O, no caching, an accidentally single-threaded
  pipeline)? Without profiling data I couldn't settle that, so I documented "optimize Python in place"
  as a real third alternative in the tradeoff table rather than silently accepting Rust-vs-Go as the
  whole decision space. I still answered the question you actually asked — the doc commits to Go — but
  the biggest assumption in it is that the 12s is genuinely CPU-bound rendering. That's why the roadmap
  puts a profiling spike first, before any rewrite code gets written.
- **Latency target (≤3s p95) is my assumption, not a stated SLA.** No target was given; I picked
  something clearly better than 12s and said so inline. Worth confirming with finance — if the real pain
  is a UI timeout at some other threshold, or specifically about batch/month-end volume rather than a
  single invoice, the requirement (and possibly the decision) could shift.
- **Concurrency profile is unknown** — whether generation is on-demand, batched, or both changes how much
  Go's GC-under-load risk actually matters. Called out as an open question, not resolved.
- **Scope of "Go or Rust"**: I kept the language choice to exactly those two as you asked; I did not
  smuggle in Node/Java as alternatives. That's a deliberate scoping choice on my part, noted as
  out-of-scope in the doc so it doesn't read as an oversight.

Net: Go is the recommendation, made and owned in the doc (autocratic, as you asked for one pick), with
the specific condition that would flip it to Rust spelled out ("The decision" section). If you can get me
the actual profiling breakdown or a latency SLA, I'd revisit the requirements section and possibly the
decision itself — right now it rests on the assumption that the bottleneck is CPU-bound rendering, which
nobody has confirmed.
