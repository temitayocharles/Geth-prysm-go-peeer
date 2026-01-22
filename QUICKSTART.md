# Quick Start Guide

Get your Ethereum node running in under 10 minutes!

## Prerequisites

- Kubernetes cluster running (Minikube, Kind, or cloud provider)
- `kubectl` configured
- `docker` installed
- At least 1.5TB storage available

## Option 1: Automated Deployment (Recommended)

```bash
# Run the deployment script
./scripts/deploy-all.sh
```

That's it! The script will:
1. Create namespaces
2. Generate JWT secret
3. Deploy Geth and Prysm
4. Set up Prometheus and Grafana
5. Build and deploy the peer monitor

## Option 2: Manual Deployment

### Step 1: Generate JWT Secret

```bash
./scripts/generate-jwt.sh
```

### Step 2: Deploy Ethereum Node

```bash
# Create namespaces
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/monitoring/namespace.yaml

# Deploy Geth
kubectl apply -f k8s/geth/

# Wait for Geth to start (30 seconds)
sleep 30

# Deploy Prysm
kubectl apply -f k8s/prysm/
```

### Step 3: Deploy Monitoring

```bash
kubectl apply -f k8s/monitoring/
```

### Step 4: Deploy Peer Monitor

```bash
# Build the image
cd go-peer-monitor
docker build -t peer-monitor:latest .

# Load into cluster (if using Minikube)
minikube image load peer-monitor:latest

# Deploy
kubectl apply -f k8s/peer-monitor/
```

## Verify Deployment

```bash
./scripts/check-status.sh
```

Or manually:

```bash
# Check pods
kubectl get pods -n ethereum
kubectl get pods -n monitoring

# Watch Geth sync
kubectl logs -f statefulset/geth -n ethereum

# Watch Prysm sync
kubectl logs -f statefulset/prysm-beacon -n ethereum

# View peer connections
kubectl logs -f deployment/peer-monitor -n ethereum
```

## Access Monitoring

### Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

Open http://localhost:9090

### Grafana

```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Open http://localhost:3000
- Username: `admin`
- Password: `admin`

Import dashboards:
- Geth: Dashboard ID `6976`
- Prysm: Dashboard ID `12704`

## Check Sync Status

### Geth Sync

```bash
kubectl exec -it statefulset/geth -n ethereum -- geth attach http://localhost:8545 -exec "eth.syncing"
```

Returns `false` when fully synced, or shows sync progress.

### Prysm Sync

```bash
kubectl exec -it statefulset/prysm-beacon -n ethereum -- curl http://localhost:3500/eth/v1/node/syncing
```

Check `is_syncing` field in the response.

## Run Peer Monitor Locally

If you want to run the Go program outside Kubernetes:

```bash
# Forward Geth RPC port
kubectl port-forward -n ethereum svc/geth 8545:8545

# In another terminal
cd go-peer-monitor
export GETH_RPC_URL=http://localhost:8545
go run main.go
```

## Troubleshooting

### Pods not starting?

```bash
# Check events
kubectl get events -n ethereum --sort-by='.lastTimestamp'

# Describe pod
kubectl describe pod <pod-name> -n ethereum
```

### No storage available?

Check if your cluster has a default storage class:

```bash
kubectl get storageclass
```

If not, you may need to create one or use a different storage class in the PVC manifests.

### Peer monitor can't connect?

Ensure Geth is running and accessible:

```bash
kubectl port-forward -n ethereum svc/geth 8545:8545

# Test connection
curl http://localhost:8545 -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}'
```

## Cleanup

To remove everything:

```bash
./scripts/cleanup.sh
```

Or manually:

```bash
kubectl delete namespace ethereum
kubectl delete namespace monitoring
```

## Next Steps

- Read [README.md](README.md) for detailed documentation
- Review [DESIGN.md](DESIGN.md) for architecture and security considerations
- Monitor sync progress (initial sync takes 1-7 days)
- Set up alerting for production use

## Support

For issues, check:
1. Pod logs: `kubectl logs <pod-name> -n ethereum`
2. Events: `kubectl get events -n ethereum`
3. Resource usage: `kubectl top pods -n ethereum`

Still stuck? Open an issue in this repository.
