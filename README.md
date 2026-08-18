# k3s-gitops — Azure CI/CD + GitOps template

本仓库分支 cicd/azure-gitops-template 中包含一个 Azure Pipelines + Terraform + Flux v2 的模板骨架，用于快速启动 AKS + ACR + GitOps 流程。

重要提醒
- 你提到已有一个外部 k8s 仓库与集群在使用，请避免同时用本仓库的 GitOps manifests 去管理相同集群中的相同资源，以免冲突。

需要在 Azure/DevOps 上准备的项（示例）

1) Azure Service Connection（Service Principal）
- 在 Azure DevOps 中，进入 Project settings -> Service connections -> New service connection -> Azure Resource Manager。
- 选择 Service principal (manual) 并填写：Subscription ID、Subscription name、Service principal client ID、client secret、tenant ID。
- 给 Service Principal 在订阅或资源组级别分配合适的权限（例如 Contributor 到 TF 需要创建资源，或更细的 RBAC）。
- 在 azure-pipelines-ci.yml 中把变量 `azureSubscription` 设置为该 Service Connection 的名字。

2) Terraform 后端（State）
- 创建 Storage Account 与 Container 用于保存 Terraform state：
  - az group create -n <tf-rg> -l <location>
  - az storage account create -n <tfstateacct> -g <tf-rg> -l <location> --sku Standard_LRS
  - az storage container create --name tfstate --account-name <tfstateacct>
- 在 infra/terraform/backend.tf 填写 storage_account_name 与 resource_group_name。

3) ACR 与 AKS
- 你可以使用 infra/terraform 模块创建 ACR 与 AKS，或先手工创建后再用 Terraform 管理。
- 需要在 Pipeline 中填入以下变量（Azure DevOps Pipeline variables / Variable group）：
  - ACR_NAME 或 ACR_LOGIN_SERVER
  - ACR_PASSWORD（如果使用 admin 用户，或使用 Service Principal 登录后 az acr login）
  - TF_AKS_RG
  - TF_AKS_CLUSTER

4) Azure DevOps Pipeline 权限建议
- 把敏感变量放入 Pipeline 的 Library -> Variable groups，并勾选“Keep this value secret”。
- 限制谁能编辑/运行 CI：在 Pipeline 权限设置里只允许特定组触发/管理 Pipeline。启用分支保护规则以强制 PR 审核。

5) Preview 环境（Ephemeral PR）
- CI 在 PR 时构建镜像并在 AKS 创建 preview-<PRID> 命名空间并部署 k8s manifests，PR 关闭时清理该 namespace。
- 注：自动在 PR close 时触发 Cleanup 需要额外的 Service Hook 或独立 pipeline（示例脚本位于 scripts/）。

6) 安全扫描/检查
- 已在 Pipeline 示例里加入 tflint、checkov（用于 Terraform/IaC 静态检查）以及 Trivy（容器镜像扫描）。
- 在合并到 main 之前，建议在 pipeline 将这些检查设为必须通过。

7) Flux v2 & GitOps
- clusters/gitops/ 目录包含 Flux skeleton。请在不同于现有 GitOps 仓库管理的命名空间或测试集群中先验证，不要直接对生产集群进行未审核 bootstrapping。

快速开始
1. 在 Azure 中准备 Service Principal & Storage Account (Terraform backend) & ACR.
2. 在 Azure DevOps 创建 Service Connection 并把名字配置到 pipeline 变量 `azureSubscription`。
3. 在 Azure DevOps 导入此仓库并创建 pipeline，或使用 YAML pipeline 配置直接指向 .azure-pipelines/azure-pipelines-ci.yml。
4. 创建 PR 测试 preview 流程（务必在测试集群先验证）。

需要我帮你做的下一步（我可以代劳）
- 我可以把 PR body 更新为更详尽的 PR 描述（.pull_request.md），并添加 reviewers/labels（请给出 reviewers 列表）。
- 我可以把 Terraform modules 进一步完善为可直接创建 AKS/ACR（适用于生产），并提供示例变量文件。
- 我可以把 Azure Pipelines 的 Cleanup 流程改为基于 GitHub/ADO service hooks 的独立 pipeline，实现 PR close 自动清理。

