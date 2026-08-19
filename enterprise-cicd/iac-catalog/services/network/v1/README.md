# Network Catalog v1

`network/v1` is the low-risk DEV self-service network profile.

A requester supplies only:

- `addressSpace` — RFC1918 IPv4 CIDR for the VNet.
- `subnetName` — one application subnet name.
- `subnetPrefix` — RFC1918 IPv4 subnet CIDR contained by `addressSpace`.

The platform renderer maps the request to the existing `platform/connectivity` root stack but forcibly disables all optional paid or higher-risk network features:

- no NAT Gateway
- no Public IP
- no VNet Peering
- no VPN/Application Gateway
- no Private Endpoint
- no Private DNS zone
- no Route Table
- no NSG in v1
- no delegated subnet or service endpoint

`network/v1` is DEV-only. TEST/PROD remain fail-closed until their network approval and IPAM controls are explicitly activated.
