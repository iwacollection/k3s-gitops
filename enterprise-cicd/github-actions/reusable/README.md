# GitHub Reusable Workflows

Executable GitHub reusable workflows must live directly under `.github/workflows/`. GitHub does not execute reusable workflows from this directory.

Canonical workflows:

- `.github/workflows/reusable-application-ci-v1.yml` — single-application governed CI DAG.
- `.github/workflows/reusable-application-ci-matrix-v1.yml` — matrix orchestrator for multiple application definitions.

Application repositories should call the canonical workflows instead of copying enterprise pipeline logic.

Orchestration rule:

```text
matrix = horizontal parallelism
needs = vertical DAG dependencies
Reusable Workflow = centrally governed capability
```

Do not keep a second executable copy here. Duplicated workflows create policy and security drift.
