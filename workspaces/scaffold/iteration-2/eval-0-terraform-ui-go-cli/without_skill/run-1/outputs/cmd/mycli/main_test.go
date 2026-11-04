package main

import "testing"

func TestRun(t *testing.T) {
	if err := run(nil); err != nil {
		t.Fatalf("run(nil) returned error: %v", err)
	}
	if err := run([]string{"version"}); err != nil {
		t.Fatalf("run(version) returned error: %v", err)
	}
}
