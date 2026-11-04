# Reply

RFC drafted, status **proposed** — two blocking legal questions hold it there. The headline: your
regulatory citation is wrong in a way that changes the option space, and none of your four objectives
survived as a requirement in the form you wrote it.

## I checked your legal sources, and two of the three claims do not say what you said

I verified the clauses against the published texts (2026-09-08). Summary:

| Your claim | What the clause actually says | Consequence |
| --- | --- | --- |
| LGPD art. 16 requires consent records to be kept for 20 years | Art. 16 is the **elimination** rule: personal data *shall be deleted* once processing ends, and retention is *authorized* only for listed purposes — the first being compliance with a legal or regulatory obligation. It imposes no period at all | The 20-year duty comes from elsewhere (below). Art. 16 is a duty pointing the **other way**: it obliges you to eliminate consent records once the retention duty expires, and to keep no more fields than the duty needs. Nobody is doing that today |
| The 20-year retention rule | Confirmed, but the source is **Lei 13.787/2018, art. 6**: "decorrido o prazo mínimo de 20 (vinte) anos a partir do último registro… poderão ser eliminados". Art. 6, §1 lets a regulation set a **different** period | Two design consequences. The clock runs from the **last entry on the record**, not from the consent's last change (that is blocking question BQ2). And the retention period must be a configurable rule reference, never a hardcoded 20 |
| LGPD requires the data to stay hosted in Brazil | **The LGPD contains no localization requirement.** Arts. 33–35 *permit* international transfer under stated conditions (adequacy, or contractual guarantees proved by the controller), which is the opposite of a mandate | This is the expensive one. If residency is real, it comes from a contract, a sector-specific rule or your own internal policy — and nobody has cited it. It is carried as constraint **C5** with its source contested, and **BQ1** must resolve it |

Two clauses you did not mention are doing most of the work in the document: **LGPD art. 8, §2** puts
the burden of proving valid consent on you as controller — that, not a preference for logging, is why
the "audit trail" became a hard requirement with database-enforced immutability. And **art. 19, II**
caps your response to a data subject at 15 days, which is the deadline the history requirement is
measured against.

**Why BQ1 matters enough to hold the status:** if residency is internal policy rather than law, a
cross-region standby and a hosted consent-management vendor both come back into the table, and your
99.9% gets cheaper to reach. If it is binding, both stay excluded. That is a different decision, so
recommending above it would be hoping rather than deciding.

## What I reclassified, and why

**Your objective 2 — "move to the managed Postgres the platform team standardized on" — is a prior
decision, not a constraint.** The platform team is inside your organization, so their 2025 standard
cannot exclude an option; it can only carry a cost. I put it in the tradeoff table with managed MySQL
beside it and made it win on its merits. It did win — but not for the reason you gave. Keeping the data
in MySQL is genuinely the **lower-risk migration** (a schema change instead of a cross-engine move of
4M rows), and it lost only because nobody will commit to operating a second database engine until 2046.
If the platform team *would* make that commitment, option B becomes hard to refuse, and you should know
that before you spend the migration.

**Your objective 1 — "a REST API with versioning" — is a mechanism.** The capability underneath it is
F4: a consumer already integrated keeps working when the contract changes. REST won, but consent
events on the platform bus and a shared library are both in the table, and the bus option is the one
that answers your monolith maintainers' real objection.

**Your objective 4 — "an audit trail" — is also a mechanism**, and the requirement under it (F3) is
stronger than a log table: the application's database role gets `INSERT`/`SELECT` only, with a CI check
asserting the grants, plus a per-patient hash chain so an export can be *recomputed* by a regulator
rather than asserted by you. A row your own application can `UPDATE` is not evidence a regulator has
any reason to accept.

**Your objective 3 — "99.9% availability" — I carried but did not accept.** It is in as N1 with the
target labelled *assumed* and its derivation cell reading "nothing", because there is no current
measurement to derive it from (the read is in-process today, so it appears in no API metric). Two
things follow. First, it brought N2 with it — recoverability, RPO 0, RTO 10 minutes derived from N1's
own 43.2-minute monthly budget — because a lost consent record is a compliance failure, not an
incident. Second, and more bluntly: **the third nine is doing less for the clinician than a cache
would.** A last-known-decision cache on the consumer side, with an explicit fail-closed rule, gets you
a better clinical outcome than a more expensive HA topology. That is BQ3, and it is a clinical safety
question rather than an engineering one.

**I added two requirements nobody asked for.** F5 and F6 exist because your two legal duties pull in
opposite directions: art. 6 obliges you to keep records for 20 years, art. 16 obliges you to eliminate
them once the reason to keep them ends. Right now you are failing the second one silently, and an
erasure request under art. 18, VI risks destroying a record art. 6 obliges you to keep. The role they
serve is your data protection officer, who is accountable for both. Recorded as a stakeholder conflict
since you did not ask for them.

## Questions I would have asked, with my recommended answers

Because this was a one-shot, each of these is in the document as a labelled assumption instead.

1. **BQ1 (blocking).** Does the Brazil-residency requirement come from a binding external source — a
   contract, a sector rule, an ANPD ruling — or from internal policy? *My recommendation: treat it as
   binding until legal says otherwise, because assuming wrongly means a data transfer you cannot
   undo.* Owner: your DPO with legal.
2. **BQ2 (blocking).** Does the 20-year clock run from the last entry on the **patient's record as a
   whole** (what art. 6's wording says) or from the consent's own last change? *My recommendation: the
   record as a whole, the conservative reading.* If so, this service cannot compute its own expiry
   dates — it needs the chart's last-entry date from whoever owns the chart, a dependency the document
   does not currently design. The elimination job therefore ships **deployed disabled**, and nothing is
   lost by that: the earliest possible elimination for a record migrated today is 2046.
3. **BQ3 (non-blocking).** How stale may a consent decision be at the point of care, and what should a
   clinician do when no answer comes back? *My recommendation: 5 minutes, fail closed beyond it.*
   Owner: clinical operations lead.
4. **Which sector-regulator resolution do you mean?** You referenced it without a number and I could
   not verify it. Non-blocking, because Lei 13.787/2018 art. 6 already gives you the 20-year floor —
   but art. 6, §1 lets a regulation set a **longer** period, so your DPO should cite it before this is
   final.
5. **Would the platform team own a second database engine until 2046?** If yes, option B (stay on
   MySQL) becomes the lower-risk choice and the decision changes.

## Assumptions you should read as assumptions

Every number in the document carries a *measured / estimated / assumed* label, and almost all of them
are **assumed**, with you as the origin, because I had no database, dashboard or repository to check.
The four that matter, each with the query that closes it in under a minute:

- **4 million rows** — `SELECT count(*)`, plus one row of `information_schema.tables` for the size.
  Volume is not a driver here, so this does not change the decision; it sizes the migration.
- **How many places read consents today** — a `grep` for the table and model name across the monolith.
  This is the single most useful unknown, which is why the backfill task is estimated as a range.
- **Whether the current blobs preserve any history** — if they do not, the record's own history begins
  at cutover. That is a compliance fact your DPO needs before an audit, not a migration detail.
- **No availability or latency baseline exists.** This is why **I set no latency target at all** rather
  than inventing one. A number with no derivation would be enforced for twenty years and nobody could
  argue with it; the first month after cutover measures it, and the target lands in an amendment.

## Caveats on the document itself

- **Roles are placeholders.** No names were available, so the decider, approver and reviewers are
  written as roles. The decision is not final until real people sit in those slots — flagged in the
  document rather than left to be inferred.
- **The hash chain has a stated limit.** It detects tampering by anyone who cannot rewrite the whole
  chain; it does not stop someone with database write access. The stronger version (a signed digest
  anchored outside the database) is a roadmap item, not a requirement, because nobody has said that
  adversary is in scope. Say if they are.
- **The 20-year archive is the risk no drill fully retires.** The annual restore-and-read drill proves
  last year's format, not 2046's. Postgres majors get roughly five years of support, so a record
  written today outlives about four upgrade cycles — that figure is labelled *assumed* and should be
  checked against the project's published schedule before the archive format is fixed.
- Had this been interactive, I would have stopped twice: after the requirements (to get F5, F6 and the
  restated N1 confirmed before designing against them) and after the tradeoff table (to check driver
  priority — putting durability above availability is the choice that decided A over C).
