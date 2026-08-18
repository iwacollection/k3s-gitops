package main

import "testing"

func TestHealth(t *testing.T) {
    if got := health(); got != "go-build-profile-ok" {
        t.Fatalf("unexpected health: %s", got)
    }
}
