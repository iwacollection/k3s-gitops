package terraform

# Terraform Plan Policy Gate
#
# 输入：terraform show -json tfplan.json
# 输出：deny[] 中的每一条消息都会使 Conftest 失败。
#
# 设计原则：
# 1. 高风险变更默认阻断；
# 2. 不依赖 Azure 实时查询，PR 阶段只审查变更意图；
# 3. 规则必须能解释“为什么失败、怎么修”；
# 4. 真实生产环境的 Apply 仍必须经过独立审批。

critical_resource_types := {
  "azurerm_kubernetes_cluster",
  "azurerm_postgresql_flexible_server",
  "azurerm_key_vault",
  "azurerm_virtual_network",
  "azurerm_subnet",
  "azurerm_network_security_group",
  "azurerm_redis_cache",
  "azurerm_container_registry",
}

# 规则 PG001：禁止任何生产 Plan 直接删除资源。
deny contains msg if {
  rc := input.resource_changes[_]
  rc.change.actions[_] == "delete"
  msg := sprintf("PG001 BLOCK: 禁止生产资源删除：%s (%s)。如确需删除，必须走受控迁移/下线流程并取得专项审批。", [rc.address, rc.type])
}

# 规则 PG002：禁止核心资源出现 replace（delete + create）。
deny contains msg if {
  rc := input.resource_changes[_]
  critical_resource_types[rc.type]
  rc.change.actions[_] == "delete"
  rc.change.actions[_] == "create"
  msg := sprintf("PG002 BLOCK: 核心资源禁止原地重建：%s (%s)。必须先分析 ForceNew/配置差异，并采用迁移或显式豁免流程。", [rc.address, rc.type])
}

# 规则 PG003：Azure RBAC 禁止高危角色直接授予生产主体。
deny contains msg if {
  rc := input.resource_changes[_]
  rc.type == "azurerm_role_assignment"
  after := object.get(rc.change, "after", {})
  role := lower(object.get(after, "role_definition_name", ""))
  role == "owner"
  msg := sprintf("PG003 BLOCK: 禁止生产环境授予 Owner：%s。请使用最小权限角色并限定 scope。", [rc.address])
}

deny contains msg if {
  rc := input.resource_changes[_]
  rc.type == "azurerm_role_assignment"
  after := object.get(rc.change, "after", {})
  role := lower(object.get(after, "role_definition_name", ""))
  role == "contributor"
  msg := sprintf("PG004 BLOCK: 禁止通过 Terraform 向生产主体授予 Contributor：%s。请改用具体服务角色。", [rc.address])
}

# 规则 PG005：Storage Account 禁止开启公网网络访问。
deny contains msg if {
  rc := input.resource_changes[_]
  rc.type == "azurerm_storage_account"
  after := object.get(rc.change, "after", {})
  object.get(after, "public_network_access_enabled", true) == true
  msg := sprintf("PG005 BLOCK: Storage Account 禁止公网网络访问：%s。优先使用 Private Endpoint/受控网络入口。", [rc.address])
}

# 规则 PG006：数据库禁止公网访问。
deny contains msg if {
  rc := input.resource_changes[_]
  rc.type == "azurerm_postgresql_flexible_server"
  after := object.get(rc.change, "after", {})
  object.get(after, "public_network_access_enabled", true) == true
  msg := sprintf("PG006 BLOCK: PostgreSQL Flexible Server 禁止公网访问：%s。", [rc.address])
}

# 规则 PG007：生产资源必须具备最低 Tag 契约。
required_tags := {"Environment", "Owner", "ManagedBy", "CostCenter"}

tagged_resource_types := {
  "azurerm_resource_group",
  "azurerm_storage_account",
  "azurerm_kubernetes_cluster",
  "azurerm_container_registry",
  "azurerm_key_vault",
  "azurerm_redis_cache",
  "azurerm_postgresql_flexible_server",
  "azurerm_virtual_network",
  "azurerm_network_security_group",
}

deny contains msg if {
  rc := input.resource_changes[_]
  tagged_resource_types[rc.type]
  after := object.get(rc.change, "after", {})
  tags := object.get(after, "tags", {})
  missing := required_tags - {k | tags[k] != null; k := k}
  count(missing) > 0
  msg := sprintf("PG007 BLOCK: 资源缺少生产必需 Tag：%s；缺失=%v。", [rc.address, missing])
}

# 规则 PG008：NSG 禁止向互联网开放高风险管理端口。
high_risk_ports := {"22", "3389", "2379", "2380", "6443", "10250"}

deny contains msg if {
  rc := input.resource_changes[_]
  rc.type == "azurerm_network_security_rule"
  after := object.get(rc.change, "after", {})
  source := lower(sprintf("%v", [object.get(after, "source_address_prefix", "")]))
  source == "*"
  destination := sprintf("%v", [object.get(after, "destination_port_range", "")])
  high_risk_ports[destination]
  msg := sprintf("PG008 BLOCK: NSG 管理端口禁止向互联网开放：%s port=%s。必须限制来源 CIDR/安全边界。", [rc.address, destination])
}

# 规则 PG009：Terraform 资源变更必须能被明确分类；未知动作不允许静默通过。
deny contains msg if {
  rc := input.resource_changes[_]
  action := rc.change.actions[_]
  not action == "create"
  not action == "update"
  not action == "delete"
  msg := sprintf("PG009 BLOCK: 发现未知 Terraform action：%s action=%s。需要人工确认 Policy Engine 兼容性。", [rc.address, action])
}
