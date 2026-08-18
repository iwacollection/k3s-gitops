#!/usr/bin/env python3
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(name: str):
    path = ROOT / name
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def fail(errors, message):
    errors.append(message)


def main() -> int:
    errors = []

    env = load("environment-contract.json")
    state = load("state-contract.json")
    identity = load("identity-contract.json")
    repo = load("repository-contract.json")

    expected_envs = ["dev", "test", "prod"]
    if env.get("promotion_order") != expected_envs:
        fail(errors, "promotion_order must be dev -> test -> prod")

    environments = env.get("environments", {})
    if list(environments.keys()) != expected_envs:
        fail(errors, "environment contract must define dev, test, prod in order")

    prod = environments.get("prod", {})
    if not prod.get("production_approval_required"):
        fail(errors, "prod must require production approval")
    if not prod.get("exclusive_lock_required"):
        fail(errors, "prod must require exclusive lock")
    if not prod.get("required_template_check"):
        fail(errors, "prod must require a protected pipeline template")
    if "main" not in prod.get("branch_control", []):
        fail(errors, "prod branch control must include main")

    state_rules = state.get("state_rules", {})
    if state_rules.get("commit_state_to_git") is not False:
        fail(errors, "Terraform state must never be committed to Git")
    if state_rules.get("cross_environment_state_access") is not False:
        fail(errors, "cross-environment Terraform state access must be disabled")
    if state_rules.get("plan_write_access") is not False:
        fail(errors, "Terraform plan identity must not have state write access")
    if state_rules.get("apply_write_access") is not True:
        fail(errors, "Terraform apply identity must have state write access")

    keys = list(state.get("platform_keys", {}).values())
    if len(keys) != len(set(keys)):
        fail(errors, "platform Terraform state keys must be unique")
    if not state.get("workload_key_pattern", "").startswith("workload/{environment}/"):
        fail(errors, "workload state keys must be environment-scoped")

    auth = identity.get("authentication", {})
    if auth.get("target") != "workload-identity-federation":
        fail(errors, "CI/CD Azure authentication target must be workload identity federation")
    if auth.get("long_lived_client_secret_allowed") is not False:
        fail(errors, "long-lived CI/CD client secrets must be disabled")
    if auth.get("interactive_user_login_allowed_in_ci") is not False:
        fail(errors, "interactive user login must not be used by CI")

    tf = identity.get("terraform", {})
    if tf.get("cross_environment_identity_reuse") is not False:
        fail(errors, "Terraform identities must not be reused across environments")
    operations = tf.get("operations", {})
    if operations.get("plan", {}).get("may_apply") is not False:
        fail(errors, "plan identity must never be allowed to apply")
    if operations.get("apply", {}).get("may_apply") is not True:
        fail(errors, "apply identity must be the only Terraform operation identity that may apply")

    ado = identity.get("azure_devops", {})
    required_prod_checks = {"required-template", "branch-control", "manual-approval"}
    if not required_prod_checks.issubset(set(ado.get("prod_apply_checks", []))):
        fail(errors, "prod apply service connection must enforce required-template, branch-control, manual-approval")
    if "exclusive-lock" not in ado.get("environment_checks", []):
        fail(errors, "Azure DevOps environments must enforce exclusive-lock")

    development = repo.get("development_model", {})
    if development.get("branching") != "trunk-based":
        fail(errors, "repository model must use trunk-based development")
    if development.get("long_lived_environment_branches_allowed") is not False:
        fail(errors, "long-lived dev/test/prod branches are not allowed")
    if development.get("same_iac_code_promoted_across_environments") is not True:
        fail(errors, "the same IaC code must be promoted across environments")

    repositories = repo.get("target_repositories", {})
    if repositories.get("azure-platform-iac", {}).get("application_team_direct_write") is not False:
        fail(errors, "application teams must not have default direct write to platform IaC")
    if repositories.get("gitops-environments", {}).get("kubernetes_desired_state_source") is not True:
        fail(errors, "gitops-environments must be the Kubernetes desired-state source")
    if repositories.get("application-repositories", {}).get("platform_iac_allowed") is not False:
        fail(errors, "application repositories must not contain platform IaC")

    if errors:
        print("CONTROL CONTRACT VALIDATION: FAILED")
        for item in errors:
            print(f"- {item}")
        return 1

    print("CONTROL CONTRACT VALIDATION: PASSED")
    print("environments: dev -> test -> prod")
    print("state: isolated by stack/environment")
    print("identity: WIF + plan/apply separation")
    print("repository: trunk-based + ownership boundaries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
