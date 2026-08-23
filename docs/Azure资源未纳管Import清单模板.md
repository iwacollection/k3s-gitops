# Azure资源未纳管Import清单模板

用于已有Azure资源接入Terraform管理。

|资源名称|资源类型|Resource ID|环境|Terraform资源|状态|
|-|-|-|-|-|-|
| | | | | | |

## 接入流程

1. Azure资源盘点
2. Terraform Resource定义
3. terraform import
4. terraform plan校准
5. 合并进入main

## 风险检查

重点关注：

- 是否会destroy
- 是否会replace
- 是否修改网络
- 是否影响AKS
- 是否影响数据服务
