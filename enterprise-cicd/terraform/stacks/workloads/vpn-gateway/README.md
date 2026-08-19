# VPN Gateway Root Stack

Creates a dedicated VNet, Azure-required `GatewaySubnet`, Standard Public IP and RouteBased Azure Virtual Network Gateway.

v1 intentionally does **not** create a Virtual Network Gateway Connection and never accepts an IPsec pre-shared key in Git. S2S connection activation belongs to a protected secret-backed capability.
