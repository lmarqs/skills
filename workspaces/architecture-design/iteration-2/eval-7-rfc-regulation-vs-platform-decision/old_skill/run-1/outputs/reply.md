# Reply

Draft RFC is in `document.md`. Recommendation: append-only consent events in managed Postgres (Brazilian
region, multi-AZ) + a write-once JSON evidence archive in Brazilian object storage + a read-through
cache with a 60-second bounded stale window + an API-level access log in a separate in-region sink;
migrate by backfill and CDC tail, reads before writes.

**The document is a draft, not approvable.** Four questions can change the design (Q1, Q2, Q3, Q6
below). I answered them with labelled assumptions so the reasoning is complete and checkable, but they
need real answers before anyone builds.

## Reclassifications — the analytical core of this RFC

You gave me four objectives. Three named a solution rather than a requirement, so I re-filed them. Each
reclassification opened a question the original framing hid.

1. **"Move to the managed Postgres the platform team standardized on" → a *preference*, not a
   requirement.** This is the most important one. Your two inputs are not the same kind of statement:
   the 20-year retention and the hosting-in-Brazil rule are **externally imposed obligations**, while
   the 2025 Postgres/Kubernetes standard is an **internal decision by a peer team** — revisable, and
   subordinate to the law if the two ever collide. Filing the platform standard as a requirement would
   have prevented the analysis from asking the one question that could disqualify it: *is that managed
   Postgres available in a Brazilian region?* I evaluated it as a candidate and **it wins** — Postgres
   with `INSERT`-only grants and a hash chain is a genuinely good fit for an append-only legal record.
   But the recommendation carries an explicit flip condition: if the product has no Brazilian region,
   the answer becomes self-managed Postgres in-country and the platform standard yields.

2. **"An audit trail" → three separate things.** The phrase conflated: (a) the **consent history**
   itself, which *is* the record, not an audit of it — ~24M rows, 20-year retention; (b) the **access
   log** — who read whose consent — whose retention is unknown and which, at an assumed 100 reads/s,
   is roughly **3.2 billion records/year, ~130× the consent data by row count**; (c) **admin/schema
   change logs**, which are the platform's. One "audit table" would have made the small precious
   dataset a tenant of the enormous disposable one, sharing its vacuum, index and backup windows. They
   are now in different stores with different retention.

3. **"99.9% availability" → split by path, plus a staleness commitment.** The arithmetic is the finding
   here: 99.9% is 43.2 min/month, and chaining our API (99.95%) synchronously with a managed Postgres
   (99.95%) gives **exactly 0.99900** — zero error budget before counting ingress or our own deploys.
   Add a third component and you are at 99.85%. So **99.9% is not reachable by a synchronous chain of
   vendor-SLA components.** The read path must be able to answer while Postgres is down, which is why
   there is a cache — for availability, not latency — and which forces an explicit bound on how stale
   a consent answer may be (60 s, worst case). Reads, writes and legal-response endpoints now have
   different targets because they fail differently.

4. **"A REST API with versioning" → kept, but it is the easy versioning problem.** URL versioning is
   cheap. The hard one over a 20-year horizon is versioning the **consent terms**: without pinning the
   exact wording (id + content hash) to every event, in year 12 you can prove a patient clicked
   something but not what they agreed to — which is not proof of consent. That is now requirement F4,
   and it is the single most important thing in the document that you did not ask for.

**Requirements I added that were not in the brief** (each because the 20-year obligation is worthless
without it): immutability enforced by database grants rather than convention; tamper evidence via a
hash chain plus a copy the database role cannot reach; capture of the evidence of the act (timestamp,
actor, channel, source IP); and byte-for-byte preservation of every original JSON blob — never "clean"
a legal artifact, because a cleaned blob is an altered record.

**Requirements I explicitly rejected**, so nobody re-adds them: hot/cold tiering, partitioning and
sharding. 4M rows now, ~24M after 20 years, ≈ **46 GiB** at a generous 2 KB/row. This dataset is small
for its entire 20-year life. The archive in my design exists for evidence durability and engine
independence, **not** for size — a different justification, and the distinction changes what the archive
has to do. I also rejected a ledger/immutable database: Amazon QLDB, the obvious managed option, reached
end of support in 2025 (see Q8 — verify before publishing), and the alternatives are niche bets over a
20-year commitment.

## Open questions

Blocking — the design changes if these come back differently:

- **Q1** Which cloud, which managed Postgres product, and **is it available in a Brazilian region**? Is
  there a second in-country region? This decides whether the platform standard survives at all, and it
  sets the disaster-recovery ceiling.
- **Q2** **What actually imposes hosting in Brazil?** You attributed it to LGPD art. 16, and I want to
  flag this carefully: LGPD art. 16 is about elimination of data after processing ends, with an
  exception for retention under a legal obligation — it is the right article for the *retention* basis.
  But **LGPD does not itself impose data localization**; art. 33 permits international transfer under
  stated conditions. So the hosting-in-Brazil obligation almost certainly comes from somewhere else —
  the sector regulator, a customer contract, or internal policy. I have treated it as a hard constraint
  because you stated it, but we need the instrument to know its **scope**: does it cover backups?
  replicas? logs? the observability platform? That scope question determines whether we can use any
  SaaS log or tracing product at all.
- **Q3** Is the sector rule the one I think it is, does it cover consent records specifically, and does
  the 20 years run from collection, from revocation, or **from the last entry on the record**? This
  sets an object-lock retention value that **cannot be shortened once set**, so it must be answered
  before Phase 1.
- **Q6** Is **fail-closed** correct — when we cannot establish consent, callers must not proceed — and
  is a **60-second worst-case revocation staleness** acceptable? Who signs that off? This is a legal
  call dressed as an engineering one. If legal says no to 60 s, my recommendation is to renegotiate the
  availability target *downward* rather than weaken the staleness bound: a lower SLO is a cost;
  honouring a revoked consent is an incident.

Non-blocking:

- **Q4** Retention for the access log — separate from the 20 years, and far larger.
- **Q5** Does a versioned corpus of consent terms already exist for wording shown to patients
  historically? If not, F4 is unmeetable for existing records and legal has to decide whether
  re-collection is needed.
- **Q7** Actual consent read rate and peak (sizes the access-log sink; does not affect the consent
  store).
- **Q8** Confirm the QLDB end-of-support date I cited.
- **Q9** Does anything read the raw JSON blob shape directly, outside the monolith's own code? Hidden
  readers are what turns a migration into permanent coexistence.
- **Q10** Who owns the service, and what is the agreed decommission date for the MySQL table?

## Assumptions I had to make

All eight are tabulated in the document with an owner. The load-bearing ones: managed Postgres exists in
a Brazilian region (A1); the retention clock runs from the last entry (A2); the only Brazilian region
has multiple AZs but no in-country pair for cross-region DR (A3); growth ~1M events/year (A4); reads
peak below 100/s (A5); the 4M blobs are of uneven completeness (A6); the monolith keeps writing until
its callers migrate (A7); 99.9% is monthly at our own edge (A8).

## Caveats

- **Legal citations are mine, not a lawyer's.** My reading of LGPD art. 16 and art. 33 is stated above
  and I am reasonably confident in it, but I did not name the sector regulator's instrument in the
  document because I would be guessing at which one applies to consent records specifically. Do not
  set the archive retention lock from this document — set it from the legal opinion.
- **Vendor SLA figures (99.95% / 99.99%) are typical, not verified for your product.** The composition
  arithmetic holds regardless of the exact inputs, but confirm the numbers for the real product under
  Q1.
- **One accepted risk you should see explicitly:** because the records must stay in Brazil and (under
  A3) there is no in-country second region, a full regional outage exceeds the 43.2 min/month budget
  and the standard remedy — a cross-region replica — is unavailable. I recorded this as an **accepted
  risk for the DPO and the SLO owner**, on the grounds that the hosting constraint outranks the
  availability target. If that is not acceptable to whoever owns the 99.9% number, that is a
  conversation to have now rather than after the first incident.
- **The estimates in the roadmap are unvalidated** with the team — shape, not commitment.
- The **biggest unquantified risk is data quality**, not architecture. If the 4M blobs lack terms
  references, timestamps or purposes, no storage design makes them into valid proof of consent. That is
  why task T1 is a 3-day profiling spike that gates the schema, and why the design preserves every
  original blob verbatim regardless of whether it can be projected.
