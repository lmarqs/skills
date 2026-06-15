# PR review — orders listing + pager count

The reviewer is right on both counts: it is slow *and* the totals are wrong. Both
symptoms trace back to the same line — `.joins(:line_items)` — which forces a 1:N
join into a query that doesn't need it, and then that whole query gets reused for the
count. Findings below, ordered by impact at the expected volume (both `orders` and
`line_items` are large and grow daily).

```ruby
def index
  scope = Order.where(account_id: current_account.id)
               .joins(:line_items)          # <-- 1:N row explosion
               .order(created_at: :desc)     # <-- unindexed sort on a growing table
  @orders = scope.limit(20).offset(params[:offset].to_i)  # <-- OFFSET pagination
  @total  = scope.count                      # <-- reuses the full listing query
end
```

---

## Finding 1 — The `joins(:line_items)` inflates the count and duplicates rows (smell #1 + #7)

**Impact.** An `Order` has many `line_items`, so `INNER JOIN line_items` produces one
result row *per line item*, not per order. This breaks the code in two ways:

- **The count is wrong.** `scope.count` becomes `SELECT COUNT(*)` over the joined
  result, so it counts *line items belonging to this account's orders*, not orders.
  An account with 10 orders averaging 8 line items each reports a total of ~80. This
  is exactly the "counts look off on big accounts" the reviewer saw — the bigger the
  account, the more line items per order, the more inflated the number, and the more
  pages the pager invents. It also silently *drops orders that have zero line items*,
  because an `INNER JOIN` excludes them.
- **The listing is wrong too.** `@orders` is `Order` records read from a row-multiplied
  result, so the same order appears multiple times in the 20-row page (ActiveRecord
  does not de-duplicate `joins` results unless you add `.distinct`). The page shows
  duplicates and fewer than 20 distinct orders.

The join appears to serve no purpose here — no `line_items` column is selected,
filtered, or ordered on. It looks like an accidental inclusion (or a leftover from a
filter that was removed).

**Corrected version.** If the join isn't needed, drop it entirely. Build a base scope
without the join, and only count over that:

```ruby
def index
  scope = Order.where(account_id: current_account.id)
  @orders = scope.order(created_at: :desc)
                 .limit(20)
                 .offset(params[:offset].to_i)
  @total  = scope.count   # COUNT(*) on orders filtered by account_id — correct and lean
end
```

If you genuinely need orders that *have at least one* line item (a filter, not a
fetch), express it without multiplying rows — use `EXISTS` rather than a join (smell #9):

```ruby
scope = Order.where(account_id: current_account.id)
             .where(LineItem.where("line_items.order_id = orders.id").arel.exists)
# or, simply:  .where(id: LineItem.select(:order_id))  ->  IN (...) ; EXISTS is preferred
```

If you need the line items *displayed* per order, load them separately to avoid the
explosion (smell #1) — `preload(:line_items)` issues a second `WHERE order_id IN (...)`
query rather than one multiplied join.

**Tradeoff.** Dropping the join changes results (intentionally — it fixes them). Using
`EXISTS`/`preload` instead of a single joined query means a second round trip, but each
query is index-friendly and returns the right cardinality. There is no real downside to
removing a join that contributes nothing.

---

## Finding 2 — The count reuses the full listing scope (smell #7)

**Impact.** `@total = scope.count` is computed from the *same* `scope` that carries the
join and the `ORDER BY`. Counting never needs ordering, and (per Finding 1) shouldn't
carry this join at all. Even after the join is fixed, keep the count on a lean scope so
it stays `SELECT COUNT(*) FROM orders WHERE account_id = $1` rather than dragging along
listing-only clauses. This count runs on *every page load*.

**Corrected version.** Already shown in Finding 1: `@orders` adds `.order/.limit/.offset`;
`@total` counts the bare `scope`. ActiveRecord drops the `ORDER BY` for a `count`
automatically, but it will *not* drop the join — which is the real trap here.

**Tradeoff.** On a very large account, an exact `COUNT(*)` over `orders` is still a scan
of that account's orders on each request. If exactness isn't essential, an approximate
count (cached, or `reltuples`-based estimate) is far cheaper. The exact count is fine if
per-account order volumes are moderate; revisit if the count query itself shows up slow.

---

## Finding 3 — OFFSET pagination degrades on deep pages (smell #8)

**Impact.** `.offset(params[:offset].to_i)` makes the database read and discard every row
before the requested page. Page 1 is cheap; page 5,000 reads and throws away 100,000 rows
first. On a large, daily-growing `orders` table this gets progressively slower the deeper
a user pages — a second contributor to "it's slow."

**Corrected version.** Use keyset (cursor) pagination anchored on the sort key:

```ruby
scope = Order.where(account_id: current_account.id)
scope = scope.where("created_at < ?", params[:before]) if params[:before].present?
@orders = scope.order(created_at: :desc).limit(20)
# next-page cursor = @orders.last.created_at
```

**Tradeoff.** Keyset pagination can't jump to an arbitrary page number (no "go to page 50")
and needs a stable, ideally unique sort key — with `created_at` alone, ties at the same
timestamp need a tiebreaker (e.g. order by `created_at DESC, id DESC` and carry both in
the cursor). It also pairs poorly with showing an exact total/last-page number. If the UI
truly needs numbered pages with a total, OFFSET may be a deliberate choice — but cap how
deep users can page, and keep the count cheap (Finding 2).

---

## Finding 4 — `ORDER BY created_at` needs a supporting index (smell #10 + #4)

**Impact.** `orders` is transactional (grows daily, has a `created_at`), and the listing
sorts every matching row by `created_at DESC`. Without an index that covers the
`account_id` filter *and* the `created_at` ordering, the database filters by account and
then sorts the result in memory/on disk on each request. Combined with OFFSET, deep pages
sort a large set just to discard most of it.

**Corrected version.** Add a composite index ordered to match the query — equality column
first, sort column second:

```sql
CREATE INDEX idx_orders_account_created
  ON orders (account_id, created_at DESC);
```

This lets the database seek to the account's rows already in `created_at DESC` order, so
both the listing and (with keyset) the pagination become index range scans.

**Tradeoff.** The index costs disk space and adds write overhead — and `orders` is written
to daily. That's the standard read-vs-write trade: this is a hot read path hit on every
page load, so paying a little on insert to make the common read fast is the right call.
Confirm `account_id` is selective enough to matter (it should be on a multi-tenant table).

---

## Root cause

These aren't four independent nits — they cluster around one mistake. The accidental
`joins(:line_items)` is the root: it corrupts the count, duplicates the listing rows, and
makes both queries heavier. Fix that one line first (Findings 1 + 2) and the "counts look
off" complaint disappears. Findings 3 and 4 (keyset pagination + a covering index) are the
durable fixes for "it's slow" as `orders` keeps growing.

## Validate with the plan

Confirm before/after with `EXPLAIN (ANALYZE, BUFFERS)` on the generated SQL. Look for:

- a **Sort** node with `Sort Method: external merge` (spilling to disk) on the listing —
  should disappear once the composite index is in place;
- a **Seq Scan** on `orders` for the count — should become an `Index Only Scan` /
  index scan filtered by `account_id`;
- the **actual row count** out of the join node vs. the number of orders — that gap is the
  inflation behind the wrong totals.
