# 文档中心（中文）

本目录用于维护生产级 Kubernetes、Terraform、Azure IaC（基础设施即代码）治理文档。

## 推荐学习路径

如果目标不是只会执行 Terraform，而是理解生产 IaC 为什么要这样设计，建议按下面顺序阅读：

1. `IaC-模块封装资源隔离与生产管理学习手册.md`
   - 面向持续学习和复习
   - 解释 Module 为什么要封装、边界怎么划分
   - 解释 Environment、State、Resource Group、Subscription、权限分别隔离什么
   - 解释 State 为什么是 IaC 核心资产、什么时候需要拆 State
   - 解释 Import、Moved、State Migration 如何避免已有生产资源被重建
   - 解释 Plan、Approval、Concurrency、prevent_destroy、Policy Gate 等生产保护机制
   - 结合当前仓库结构说明后续演进方向

2. `IaC-Governance-Production-Management.md`
   - 面向生产治理规范
   - 说明已有 Azure 资源接入、生产变更、权限和风险控制标准

3. `Terraform-Module治理规范.md`
   - 面向 Module 编写和审计规则

4. `Terraform-Backend实施规范.md`
   - 面向 Terraform State 与 Azure Storage Backend 管理

5. `Terraform-Policy-Gate规范.md`
   - 面向策略即代码和危险配置阻断

## IaC 生产管理

核心生产治理文档：

- `IaC-Governance-Production-Management.md`

内容包括：

- Terraform 目录设计
- Environment 与 Module 分层管理
- 已有 Azure 资源接入 Terraform 的完整流程
- Terraform State 管理
- GitHub Actions CI/CD 流程
- 权限控制模型
- 防止错误删除、错误重建的安全机制
- Terraform Plan 审核机制
- Policy as Code（策略即代码）治理

## 学习手册与治理规范的区别

```text
学习手册
    |
    +-- 为什么这样设计？
    +-- 错误做法会发生什么？
    +-- 当前仓库对应在哪里？
    +-- 规模扩大以后怎么演进？

治理规范
    |
    +-- 必须怎么做？
    +-- 哪些行为禁止？
    +-- 生产流程如何执行？
    +-- 审计检查什么？
```

两类文档应同时保留：

- 学习手册帮助理解原理
- 治理规范帮助统一执行标准

## 生产 IaC 标准流程

```text
需求变更
    |
    v
Git Pull Request
    |
    v
Terraform fmt
    |
    v
Terraform validate
    |
    v
TFLint
    |
    v
Checkov 安全扫描
    |
    v
Terraform Plan
    |
    v
策略检查
    |
    v
人工审批
    |
    v
Terraform Apply
    |
    v
生产验证
```

## 生产 IaC 核心记忆模型

```text
Git
= 期望状态

Terraform State
= Terraform 对真实资源的认知和映射

Azure
= 真实状态

IaC 治理
= 让三者在可审计、可控制、可恢复的前提下安全收敛
```

## 文档规范

所有设计说明文档要求：

- 使用中文描述
- 首次出现英文缩写提供中文解释
- 包含生产场景说明
- 包含风险控制方案
- 包含故障恢复方案
- 对学习型文档优先补充“为什么这样做”和常见错误场景
