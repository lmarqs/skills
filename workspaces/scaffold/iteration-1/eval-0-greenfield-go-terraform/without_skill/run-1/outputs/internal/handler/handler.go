// Package handler holds the HTTP handlers shared by the API server and the
// Lambda entrypoint.
package handler

import (
	"encoding/json"
	"net/http"
)

// New builds the service's HTTP handler.
func New() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", health)
	return mux
}

func health(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	//nolint:errcheck // best-effort write to the response stream
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}
