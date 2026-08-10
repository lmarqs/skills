# Review: V42__cleanup_customers.sql

**Verdict: do not merge.** All three statements are unsafe for a rolling deployment, and two of
them will likely fail or break production *before* considering rollback at all. The governing
question for any migration is not "can I reverse this SQL?" but **"can every application version
in traffic work with every intermediate database state?"** — and with a ~15-minute rolling window,
v1 (old pods) and v2 (new pods) share this schema for the entire rollout, plus however long you
need rollback to v1 to remain possible afterwards. This migration fails that test three separate
ways.

Findings are ordered with the irreversible/lossy one first, then the ones that break traffic.

---

## Finding 1 (lossy — highest severity): `ALTER COLUMN phone TYPE VARCHAR(20)`

**Class: breaking, and irreversibly destructive if it succeeds.**

Narrowing `VARCHAR(100) → VARCHAR(20)` discards information. Widening back later restores the
*shape* of the column, not any characters that were lost — there is no down migration for this.
That makes it the finding that outranks everything else in this file.

Concrete problems:

1. **"We checked" is a point-in-time observation, not a constraint.** Between your check and the
   moment the migration runs in production, any v1 pod can write a phone value longer than 20
   characters (pasted text, international format with annotations like `"+44 20 7946 0958 ext. 1234 (ask for Sam)"`,
   junk data from an integration). Nothing prevents it, because the schema currently allows 100.
2. **On PostgreSQL, if any over-long value exists, the `ALTER` errors out** (`value too long for
   type character varying(20)`) and the whole migration fails — see Finding 4 on what that does to
   your deploy. On MySQL with non-strict mode, worse: it *silently truncates*. Either outcome is
   bad; one of them is invisible.
3. **Even when all values fit, this narrowing forces a full table rewrite under an
   `ACCESS EXCLUSIVE` lock** (Postgres treats it as a type change, unlike widening, which is
   metadata-only). On a large `customers` table that blocks all reads and writes for the duration
   of the rewrite — an outage hiding inside a "cleanup" migration.
4. **After it succeeds, v1 is still in traffic for ~15 minutes** and may attempt inserts/updates
   with values that were legal seconds earlier. Those writes now fail with constraint errors on
   old pods — errors you'll misattribute to the new release.

**Staged alternative:** don't change the stored type in place at all unless you truly need the
storage semantics. If the goal is validation, add a `CHECK (char_length(phone) <= 20) NOT VALID`,
clean existing data, then `VALIDATE CONSTRAINT` (which takes only a light lock). If you genuinely
need the column type changed, do it as Expand–Migrate–Contract: add `phone_v2 VARCHAR(20)`,
dual-write with validation, backfill with an explicit rule for over-long values (truncate? reject?
route to manual review? — decide *before* the backfill, and keep the original), switch reads,
drop the old column in a separate deployment after the rollback window.

Also ask: what does shrinking this column actually buy? In Postgres, `VARCHAR(100)` and
`VARCHAR(20)` store identical bytes for identical values. If the answer is "tidiness", the risk
budget here is being spent on nothing.

---

## Finding 2 (immediate breakage): `RENAME COLUMN full_name TO display_name`

**Class: breaking. A rename is the canonical never-one-deployment change.**

The failure scenario, minute by minute: Flyway runs when the first v2 pod starts. From that moment
until the last v1 pod terminates (~15 minutes), every v1 pod still in the rollout executes
`SELECT ... full_name ...` / `UPDATE ... SET full_name = ...` against a schema where the column no
longer exists. Every one of those queries errors — `column "full_name" does not exist`. That's up
to 15 minutes of hard failures on your customers table, *by design of the deployment model*, not
by bad luck.

"The app code in this same PR is already updated to use `display_name` everywhere" does not help —
it makes the trap. The updated code only runs on new pods; the migration changes the schema for
old pods too. Schema and code cannot cut over atomically under rolling deploys.

And rollback is worse than the rollout: if v2 misbehaves and you redeploy v1, v1 is now broken
*by the schema*, so rolling back the application requires also reverse-renaming the column —
under incident pressure, against data v2 has been writing.

**Staged alternative (Expand–Migrate–Contract), each step an independent deployment compatible
with both versions in traffic during it:**

1. **Expand:** `ALTER TABLE customers ADD COLUMN display_name VARCHAR(100);` (nullable). v1
   ignores it. Rollback: drop it.
2. **Migrate (code):** deploy code that writes both `full_name` and `display_name`, reads
   `COALESCE(display_name, full_name)`. Rollback: redeploy v1 — compatible both ways.
3. **Migrate (data):** backfill in bounded, idempotent, restartable batches, e.g. loop until
   0 rows:
   ```sql
   UPDATE customers SET display_name = full_name
   WHERE id IN (
     SELECT id FROM customers WHERE display_name IS NULL AND full_name IS NOT NULL LIMIT 1000
   );
   ```
   Verify convergence with a query, not the job's exit code:
   `SELECT count(*) FROM customers WHERE display_name IS NULL AND full_name IS NOT NULL;` → must be 0.
4. **Contract (code):** deploy code that reads/writes only `display_name`. Rollback: redeploy
   step 2's version any time inside the rollback window.
5. **Cleanup (separate, later migration, after the rollback window and after proving nothing
   reads/writes `full_name`):** drop `full_name`. This is the only irreversible step, which is
   why it goes last and alone, with a date and an owner so "temporarily keeping both columns"
   doesn't become permanent.

---

## Finding 3 (fails or breaks, pick one): `ADD COLUMN loyalty_tier VARCHAR(10) NOT NULL`

**Class: breaking — twice over.**

1. **If `customers` has any rows, this statement fails outright** on Postgres/MySQL:
   `NOT NULL` with no `DEFAULT` cannot be satisfied for existing rows (`column "loyalty_tier" of
   relation "customers" contains null values`). The migration errors on deploy.
2. **If you "fix" it by adding a `DEFAULT`, it's still only conditionally safe:** it works because
   v1's inserts (which don't mention `loyalty_tier`) get the default — but that means "v2 sets it
   on every insert" is doing none of the safety work; the default is. And confirm what values v2
   writes: if v2 introduces tier values that v1-era code paths or reports don't understand, that's
   the enum-style data-compatibility trap — the schema is intact but the data is unreadable by
   old code.

**Staged alternative:**

1. Add the column nullable (or with a sensible `DEFAULT` — on Postgres 11+ adding a column with a
   constant default is metadata-only, no rewrite):
   `ALTER TABLE customers ADD COLUMN loyalty_tier VARCHAR(10) DEFAULT 'basic';` — pick the real
   default with the team, don't let the migration invent business meaning.
2. Backfill existing rows (batched, idempotent, as above) if the default isn't right for them.
3. Only after v1 is fully out of traffic and the backfill is verified
   (`SELECT count(*) FROM customers WHERE loyalty_tier IS NULL;` → 0), tighten in a later
   migration. On Postgres, avoid the full-table scan lock of a bare `SET NOT NULL` by using
   `ADD CONSTRAINT loyalty_tier_not_null CHECK (loyalty_tier IS NOT NULL) NOT VALID`, then
   `VALIDATE CONSTRAINT`, then `SET NOT NULL` (PG 12+ uses the validated constraint to skip the
   scan).

---

## Finding 4 (structural): three unrelated risky changes in one versioned migration

Flyway wraps `V42` in a single transaction (on Postgres). If the phone narrowing hits one
over-long value, or the `NOT NULL` add hits existing rows, the whole file fails, the schema
history marks the deploy failed, and your rollout stalls half-cycled — some v2 pods possibly up
against the old schema depending on startup ordering. Independently risky changes belong in
independent migrations shipped in independent deployments, so each has its own small blast radius
and its own rollback story. "Cleanup" migrations that batch a rename, a narrowing, and a new
required column are exactly how one bad assumption takes down three features.

---

## Pre-deployment checklist, applied

These unanswered questions *are* the review findings in compact form:

| # | Question | V42 as written |
|---|---|---|
| 1 | Can v1 run against the new schema? | **No** — `full_name` gone; phone writes can start failing |
| 2 | Can old and new pods run simultaneously? | **No** — 15-minute window of v1 errors |
| 3 | Does it delete/transform information? | **Yes** — phone narrowing is lossy; no source of truth named |
| 4 | Can it run safely more than once? | Moot — it likely doesn't run safely once (Finding 3) |
| 5 | Can a large backfill stop and resume? | No backfill exists; the `NOT NULL` add needs one |
| 6 | How is data correctness verified? | Nothing beyond Flyway's exit code |
| 7 | Can the behavior be disabled without schema revert? | No — no flag; code and schema cut over together |
| 8 | Recovery path if data goes wrong? | None; reverse-rename under incident pressure is the implied plan |
| 9 | When does destructive cleanup happen? | Immediately, in step 1 — the opposite of last |
| 10 | Interaction with concurrent releases? | Unknown — worth confirming nothing else touches `customers` |

---

## Recommended shape of the replacement

Deployment sequence (each item independently deployable and rollback-safe during its window):

1. **V42** (expand): add `display_name` (nullable), add `loyalty_tier` with `DEFAULT`, add
   `CHECK (char_length(phone) <= 20) NOT VALID`.
2. **App deploy**: dual-write `full_name`/`display_name`, read with fallback; set `loyalty_tier`
   explicitly on insert. Ideally behind a feature flag so the new behavior can be switched off
   without touching the schema.
3. **Backfill job**: `display_name` from `full_name`; fix/normalize any over-long phones per the
   agreed rule (keeping originals or logging what changed, so a compensating migration stays
   possible). Idempotent, batched, restartable, observable.
4. **Verify with queries**: zero unconverged `display_name` rows; zero phones over 20 chars; zero
   null `loyalty_tier`. Then `VALIDATE CONSTRAINT` on the phone check.
5. **App deploy** (contract): read/write only `display_name`.
6. **V43+, after an agreed rollback window (put a date on it now)**: drop `full_name`; `SET NOT
   NULL` on `loyalty_tier` via the validated-constraint route; optionally alter the phone type if
   there's a concrete reason beyond tidiness.

One question back to the team before re-planning: roughly how large is `customers` and what's its
write rate? That decides whether the backfill needs throttling/pause windows and how much the
rewrite lock in Finding 1 would have hurt.
