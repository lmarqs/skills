// Command api runs the service as a standalone HTTP server.
package main

import (
	"log"
	"net/http"
	"os"

	"github.com/Medprev/go-api-service/internal/handler"
)

func main() {
	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8080"
	}

	log.Printf("listening on %s", addr)

	if err := http.ListenAndServe(addr, handler.New()); err != nil { //nolint:gosec // local dev server
		log.Fatalf("server error: %v", err)
	}
}
