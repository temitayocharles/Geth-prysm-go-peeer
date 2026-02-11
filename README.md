# Ethereum Mainnet Node on Kubernetes


## Start Here
- Read [START_HERE.md](START_HERE.md) for the chronological playbook.

This project deploys a fully functional Ethereum Mainnet node on Kubernetes using:
- **Execution Client**: Geth
- **Consensus Client**: Prysm
- **Monitoring**: Prometheus & Grafana
- **Peer Monitoring**: Custom Go application


## Documentation Index
- [.github/instructions/snyk_rules.instructions.md](.github/instructions/snyk_rules.instructions.md)
- [DESIGN.md](DESIGN.md)
- [HELM_GUIDE.md](HELM_GUIDE.md)
- [INTERVIEW_PREP.md](INTERVIEW_PREP.md)

## Deployment Options

### Helm (Recommended)
Template-based deployment with easy configuration management:
```bash
./scripts/helm-deploy.sh          # Deploy Ethereum node (~75GB)
```
**[Helm Guide](./HELM_GUIDE.md)**

### kubectl (Traditional)
Direct Kubernetes manifest deployment:
```bash
./scripts/deploy.sh               # Deploy using kubectl
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Kubernetes Cluster                      │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Ethereum Namespace                       │  │
│  │                                                       │  │
│  │  ┌──────────┐         ┌──────────┐                  │  │
│  │  │   Geth   │◄───────►│  Prysm   │                  │  │
│  │  │ (Exec)   │ JWT Auth│ (Beacon) │                  │  │
│  │  └────┬─────┘         └────┬─────┘                  │  │
│  │       │                    │                         │  │
│  │       │                    │                         │  │
│  │  ┌────▼────────────────────▼─────┐                  │  │
│  │  │     Peer Monitor (Go)         │                  │  │
│  │  └────────────┬──────────────────┘                  │  │
│  └───────────────┼───────────────────────────────────────┘  │
│                  │                                           │
│  ┌───────────────▼───────────────────────────────────────┐  │
│  │              Monitoring Namespace                     │  │
│  │                                                       │  │
│  │  ┌──────────┐         ┌──────────┐                  │  │
│  │  │Prometheus│◄────────┤ Grafana  │                  │  │
│  │  └──────────┘         └──────────┘                  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Kubernetes cluster (local or cloud)
  - **Mac**: OrbStack (recommended), Rancher Desktop, k3d, or Minikube
  - **Windows**: Rancher Desktop (recommended), k3d, or Docker Desktop
  - **Linux**: k3d (recommended), Rancher Desktop, or Minikube
  - **Cloud**: GKE, EKS, or AKS
  - See [DEPLOYMENT_ENVIRONMENTS.md](DEPLOYMENT_ENVIRONMENTS.md) for detailed setup guides
- `kubectl` configured to access your cluster
- Docker installed (for building the peer monitor image)

### Storage Requirements

**CHOOSE YOUR SETUP BASED ON AVAILABLE STORAGE:**

| Storage Available | Setup Type | Total Required | Capabilities |
|-------------------|------------|----------------|--------------|
| **< 100GB** | **Light Node** | ~75GB | Real-time data<br>No historical queries<br>Cannot validate |
| **100GB - 500GB** | **Partial Sync** | ~100GB | Recent history<br>Limited historical queries |
| **500GB - 1TB** | **Snap Sync** | ~500GB | Most features<br>Good historical data |
| **1.5TB+** | **Full Node** | ~1.5TB | Complete archive<br>All features |

**If you have < 100GB available storage**, use the light client setup documented below and in [DEPLOYMENT_ENVIRONMENTS.md](DEPLOYMENT_ENVIRONMENTS.md#low-storage-setup--100gb-available).

### Minimum Resources
- **Full Node**: 16GB RAM, 4 CPU cores
- **Light Node**: 4GB RAM, 1 CPU core

## Quick Start

### Choose Your Deployment Type

#### Option A: Light Node (< 100GB Storage Available)

If you have limited storage (less than 100GB available), use the light client configuration:

```bash
# Create namespaces
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/monitoring/namespace.yaml

# Deploy Geth (Light Mode)
kubectl apply -f k8s/geth/statefulset-light.yaml
kubectl apply -f k8s/geth/service.yaml

# Deploy Prysm (Minimal Storage)
kubectl apply -f k8s/prysm/statefulset-light.yaml
kubectl apply -f k8s/prysm/service.yaml

# Deploy Monitoring
kubectl apply -f k8s/monitoring/
```

**Storage Breakdown:**
- Geth: 20GB (light sync)
- Prysm: 40GB (checkpoint only)
- Prometheus: 10GB
- Grafana: 5GB
- **Total: ~75GB**

**Limitations:**
- Cannot query old transactions/blocks
- Cannot run as validator
- Depends on other full nodes

#### Option B: Full Node (1.5TB+ Storage Available)

### Part A: Deploy Ethereum Node with Monitoring

#### 1. Generate JWT Secret

First, generate a JWT secret for authentication between Geth and Prysm:

```bash
./scripts/generate-jwt.sh
```

Or manually:

```bash
openssl rand -hex 32 > jwt.hex
kubectl create namespace ethereum
kubectl create secret generic jwt-secret \
  --from-file=jwt.hex=jwt.hex \
  --namespace=ethereum
```

#### 2. Deploy the Ethereum Node

```bash
# Create namespaces
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/monitoring/namespace.yaml

# Deploy Geth (Execution Client)
kubectl apply -f k8s/geth/

# Deploy Prysm (Consensus Client)
kubectl apply -f k8s/prysm/

# Deploy Monitoring Stack
kubectl apply -f k8s/monitoring/prometheus-rbac.yaml
kubectl apply -f k8s/monitoring/prometheus-config.yaml
kubectl apply -f k8s/monitoring/prometheus-deployment.yaml
kubectl apply -f k8s/monitoring/grafana-config.yaml
kubectl apply -f k8s/monitoring/grafana-deployment.yaml
```

#### 3. Verify Deployment

```bash
# Check Geth status
kubectl logs -f statefulset/geth -n ethereum

# Check Prysm status
kubectl logs -f statefulset/prysm-beacon -n ethereum

# Check all pods
kubectl get pods -n ethereum
kubectl get pods -n monitoring
```

#### 4. Access Monitoring

**Prometheus:**
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090
```

**Grafana:**
```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000
# Login: admin / admin
```

### Part B: Deploy Peer Monitor

#### 1. Build the Go Application

```bash
cd go-peer-monitor

# Build Docker image
docker build -t peer-monitor:latest .

# If using Minikube, load the image
minikube image load peer-monitor:latest

# If using Kind, load the image
kind load docker-image peer-monitor:latest
```

#### 2. Deploy Peer Monitor

```bash
kubectl apply -f k8s/peer-monitor/deployment.yaml
```

#### 3. View Peer Information

```bash
# Stream peer information logs
kubectl logs -f deployment/peer-monitor -n ethereum
```

You should see output like:

```
=== Connected Peers at 2024-01-21 10:30:45 ===
Total Peers: 12

Peer 1:
  ID: enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@52.16.188.185:30303
  Name: Geth/v1.13.8-stable/linux-amd64/go1.21.5
  Remote Address: 52.16.188.185:30303
  Capabilities: [eth/67 eth/68 snap/1]
  ETH Protocol: {
    "difficulty": 58750003716598352816469,
    "head": "0x1234...",
    "version": 68
  }
...
================================
```

## Running Standalone (Part B Only)

If you want to run the peer monitor locally without Kubernetes:

```bash
cd go-peer-monitor

# Set Geth RPC URL (use port-forwarding if Geth is in k8s)
export GETH_RPC_URL=http://localhost:8545

# Run the application
go run main.go
```

## Monitoring Sync Progress

### Check Geth Sync Status

```bash
kubectl exec -it statefulset/geth -n ethereum -- geth attach http://localhost:8545 -exec "eth.syncing"
```

### Check Prysm Sync Status

```bash
kubectl exec -it statefulset/prysm-beacon -n ethereum -- curl http://localhost:3500/eth/v1/node/syncing
```

### Using Grafana Dashboards

1. Access Grafana at http://localhost:3000 (after port-forwarding)
2. Import pre-built dashboards:
   - Geth Metrics Dashboard: Import ID `6976`
   - Prysm Dashboard: Import ID `12704`
3. Custom dashboard for peer monitoring is available via Prometheus metrics

## Prometheus Metrics

The setup exposes the following metrics endpoints:

- **Geth**: `http://geth.ethereum.svc.cluster.local:6060/debug/metrics/prometheus`
- **Prysm**: `http://prysm-beacon.ethereum.svc.cluster.local:8080/metrics`
- **Peer Monitor**: `http://peer-monitor.ethereum.svc.cluster.local:8080/metrics`

Key metrics:
- `geth_peer_count`: Number of connected peers
- `chain_head_block`: Current block number
- `p2p_peers`: Detailed peer statistics

## Configuration

### Storage Requirements

The default configuration requests:
- **Geth**: 1TB (will grow over time)
- **Prysm**: 500GB
- **Prometheus**: 50GB
- **Grafana**: 10GB

Adjust in the respective PVC manifests if needed.

### Resource Limits

Default resource allocations:
- **Geth**: 8-16GB RAM, 2-4 CPUs
- **Prysm**: 4-8GB RAM, 1-2 CPUs
- **Prometheus**: 2-4GB RAM, 0.5-1 CPU
- **Grafana**: 512MB-1GB RAM, 0.25-0.5 CPU

### Network Ports

**Geth:**
- 8545: HTTP RPC
- 8546: WebSocket RPC
- 8551: Engine API (JWT authenticated)
- 30303: P2P (TCP/UDP)
- 6060: Metrics

**Prysm:**
- 4000: HTTP API
- 3500: gRPC Gateway
- 8080: Metrics
- 13000: P2P TCP
- 12000: P2P UDP

## Troubleshooting

### Geth won't start
- Check JWT secret exists: `kubectl get secret jwt-secret -n ethereum`
- Verify storage provisioning: `kubectl get pvc -n ethereum`
- Check logs: `kubectl logs statefulset/geth -n ethereum`

### Prysm won't connect to Geth
- Ensure Geth is running and healthy
- Verify JWT secret is correctly mounted
- Check network connectivity: `kubectl exec -it statefulset/prysm-beacon -n ethereum -- nc -zv geth.ethereum.svc.cluster.local 8551`

### Peer Monitor can't connect
- Verify Geth RPC is accessible: `kubectl port-forward -n ethereum svc/geth 8545:8545`
- Test connection: `curl http://localhost:8545 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"admin_peers","params":[],"id":1}'`

### Slow sync times
- Initial sync can take 1-7 days depending on hardware
- Prysm uses checkpoint sync to speed up beacon chain sync
- Monitor sync progress with the commands in "Monitoring Sync Progress" section

## Cleanup

To remove all resources:

```bash
kubectl delete namespace ethereum
kubectl delete namespace monitoring
```

To remove specific components:

```bash
# Remove peer monitor
kubectl delete -f k8s/peer-monitor/

# Remove monitoring
kubectl delete -f k8s/monitoring/

# Remove Ethereum nodes
kubectl delete -f k8s/prysm/
kubectl delete -f k8s/geth/
```

## Production Considerations

See [DESIGN.md](DESIGN.md) for detailed discussion of:
- Design Process
- Technology Choices
- Security Considerations
- Future Improvements for Production

## License

MIT

## Additional Documentation

- [DEPLOYMENT_ENVIRONMENTS.md](DEPLOYMENT_ENVIRONMENTS.md) - Detailed deployment guides for different platforms
- [STORAGE_GUIDE.md](STORAGE_GUIDE.md) - Complete storage optimization and sizing guide
- [DESIGN.md](DESIGN.md) - Architecture decisions and security considerations
- [TESTING.md](TESTING.md) - Testing strategies and verification
- [NEXT_STEPS.md](NEXT_STEPS.md) - Interview preparation and advanced topics

## Support

For issues or questions, please open an issue in this repository.
