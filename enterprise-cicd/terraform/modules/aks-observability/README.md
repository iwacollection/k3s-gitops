# AKS observability module

Creates the Container Insights DCR/DCRA and Managed Prometheus DCE/DCR/DCRA for a governed AKS cluster. V1 requires the Azure Monitor workspace to be in the same region as the cluster. The AKS module separately enables `oms_agent` and `monitor_metrics` so collection agents are installed with managed identity authentication.
