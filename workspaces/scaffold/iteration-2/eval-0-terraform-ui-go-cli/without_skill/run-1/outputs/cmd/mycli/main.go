// Command mycli is a cross-platform Go CLI tool.
package main

import (
	"fmt"
	"os"
)

// Build metadata, injected at release time via -ldflags.
var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) > 0 && (args[0] == "version" || args[0] == "--version" || args[0] == "-v") {
		fmt.Printf("mycli %s (commit %s, built %s)\n", version, commit, date)
		return nil
	}
	fmt.Println("hello from mycli")
	return nil
}
