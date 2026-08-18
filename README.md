# k3s-gitops — Azure CI/CD + GitOps template

本仓库分支 cicd/azure-gitops-template 中包含一个 Azure Pipelines + Terraform + Flux v2 的模板骨架，用于快速启动 AKS + ACR + GitOps 流程。

重要提醒
- 你提到已有一个外部 k8s 仓库与集群在使用，请避免同时用本仓库的 GitOps manifests 去管理相同集群中的相同资源，以免冲突。

需要在 Azure/DevOps 上准备的项（示例）
- Azure Service Connection（用于 Azure Pipelines）
- Azure 订阅 ID / Tenant ID / Service Principal（用于 Terraform 与 az cli）
- Terraform 后端的 Storage Account 与 Container
- ACR 名称
- AKS 名称与 Resource Group

仓库结构（简要）
- infra/terraform/                # Terraform scaffold（backend + modules）
- .azure-pipelines/               # Azure Pipelines 工作流
- apps/example-service/           # 示例微服务（Dockerfile + k8s manifests）
- clusters/gitops/                # Flux v2 skeleton
- scripts/                        # CI 用的 preview 部署/清理脚本

下一步我在分支里已经提交了这些 scaffold 文件，你可以：
1) 在 Azure 中创建 Service Connection、ACR、AKS（或使用 Terraform 来创建）
2) 在 Azure DevOps 中导入本仓库，配置 pipeline（azure-pipelines-ci.yml）并设定变量/secret
3) 按 README 里提示 bootstrap Flux 到 AKS（或修改为使用 ArgoCD）

如果你确认，我可以：
- 打开一个 Pull Request 将 cicd/azure-gitops-template 分支的变更合并到默认分支；
- 或继续在分支内根据你的反馈完善 Terraform 模块、pipeline 步骤、或把 Flux manifests 做成更完整的示例。

请告诉我你希望我接下来的动作（例如：打开 PR / 继续完善 Terraform / 添加 Helm chart 示例 / 删减 preview 功能等）。
