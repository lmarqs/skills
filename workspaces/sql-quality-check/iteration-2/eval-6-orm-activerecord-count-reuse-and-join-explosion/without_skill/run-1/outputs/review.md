# PR Review: Orders listing + pager total

```ruby
def index
  scope = Order.where(account_id: current_account.id)
               .joins(:line_items)
               .order(created_at: :desc)
  @orders = scope.limit(20).offset(params[:offset].to_i)
  @total  = scope.count
end
```

## Summary

Two real problems, and they share the same root cause: the `scope` is built with
`.joins(:line_items)` and reused for both the page of records **and** the count.
Because `orders has_many line_items`, the join fans each order out into one row
per line item. That breaks the count and makes both queries slower than they need
to be.

---

## Issue 1 — `@total` is wrong (counts are inflated) — **Correctness, blocking**

`scope.count` generates roughly:

```sql
SELECT COUNT(*)
FROM orders
INNER JOIN line_items ON line_items.order_id = orders.id
WHERE orders.account_id = ?
```

The join produces **one row per line item**, so `COUNT(*)` returns the number of
*line items* for the account, not the number of *orders*. An order with 8 line
items is counted 8 times.

- On a small/test account where most orders have ~1 line item, this looks fine —
  which is why it passed review locally.
- On big accounts (many line items per order) the total balloons, e.g. 1,000
  orders with avg 12 items reports `@total = 12,000`. The reviewer's "counts look
  off on big accounts" is exactly this.

Consequence for the pager: the page count is derived from a number that's 5–15x
too large, so users see far more pages than exist and most of them are empty
(offset runs past the real data).

### Also note: the list itself returns duplicates

The same join explosion affects `@orders`. `scope.limit(20)` selects from the
joined result set, so a single order with many line items can consume several of
the 20 slots — the page shows duplicate orders and fewer than 20 distinct ones.
`.order(created_at: :desc)` does not fix this; it just orders the duplicated rows.

---

## Issue 2 — Both queries are slower than necessary — **Performance**

1. **Unnecessary join.** Nothing in this action reads any `line_item` column. The
   `joins(:line_items)` appears to be dead weight (maybe meant as a filter that
   was never finished, or copy-paste). Joining a large, daily-growing child table
   just to list/count parents forces the DB to materialize the exploded row set.

2. **`COUNT` carries the `ORDER BY`.** `scope.count` inherits
   `.order(created_at: :desc)`. Ordering is meaningless for a count and some
   planners still pay for it. ActiveRecord usually strips the order on `count`,
   but relying on that is fragile; better not to put it on the shared scope.

3. **Recomputing `count` on every page request** is expensive on a large table,
   especially with the join. For deep pagination it's the dominant cost.

---

## Recommended fix

Separate the three concerns: a base scope (no join, no order), the ordered/limited
page, and a clean count.

```ruby
def index
  base = Order.where(account_id: current_account.id)

  @orders = base.order(created_at: :desc)
                .limit(20)
                .offset(params[:offset].to_i)

  @total  = base.count
end
```

- `base.count` now produces `SELECT COUNT(*) FROM orders WHERE account_id = ?` —
  correct order count, no join, no order-by.
- `@orders` returns 20 distinct orders.

### If a `line_items` join is actually required

If the join exists to filter orders (e.g. "orders that have at least one line
item", or matching some line-item condition), keep it but de-duplicate and count
correctly:

```ruby
base = Order.where(account_id: current_account.id)
            .where(LineItem.where("line_items.order_id = orders.id").arel.exists) # EXISTS, no fan-out
```

Prefer a `WHERE EXISTS` (or `.where(id: LineItem.select(:order_id))`) over a join
when you only need the parent rows — it avoids the explosion entirely. If you must
keep `joins`, then `base.distinct.count(:id)` (counts distinct orders) and
`@orders = scope.distinct` are required, but `EXISTS` is cleaner and faster.

### Pagination at scale

Counting the whole table on every page is the slowest part on big accounts.
Consider:

- Ensure an index on `orders(account_id, created_at)` to support the ordered page.
- **Keyset / cursor pagination** (`WHERE created_at < :last_seen ORDER BY
  created_at DESC LIMIT 20`) instead of `OFFSET`, which scans and discards all
  skipped rows and degrades on deep pages.
- If an exact total isn't essential, cache it, show an approximate count, or use
  `reltuples`-style estimates.

---

## Checklist

- [ ] Remove `joins(:line_items)` from the count path (fixes inflated total).
- [ ] Don't reuse the ordered+joined scope for `count`; build a clean base scope.
- [ ] Confirm whether the join is needed at all; if it is, use `EXISTS`/`distinct`.
- [ ] Verify `@orders` returns 20 *distinct* orders on an account with multi-item orders.
- [ ] Add/confirm index on `(account_id, created_at)`; consider keyset pagination.
