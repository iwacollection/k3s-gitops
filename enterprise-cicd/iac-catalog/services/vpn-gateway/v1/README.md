# VPN Gateway v1

Creates the Azure VPN Gateway foundation: dedicated VNet, `GatewaySubnet`, Standard Public IP and RouteBased Virtual Network Gateway.

**Secret boundary:** v1 has no `sharedKey`, `sharedSecret`, password or PSK field and does not create `azurerm_virtual_network_gateway_connection`. Site-to-site connection is a separate protected secret-backed capability.

VPN Gateway is billable and may take a long time to provision, so automatic demo Apply is intentionally disabled.
