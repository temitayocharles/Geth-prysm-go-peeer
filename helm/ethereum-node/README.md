# Ethereum Node Helm Chart

A Helm chart for deploying Ethereum execution (Geth) and consensus (Prysm) clients on Kubernetes with integrated monitoring.

## Features

- **Execution Layer**: Geth client with configurable sync modes
- **Consensus Layer**: Prysm beacon chain with checkpoint sync
- **Monitoring**: Prometheus and Grafana stack
- **Flexible Configuration**: Light node (~75GB) or full node (~1TB+) deployments
- **Production Ready**: Resource limits, health checks, and persistent storage

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- 75GB+ available storage (light node) or 1TB+ (full node)
- kubectl configured to communicate with your cluster

## Installation

### Quick Start

1. Generate JWT secret:
```bash
cd /Users/charlie/Desktop/debbie-k8s
./scripts/generate-jwt.sh
```

2. Install the chart:
```bash
helm install ethereum-node ./helm/ethereum-node \
  --set jwt.secret="$(cat jwt.hex)" \
  --create-namespace
```

Or use the convenience script:
```bash
./scripts/helm-deploy.sh
```

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.network` | Ethereum network (mainnet, goerli, sepolia) | `mainnet` |
| `global.storageClass` | Storage class for PVCs | `local-path` |
| `geth.syncMode` | Sync mode | `light` |
| `geth.storage.size` | Geth data storage size | `20Gi` |
| `prysm.storage.size` | Prysm data storage size | `40Gi` |
| `monitoring.enabled` | Enable Prometheus/Grafana | `true` |
| `jwt.secret` | JWT secret for auth (required) | `""` |

### Example: Custom Configuration

Create a custom values file to adjust resources:

```yaml
# custom-values.yaml
geth:
  storage:
    size: 50Gi
  resources:
    limits:
      memory: "8Gi"
      cpu: "2000m"

prysm:
  storage:
    size: 60Gi
```

Install with custom values:
```bash
helm install ethereum-node ./helm/ethereum-node \
  --values custom-values.yaml \
  --set jwt.secret="$(cat jwt.hex)"
```

## Accessing Services

### Grafana Dashboard

```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Then open http://localhost:3000 (default login: admin/admin)

### Geth RPC

```bash
kubectl port-forward -n ethereum svc/geth 8545:8545
```

Test connection:
```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

## Monitoring

### Check Pod Status

```bash
kubectl get pods -n ethereum
kubectl get pods -n monitoring
```

### View Logs

```bash
# Geth logs
kubectl logs -f statefulset/geth -n ethereum

# Prysm logs
kubectl logs -f statefulset/prysm-beacon -n ethereum
```

### Storage Usage

```bash
# Geth storage
kubectl exec -n ethereum statefulset/geth -- df -h /data

# Prysm storage
kubectl exec -n ethereum statefulset/prysm-beacon -- df -h /data
```

## Upgrading

Update configuration and upgrade:

```bash
helm upgrade ethereum-node ./helm/ethereum-node \
  --values ./helm/ethereum-node/values.yaml \
  --set jwt.secret="$(cat jwt.hex)"
```

## Uninstalling

### Using Helm

```bash
helm uninstall ethereum-node
kubectl delete namespace ethereum monitoring
```

Or use the convenience script:
```bash
./scripts/helm-cleanup.sh
```

### Clean Up Persistent Volumes

```bash
kubectl get pv
kubectl delete pv <pv-name>
```

## Troubleshooting

### Geth Not Syncing

```bash
kubectl logs -f statefulset/geth -n ethereum
kubectl exec -n ethereum statefulset/geth -- geth attach /data/geth.ipc --exec "eth.syncing"
```

### Prysm Waiting for Geth

Check if Geth is ready:
```bash
kubectl get pods -n ethereum
kubectl logs statefulset/prysm-beacon -n ethereum
```

### Storage Issues

Check PVC status:
```bash
kubectl get pvc -n ethereum
kubectl describe pvc geth-data-geth-0 -n ethereum
```

## Architecture

```
┌─────────────────────────────────────────┐
│           Kubernetes Cluster            │
├─────────────────────────────────────────┤
│                                         │
│  ┌────────────────────────────────┐    │
│  │  Namespace: ethereum           │    │
│  │                                │    │
│  │  ┌──────────┐  ┌───────────┐  │    │
│  │  │   Geth   │  │   Prysm   │  │    │
│  │  │(StatefulSet)│(StatefulSet)│    │
│  │  └────┬─────┘  └─────┬──────┘  │    │
│  │       │              │         │    │
│  │  ┌────▼──────────────▼─────┐   │    │
│  │  │    JWT Secret           │   │    │
│  │  └─────────────────────────┘   │    │
│  └────────────────────────────────┘    │
│                                         │
│  ┌────────────────────────────────┐    │
│  │  Namespace: monitoring         │    │
│  │                                │    │
│  │  ┌────────────┐ ┌──────────┐  │    │
│  │  │ Prometheus │ │ Grafana  │  │    │
│  │  └────────────┘ └──────────┘  │    │
│  └────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

## Values Files

- `values.yaml` - Default light node configuration (~75GB)
- `values-full.yaml` - Full node configuration (~1TB+)

## Support

For issues and questions:
- Check the troubleshooting section above
- Review Kubernetes events: `kubectl get events -n ethereum`
- Check resource usage: `kubectl top pods -n ethereum`

## License

This Helm chart is provided as-is for deploying Ethereum nodes on Kubernetes.
