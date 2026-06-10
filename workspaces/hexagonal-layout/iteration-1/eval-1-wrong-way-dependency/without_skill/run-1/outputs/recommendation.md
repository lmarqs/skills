# Code review: `internal/order/order.go`

## Verdict

Your instinct is right — the structure is **not** right. The problem is a **dependency-direction inversion**: your central domain type knows about `database/sql`, which means your business core depends on infrastructure instead of the other way around.

The smell shows up concretely in two places in `internal/order/order.go`:

```go
import (
	"database/sql"  // domain importing infrastructure
	"errors"
)

func (o *Order) Place(db *sql.DB) error {   // domain method takes a *sql.DB
	...
	_, err := db.Exec(
		"INSERT INTO orders (id, total, status) VALUES ($1, $2, $3)",
		o.ID, o.Total, o.Status,
	)
	return err
}
```

`Order` is described in its own comment as "our central domain type," yet `Place` mixes two unrelated responsibilities:

1. **Business rules** — reject empty orders, compute `Total`, set `Status = "placed"`.
2. **Persistence** — open a SQL connection, write an `INSERT`, and even know the Postgres `$1`-style placeholder dialect.

## Why this is a problem

- **Wrong-way dependency.** The whole point of an `internal/`-style layout (domain core + `cmd/` entry points) is that the core sits at the center and nothing inward depends on the database, HTTP, or any specific tech. Here the arrow points the wrong way: `order` -> `database/sql` -> Postgres driver.
- **You can't test the business rules in isolation.** To unit-test "an empty order is rejected" or "total is summed correctly," you currently need a live `*sql.DB`. The pure logic and the I/O are welded together.
- **Leaky abstraction.** The SQL dialect (`$1, $2, $3`), the table name, and the column list now live inside the domain. Swapping databases, adding a transaction, or changing the schema forces edits to your core type.
- **Single Responsibility violation.** `Place` is both the rule engine and the data-access layer.

## What to change, concretely

The fix is to invert the dependency: define what persistence the domain *needs* as an interface owned by the domain, and put the SQL implementation in a separate package that depends on the domain (not the reverse).

### 1. Keep `internal/order/order.go` pure

Remove the `database/sql` import entirely. `Place` should run only the business rules and return the validated/priced order — no `db` parameter.

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

// Place runs the business rules for accepting an order. No persistence here.
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

### 2. Declare the persistence contract in the domain package

Add a `Repository` interface (the "port") in `internal/order/`. The domain says *what* it needs; it does not say *how*. Put it next to the type, e.g. a new file `internal/order/repository.go`:

```go
package order

type Repository interface {
	Save(o *Order) error
}
```

Optionally, add an application service that orchestrates "run the rules, then save" so callers have a single entry point — e.g. `internal/order/service.go`:

```go
package order

type Service struct {
	repo Repository
}

func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) Place(o *Order) error {
	if err := o.Place(); err != nil {
		return err
	}
	return s.repo.Save(o)
}
```

### 3. Put the SQL in an adapter package that depends on the domain

Create a new package for the database implementation — for example `internal/order/postgres/repository.go` (or a sibling `internal/storage/postgres/`). This is the only place that imports `database/sql` and knows the SQL dialect.

```go
package postgres

import (
	"database/sql"

	"example.com/shop/internal/order"
)

type OrderRepository struct {
	db *sql.DB
}

func NewOrderRepository(db *sql.DB) *OrderRepository {
	return &OrderRepository{db: db}
}

// compile-time check that we satisfy the domain port
var _ order.Repository = (*OrderRepository)(nil)

func (r *OrderRepository) Save(o *order.Order) error {
	_, err := r.db.Exec(
		"INSERT INTO orders (id, total, status) VALUES ($1, $2, $3)",
		o.ID, o.Total, o.Status,
	)
	return err
}
```

Note the dependency now points the right way: `postgres` -> `order`. The `order` package imports nothing from `postgres`.

### 4. Wire it up in `cmd/server/main.go`

`main` is the composition root — the right place to know about both the database and the domain, and to glue them together:

```go
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
	if err := svc.Place(o); err != nil {
		log.Fatal(err)
	}
}
```

## Resulting shape

```
internal/order/order.go              // pure domain type + business rules (no sql)
internal/order/repository.go         // Repository interface (the port)
internal/order/service.go            // orchestrates rules + save (optional but recommended)
internal/order/postgres/repository.go // SQL adapter, imports order + database/sql
cmd/server/main.go                   // composition root: opens db, wires repo -> service
```

Dependency arrows all point inward toward `order`; the database is a detail at the edge.

## Payoff

- Business rules in `Place` are now unit-testable with zero database — and `Service.Place` is testable with a tiny fake `Repository`.
- The Postgres dialect, table name, and `INSERT` live in one swappable adapter. Switching to another store, or adding a transaction/batch, no longer touches the domain.
- The `order` package import list visibly documents that the core has no infrastructure dependencies, which is the property the `internal/` + `cmd/` layout is meant to give you.

## Minimal vs. full

If a full application-service layer feels heavy for where the project is today, the smallest change that still fixes the core problem is steps 1–4 *without* the `Service`: keep `Place()` pure, define `Repository`, implement it in a `postgres` package, and have `main` call `o.Place()` then `repo.Save(o)`. The non-negotiable part is removing `database/sql` from `order.go` so the dependency stops pointing the wrong way.
