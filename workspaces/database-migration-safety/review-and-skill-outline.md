# Review of the source article, and a proposed skill shape

Companion to [`source-article.md`](source-article.md) (faithful distillation) and
[`knowledge-base.md`](knowledge-base.md) (organized + extended body of knowledge).

---

## 1. What the article gets right

- **The central reframing is genuinely good.** "Can I reverse this SQL?" → "Can both
  application versions work with every intermediate database state?" is the correct question,
  and most migration guides never ask it. Everything downstream in the knowledge base hangs off
  that sentence.
- **Naming the two non-equivalences explicitly** — application rollback ≠ database rollback,
  and schema rollback ≠ data rollback — is the clearest statement of the problem I've seen in
  a short article. The `VARCHAR(100)` → `VARCHAR(20)` example is perfect because it's obviously
  irreversible once stated and obviously invisible until it isn't.
- **"The SQL statement alone does not determine the risk. Deployment timing matters too."**
  This is the load-bearing insight for rolling deploys and it's stated crisply.
- **Insisting the five backfill properties are non-negotiable** (idempotent, restartable,
  bounded, observable, pausable) — correct, and correctly placed under "transitional logic
  fails in ways diagrams don't show".
- **Being honest about feature flags' limits** rather than selling them as the answer.
- **The restore-aside-and-repair recommendation over a full production restore.** This is the
  right instinct and it's often stated backwards elsewhere.
- **The five drop-preconditions and the ten-question checklist** are directly operational —
  they're the parts of the article that can be lifted into a skill nearly as-is.
- **"Verification queries; the success message doesn't prove the data is correct."** Small
  point, large consequences.

## 2. Gaps — the material additions the knowledge base makes

Ranked by how much they'd change an engineer's actual behavior.

| # | Gap | Why it matters | Where addressed |
|---|---|---|---|
| 1 | **Locking, table rewrites, and online DDL are never mentioned.** | This is the *most common* way migrations cause production incidents — more common than the compatibility problem the article is about. A three-millisecond `ALTER` that queues behind a long transaction takes the table down for everything behind it. | KB §1.3, §5.1 |
| 2 | **No testing story.** | The compatibility contract is checkable by CI: run the previous release's test suite against the new schema. Without that, the whole argument depends on reviewer vigilance. | KB Part IX |
| 3 | **Reversibility is treated as fate rather than a design choice.** | "Once a migration discards information, rollback cannot reconstruct it" is true *and* actionable in the opposite direction: capture the pre-image yourself and the change stops being irreversible. | KB §2.2 |
| 4 | **The schema exists outside the database too.** | Queues, caches, event streams, search indexes, analytics, and mobile clients all carry the old shape. The real rollback window is set by the slowest of them — often a mobile client, i.e. months. | KB §5.6 |
| 5 | **Replicas and replication are absent.** | Backfills generate lag → stale reads; DDL conflicts with standby queries; logical replication/CDC pipelines break on DDL. | KB §5.3 |
| 6 | **No guidance on rolling back *mid-pattern*.** | "What do I do if the dual-write release is bad?" is the question people actually have, and each phase has a different, specific answer. | KB §3.3 |
| 7 | **The deployment-ordering rule is implied, never stated.** | Expand DDL before the code that uses it; contract DDL after the last referencing code is gone. Stating it makes the pattern mechanical. | KB §3.1 |
| 8 | **Dual writes are shown only at the application layer.** | For same-database column sync, a generated column or trigger is usually *safer* — it covers writers the app team doesn't control, which is exactly the failure mode that bites during Contract. | KB §3.4 |
| 9 | **Semantic changes (repurposed columns) aren't covered.** | The only change class where nothing errors, nothing is detectable, and both versions are confidently wrong. | KB §2.4 |
| 10 | **Backfill mechanics stop at "batch it".** | Keyset vs `OFFSET`, the driving-predicate index, durable checkpoints, `SKIP LOCKED`, adaptive throttling on replica lag — the difference between a backfill that finishes and one that doesn't. | KB §6.2–6.3 |
| 11 | **Nothing on the migration runner.** | Boot-time migrations racing across N pods, advisory locks, checksum drift, per-migration timeouts. | KB §5.5 |
| 12 | **No shadow/dark-read verification.** | The cheapest possible proof, on real traffic, that the backfill and dual-write are correct before switching reads. | KB §3.6 |
| 13 | **Retention vs. rollback window vs. MTTD is never reconciled.** | Recovery plans routinely depend on evidence that has already expired. If MTTD is two weeks and WAL retention is three days, the plan is fiction. | KB §7.3 |
| 14 | **Process and enforcement are absent.** | "Keep it temporarily (in bold)" is a hope. Contract tickets created at expand time, schema comments, CI linters, and a tracked count of open cycles are what make it real. | KB §3.7, Part X |
| 15 | **Tolerant readers aren't named.** | Deploying lenient readers one release ahead turns a whole class of enum/field incidents into a log line. | KB §1.5 |

## 3. Where I'd push back

- **"`up`/`down` migrations are totally unreliable in production" is too broad.** `down` is
  unreliable for anything that touched *data*; it's perfectly fine for "drop the index I just
  created" and genuinely useful in local dev and CI teardown. The sharper rule: *write `down`
  for developers; never let it be the production recovery plan for a data-touching change.*
  Stated as an absolute, the advice invites engineers to stop writing `down` migrations at all,
  which costs them something and buys nothing.

- **"Adding a nullable column usually allows the old version to keep running."** True at the
  logical level, with two real caveats the article omits: old code doing `SELECT *` into a
  strict struct, or `INSERT` without a column list, can break on shape change; and on a large
  table the `ALTER` itself may be the incident, depending on engine, version, and default. The
  word doing the work is "usually", and it deserves its footnotes.

- **The dual-write example understates the same-database case.** "If both writes hit the same
  database and run in a single transaction, you usually get atomicity" — correct, but the more
  useful advice for that case is *don't dual-write from the application at all*; let the
  database keep the columns in sync. The article jumps from app dual-writes straight to
  distributed consistency, skipping the option that's better than both.

- **Expand/Migrate/Contract is presented as three deployments; it's really four or more.**
  Expand DDL, dual-write code, backfill (an operation, not a deploy), new-only code, and the
  drop are five distinct steps with four gates between them. The compressed version hides the
  gate that matters most — the one between "code no longer reads it" and "drop it".

- **The compensating-migration section needs a "measure first" step.** As written it goes
  straight to the corrective operation. Under incident pressure, the missing `SELECT count(*)`
  with the exact `WHERE` clause of the pending `UPDATE` is how a data-quality incident becomes
  a data-loss incident.

- **The AWS-bill aside and the sponsor block** carry no technical content and shouldn't survive
  into any derived material.

## 4. Structural suggestion

The article's spine is one axis: *compatible vs breaking*. The knowledge base re-spines it on
three: **availability, compatibility, reversibility** (KB §1.3). That reorganization is the
single most valuable edit, because it:

- gives every change a three-part classification instead of a vague "risky",
- makes the article's own advice land in the right bucket (Expand/Migrate/Contract answers
  *compatibility*; pre-images and rollback windows answer *reversibility*; online DDL — the
  missing part — answers *availability*),
- and explains why some "safe" changes still cause outages, which the one-axis model cannot.

## 5. Proposed skill shape (for the later step)

Sketch only; to be settled with `skill-creator` when we actually build it.

**Name:** `database-migration-safety` (alternatives: `safe-schema-change`,
`zero-downtime-migrations`). Sits naturally beside `sql-quality-check`, which reviews queries
and *mentions* migrations — this one owns change-over-time and should defer index/query
performance analysis to it.

**Shape:** advisory + review, like `sql-quality-check`. Two entry modes:

- *Plan mode* — "I need to rename/drop/backfill X": produce the phased plan, the verification
  queries, and the recovery path.
- *Review mode* — "review this migration / PR": classify on the three axes, flag the
  not-deployable-in-one-step cases, demand the missing evidence.

**Body (SKILL.md, kept lean):** the three axes, the state matrix, the ordering rule, the
Expand/Migrate/Contract phase table with gates, and the pre-deployment checklist. Everything
else pushed to references.

**References (progressive disclosure):**

| File | Contents |
|---|---|
| `references/change-classification.md` | The compatibility table, reversibility classes, the not-deployable-in-one-step list, semantic changes. |
| `references/expand-migrate-contract.md` | Phases, gates, rollback-per-phase, dual-write implementations, shadow reads, table-level variant. |
| `references/operational-mechanics.md` | Locks and online DDL per engine, connection pools/ORM traps, replicas, MVCC, migration runners, non-DB carriers. |
| `references/backfills.md` | The six properties, keyset batching template, throttling, failure handling, sizing. |
| `references/recovery.md` | Roll-forward posture, compensating migrations, pre-images, evidence sources + retention, restore-aside, the incident decision tree. |
| `references/verification-and-testing.md` | Metrics, verification queries, the five drop preconditions, the CI compatibility matrix, linters. |
| `references/playbooks.md` | Worked examples (rename, NOT NULL, INT→BIGINT, enum, narrowing, unique, split, purge) and the anti-pattern list. |

**Description-trigger vocabulary to cover:** migration, schema change, `ALTER TABLE`, add/drop/
rename column, backfill, zero-downtime deploy, rollback, "can I roll this back", down
migration, expand-contract, breaking schema change, data fix, "we shipped bad data",
compensating migration, PITR/restore, replica lag during migration, "will this lock the table",
flyway/liquibase/alembic/prisma/active record migration.

**Open questions to settle before authoring:**

1. **Scope boundary with `sql-quality-check`** — that skill already claims "check my migration".
   Decide whether this one takes over migration review entirely (and the other is edited to
   defer) or whether they split on query-performance vs change-safety.
2. **Engine specificity.** The house style is generic and asks for context rather than
   assuming. Engine-specific lock behavior is the most valuable content here but is also the
   most assumption-laden — likely resolution: keep SKILL.md engine-agnostic, put engine detail
   in `references/operational-mechanics.md`, and have the skill *ask* which engine and version
   before giving lock advice.
3. **How prescriptive to be about process** (Part X) — plans, two-person review, contract
   tickets. Valuable, but a skill that lectures about Jira will get ignored. Probably a short
   "what a migration plan contains" section and nothing more.
4. **Output format.** `sql-quality-check` uses impact/corrected/tradeoff triads. The analogue
   here is probably **risk classification / phased plan / recovery path** as the mandatory
   three parts of any answer.
