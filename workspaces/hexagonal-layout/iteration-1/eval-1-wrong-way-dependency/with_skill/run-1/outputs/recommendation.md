# Code review: `internal/order/order.go`

## Verdict

Your instinct is right — this is **not** structured well. The `Order` type, which is the
system's reason to exist, depends directly on the database technology. The dependency arrow
points the wrong way.

## The issue

In a layout like yours (`internal/` for the system, `cmd/` for entrypoints), `internal/order`
is the **reason** the system exists: the `Order` and `Item` types and the rule for placing an
order. That code should depend on *nothing outward* — least of all a concrete database driver.

But `order.go` does two unrelated jobs in one method:

```go
import "database/sql"

func (o *Order) Place(db *sql.DB) error {
	// 1. business rules (validate items, compute total, set status)
	...
	// 2. I/O: a hand-written Postgres INSERT
	_, err := db.Exec("INSERT INTO orders (id, total, status) VALUES ($1, $2, $3)", ...)
	return err
}
```

Three smells, all from the same root cause — **I/O and an outside concrete living in the reason**:

1. **`database/sql` imported by the domain.** `*sql.DB` is a runtime dependency: it pulls real
   connection behaviour into the type. The domain now can't compile or be reasoned about without
   the SQL package.
2. **A SQL string and Postgres-flavoured `$1` placeholders inside `Place`.** That's the most
   external concrete there is — a specific dialect of a specific database — sitting in the core.
3. **Business logic and persistence fused in one method.** `Place` both decides (is the order
   valid? what's the total?) and persists (INSERT). They can't be exercised or changed
   independently.

This costs all three payoffs the layout is supposed to give you:

- **Not technology-independent** — switching to another store, or even reshaping the SQL, means
  editing the domain type.
- **Not testable** — you can't unit-test the "reject an empty order" / "total = sum of items"
  rules without a live `*sql.DB`.
- **Not reusable** — a second caller (an HTTP handler, a batch job, a different store) inherits
  Postgres whether it wants it or not.

`cmd/server/main.go` is mostly fine — opening the DB and wiring is exactly run's job — but it's
forced to hand a `*sql.DB` straight into the domain because the domain demanded it.

## What to change, concretely

Split the one method along its seam: the **decision** stays in the reason, the **interface** for
what it needs is *declared* by the reason, the **SQL** moves to a connection, and `main` does the
**wiring**.

### 1. Keep the rule in the reason; declare the interface there

In `internal/order/order.go`, drop the `database/sql` import. Make `Place` only run the rules,
and have the domain declare the port it needs:

```go
package order

import "errors"

type Order struct {
	ID     string
	Items  []Item
	Total  int // cents
	Status string
}

type Item struct {
	SKU      string
	Quantity int
	Price    int
}

// Repository is the port the domain declares for persisting orders.
// The reason owns this interface, because the reason is what needs it.
type Repository interface {
	Save(o *Order) error
}

// Place runs the business rules for accepting an order. No I/O.
func (o *Order) Place() error {
	if len(o.Items) == 0 {
		return errors.New("order has no items")
	}
	o.Total = 0
	for _, it := range o.Items {
		o.Total += it.Price * it.Quantity
	}
	o.Status = "placed"
	return nil
}
```

Note the interface lives **with the domain** (in `internal/order`), not next to the SQL. That's
what inverts the arrow: the connection will depend on `order`, not the other way around.

You can keep `Place()` as a pure method and have the caller persist, or — if you'd rather the
domain own the "place then store" use-case — add a thin service that takes the `Repository`:

```go
// internal/order/service.go
package order

type Service struct{ repo Repository }

func NewService(repo Repository) *Service { return &Service{repo: repo} }

func (s *Service) PlaceOrder(o *Order) error {
	if err := o.Place(); err != nil {
		return err
	}
	return s.repo.Save(o)
}
```

Either way the domain depends only on the `Repository` interface it declared, never on `sql`.

### 2. Move the SQL to a connection

Create a new package for the Postgres implementation — the connection that fulfils the port.
With your `internal/` convention, something like `internal/order/postgres` or a sibling
`internal/storage/postgres`:

```go
// internal/order/postgres/repository.go
package postgres

import (
	"database/sql"

	"example.com/shop/internal/order"
)

type OrderRepository struct{ db *sql.DB }

func NewOrderRepository(db *sql.DB) *OrderRepository {
	return &OrderRepository{db: db}
}

// Save implements order.Repository.
func (r *OrderRepository) Save(o *order.Order) error {
	_, err := r.db.Exec(
		"INSERT INTO orders (id, total, status) VALUES ($1, $2, $3)",
		o.ID, o.Total, o.Status,
	)
	return err
}
```

This is the right home for `database/sql`, the SQL string, and the `$1` Postgres placeholders.
The import now points `postgres → order`, i.e. toward the reason.

### 3. Wire it in run

`cmd/server/main.go` is where the connection and the reason meet — it picks Postgres and hands
it to the domain:

```go
package main

import (
	"database/sql"
	"log"
	"os"

	_ "github.com/lib/pq"

	"example.com/shop/internal/order"
	"example.com/shop/internal/order/postgres"
)

func main() {
	db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	repo := postgres.NewOrderRepository(db)
	svc := order.NewService(repo)

	o := &order.Order{
		ID:    "ord_123",
		Items: []order.Item{{SKU: "abc", Quantity: 2, Price: 500}},
	}
	if err := svc.PlaceOrder(o); err != nil {
		log.Fatal(err)
	}
}
```

## Resulting shape

```
internal/order/             <- the reason: Order, Item, Place(), Repository interface, Service
internal/order/postgres/    <- a connection: SQL implementation of Repository
cmd/server/                 <- how it's run: opens the DB, builds postgres repo, wires the service
```

Arrows: `cmd/server → internal/order ← internal/order/postgres`. The reason depends on nothing
outward; the connection and run depend on it.

## What this buys you

- **Technology-independent** — swap Postgres for another store (or a fake) by writing a new
  `Repository`; `internal/order` doesn't change.
- **Testable** — unit-test the empty-order rejection and the total calculation against an
  in-memory `Repository`, no database in the loop.
- **Reusable** — an HTTP handler, a CLI, or a batch job can all drive `order.Service` with
  whatever store they choose.

## A note on degree

How far to take this is your call. The minimum fix that removes the wrong-way arrow is steps 1
and 2 — get `database/sql` and the SQL out of `internal/order` and behind an interface the domain
declares. The `Service` in step 1 is optional sugar for owning the use-case; if you'd rather keep
`Place()` pure and let `main` call `repo.Save(o)` after it, that's also clean. The package name
`internal/order/postgres` follows Go convention and announces intent (a Postgres-backed order
store); pick whatever name fits the rest of your tree, but keep the SQL out of the domain package.
