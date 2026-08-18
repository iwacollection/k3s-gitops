package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
)

type response struct {
    Status string `json:"status"`
    Commit string `json:"commit"`
}

func main() {
    commit := os.Getenv("APP_COMMIT")
    if commit == "" {
        commit = "local"
    }

    http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        _ = json.NewEncoder(w).Encode(response{Status: "ok", Commit: commit})
    })

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        _ = json.NewEncoder(w).Encode(response{Status: "enterprise-cicd-smoke", Commit: commit})
    })

    log.Println("listening on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
