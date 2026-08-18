package main

import (
    "fmt"
    "log"
    "net/http"
    "os"
)

func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        _, _ = w.Write([]byte("ok\n"))
    })
    mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        commit := os.Getenv("APP_COMMIT")
        if commit == "" {
            commit = "dev"
        }
        _, _ = fmt.Fprintf(w, "enterprise-cicd smoke service commit=%s\n", commit)
    })

    log.Println("listening on :8080")
    log.Fatal(http.ListenAndServe(":8080", mux))
}
