package order

import (
	"database/sql"
	"errors"
)

// Order is our central domain type.
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

// Place runs the business rules for accepting an order, then persists it.
func (o *Order) Place(db *sql.DB) error {
	if len(o.Items) == 0 {
		return errors.New("order has no items")
	}
	o.Total = 0
	for _, it := range o.Items {
		o.Total += it.Price * it.Quantity
	}
	o.Status = "placed"

	_, err := db.Exec(
		"INSERT INTO orders (id, total, status) VALUES ($1, $2, $3)",
		o.ID, o.Total, o.Status,
	)
	return err
}
