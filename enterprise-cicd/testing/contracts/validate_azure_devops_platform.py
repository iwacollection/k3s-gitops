from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    contract = load(ROOT / "azure-devops" / "service-connections" / "terraform-service-connections.json")
    spec = contract["spec"]
    require(spec["authentication"] == "workload-identity-federation", "Azure DevOps Terraform auth must use WIF")
    require(spec["plan"]["mayApply"] is False, "plan connection must never apply")
    require(spec["apply"]["savedPlanRequired"] is True, "apply must consume a saved plan")
    require(spec["serviceConnectionFromRuntimeVariableAllowed"] is False, "service connection must not be selected by runtime variable")
    require(spec["lockBehavior"] == "sequential", "Terraform apply lock behavior must be sequential")
    require(set(spec["prodApplyChecks"]) == {"required-template", "branch-control", "manual-approval", "exclusive-lock"}, "unexpected PROD apply checks")

    expected_connections = {
        "sc-tf-plan-dev", "sc-tf-apply-dev",
        "sc-tf-plan-test", "sc-tf-apply-test",
        "sc-tf-plan-prod", "sc-tf-apply-prod",
    }
    actual_connections = {
        value
        for environment in spec["connections"].values()
        for value in environment.values()
    }
    require(actual_connections == expected_connections, "Terraform service connection set changed unexpectedly")

    pr_pipeline = (ROOT / "azure-devops" / "pipelines" / "workload" / "iac-request-pr.yml").read_text(encoding="utf-8")
    apply_pipeline = (ROOT / "azure-devops" / "pipelines" / "workload" / "iac-request-apply.yml").read_text(encoding="utf-8")
    plan_template = (ROOT / "azure-devops" / "templates" / "terraform" / "request-plan.yml").read_text(encoding="utf-8")
    apply_template = (ROOT / "azure-devops" / "templates" / "terraform" / "request-apply.yml").read_text(encoding="utf-8")
    discovery = ROOT / "ci-scripts" / "infra" / "discover_iac_requests.py"

    require(discovery.is_file(), "IaC request discovery helper is missing")
    require("pr:" in pr_pipeline and "enterprise-cicd/iac-requests/**" in pr_pipeline, "PR pipeline must be scoped to IaC requests")
    require("terraform apply" not in pr_pipeline, "PR entry pipeline must not run terraform apply")
    require("request-apply.yml" not in pr_pipeline, "PR entry pipeline must not include apply template")

    for connection in ("sc-tf-plan-dev", "sc-tf-plan-test", "sc-tf-plan-prod"):
        require(connection in pr_pipeline, f"PR pipeline missing fixed plan connection: {connection}")
    for connection in expected_connections:
        require(connection in apply_pipeline or connection.startswith("sc-tf-plan-") and connection in pr_pipeline, f"pipeline missing fixed service connection: {connection}")

    require("lockBehavior: sequential" in apply_pipeline, "merge/apply pipeline must serialize protected applies")
    require("request-plan.yml" in apply_pipeline, "merge pipeline must re-plan after merge")
    require("request-apply.yml" in apply_pipeline, "merge pipeline must invoke saved-plan apply template")
    require("sc-tf-apply-prod" in apply_pipeline, "PROD apply connection must be explicit")
    require("terraform apply" not in apply_pipeline, "entry pipeline must delegate apply to governed template")

    require("task.uploadsummary" in plan_template, "Terraform plan must be visible as pipeline review summary")
    require("PublishPipelineArtifact@1" in plan_template, "Terraform plan must be published as evidence")
    require("ARM_USE_OIDC=true" in plan_template, "Terraform plan must use OIDC")
    require("terraform -chdir=\"$ROOT_STACK\" apply" in apply_template, "apply template must apply the saved plan")
    require("\"$WORK/tfplan\"" in apply_template, "apply template must consume saved tfplan")
    require("ARM_USE_OIDC=true" in apply_template, "Terraform apply must use OIDC")

    for text in (pr_pipeline, apply_pipeline):
        require("azureServiceConnection: $(" not in text, "service connection cannot be chosen from runtime variable")

    print("AZURE DEVOPS PLATFORM VALIDATION: PASSED")
    print("request discovery -> environment matrices -> fixed plan/apply identities")
    print("PR = plan only; merge = re-plan + protected saved-plan apply")
    print("PROD checks = required template + branch control + approval + exclusive lock")


if __name__ == "__main__":
    main()
