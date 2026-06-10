package main

import (
	"database/sql"
	"log"
	"os"

	_ "github.com/lib/pq"

	"example.com/shop/internal/order"
)

func main() {
	db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	o := &order.Order{
		ID:    "ord_123",
		Items: []order.Item{{SKU: "abc", Quantity: 2, Price: 500}},
	}
	if err := o.Place(db); err != nil {
		log.Fatal(err)
	}
}
