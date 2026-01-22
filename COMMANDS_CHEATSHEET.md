# Commands Cheatsheet

Quick reference for common operations.

## Deployment

```bash
# Full automated deployment
./scripts/deploy-all.sh

# Manual step-by-step
./scripts/generate-jwt.sh
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/monitoring/namespace.yaml
kubectl apply -f k8s/geth/
kubectl apply -f k8s/prysm/
kubectl apply -f k8s/monitoring/
kubectl apply -f k8s/peer-monitor/

# Check status
./scripts/check-status.sh
```

## Pod Management

```bash
# List all pods
kubectl get pods -n ethereum
kubectl get pods -n monitoring

# Get pod details
kubectl describe pod <pod-name> -n ethereum

# Watch pod status
kubectl get pods -n ethereum --watch

# Check events
kubectl get events -n ethereum --sort-by='.lastTimestamp'

# Get pod logs
kubectl logs -f statefulset/geth -n ethereum
kubectl logs -f statefulset/prysm-beacon -n ethereum
kubectl logs -f deployment/peer-monitor -n ethereum

# Execute commands in pod
kubectl exec -it geth-0 -n ethereum -- /bin/sh
kubectl exec -it prysm-beacon-0 -n ethereum -- /bin/sh
```

## Monitoring

```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Port forward Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Port forward Geth RPC
kubectl port-forward -n ethereum svc/geth 8545:8545

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Query Prometheus metrics
curl 'http://localhost:9090/api/v1/query?query=geth_peer_count'
```

## Geth Commands

```bash
# Attach to Geth console
kubectl exec -it geth-0 -n ethereum -- geth attach http://localhost:8545

# Check sync status
kubectl exec -n ethereum geth-0 -- \
  geth attach http://localhost:8545 --exec "eth.syncing"

# Get current block number
kubectl exec -n ethereum geth-0 -- \
  geth attach http://localhost:8545 --exec "eth.blockNumber"

# Get peer count
kubectl exec -n ethereum geth-0 -- \
  geth attach http://localhost:8545 --exec "admin.peers.length"

# Get peer info
kubectl exec -n ethereum geth-0 -- \
  geth attach http://localhost:8545 --exec "admin.peers"

# Get node info
kubectl exec -n ethereum geth-0 -- \
  geth attach http://localhost:8545 --exec "admin.nodeInfo"
```

## Geth RPC Commands (via curl)

```bash
# Port forward first
kubectl port-forward -n ethereum svc/geth 8545:8545

# Get network version
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}'

# Get current block number
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Get sync status
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'

# Get peer count
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'

# Get connected peers (admin API)
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"admin_peers","params":[],"id":1}'

# Get latest block
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}'
```

## Prysm Commands

```bash
# Check sync status
kubectl exec -n ethereum prysm-beacon-0 -- \
  curl -s http://localhost:3500/eth/v1/node/syncing | jq .

# Get node version
kubectl exec -n ethereum prysm-beacon-0 -- \
  curl -s http://localhost:3500/eth/v1/node/version | jq .

# Get peer count
kubectl exec -n ethereum prysm-beacon-0 -- \
  curl -s http://localhost:3500/eth/v1/node/peer_count | jq .

# Get node health
kubectl exec -n ethereum prysm-beacon-0 -- \
  curl -s http://localhost:3500/healthz

# Get beacon head
kubectl exec -n ethereum prysm-beacon-0 -- \
  curl -s http://localhost:3500/eth/v1/beacon/headers/head | jq .
```

## Storage

```bash
# List PVCs
kubectl get pvc -n ethereum

# Get PVC details
kubectl describe pvc geth-data-geth-0 -n ethereum

# Check disk usage
kubectl exec -n ethereum geth-0 -- df -h /data
kubectl exec -n ethereum prysm-beacon-0 -- df -h /data

# Check available storage classes
kubectl get storageclass

# Check PVs
kubectl get pv
```

## Secrets

```bash
# View JWT secret
kubectl get secret jwt-secret -n ethereum -o yaml

# Decode JWT secret
kubectl get secret jwt-secret -n ethereum -o jsonpath='{.data.jwt\.hex}' | base64 -d

# Verify JWT in pod
kubectl exec -n ethereum geth-0 -- cat /secrets/jwt.hex
kubectl exec -n ethereum prysm-beacon-0 -- cat /secrets/jwt.hex
```

## Services & Networking

```bash
# List services
kubectl get svc -n ethereum
kubectl get svc -n monitoring

# Get service details
kubectl describe svc geth -n ethereum

# Test service connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://geth.ethereum.svc.cluster.local:8545

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup geth.ethereum.svc.cluster.local
```

## Resource Usage

```bash
# Check pod resource usage
kubectl top pods -n ethereum
kubectl top pods -n monitoring

# Check node resource usage
kubectl top nodes

# Get pod resource limits
kubectl get pod geth-0 -n ethereum -o json | jq '.spec.containers[].resources'
```

## Troubleshooting

```bash
# Restart a pod
kubectl delete pod geth-0 -n ethereum
kubectl delete pod prysm-beacon-0 -n ethereum

# Scale down (to stop)
kubectl scale statefulset geth -n ethereum --replicas=0

# Scale up (to start)
kubectl scale statefulset geth -n ethereum --replicas=1

# Force delete stuck pod
kubectl delete pod geth-0 -n ethereum --force --grace-period=0

# Check pod events
kubectl get events --field-selector involvedObject.name=geth-0 -n ethereum

# Debug with temporary pod
kubectl run -it --rm debug --image=busybox --restart=Never -n ethereum -- sh
```

## Backup & Restore

```bash
# Backup JWT secret
kubectl get secret jwt-secret -n ethereum -o yaml > jwt-secret-backup.yaml

# Restore JWT secret
kubectl apply -f jwt-secret-backup.yaml

# Export pod configuration
kubectl get statefulset geth -n ethereum -o yaml > geth-backup.yaml

# Snapshot PVC (cloud-specific)
# GKE
gcloud compute disks snapshot <disk-name> --snapshot-names=geth-snapshot

# EKS (using AWS)
aws ec2 create-snapshot --volume-id <volume-id> --description "Geth backup"

# AKS
az snapshot create --resource-group <rg> --name geth-snapshot --source <disk-id>
```

## Cleanup

```bash
# Full cleanup (with confirmation)
./scripts/cleanup.sh

# Delete specific components
kubectl delete -f k8s/peer-monitor/
kubectl delete -f k8s/monitoring/
kubectl delete -f k8s/prysm/
kubectl delete -f k8s/geth/

# Delete namespaces
kubectl delete namespace ethereum
kubectl delete namespace monitoring

# Delete PVCs (data will be lost!)
kubectl delete pvc --all -n ethereum

# Delete PVs
kubectl delete pv <pv-name>
```

## Build & Deploy Peer Monitor

```bash
# Build Go application
cd go-peer-monitor
go build -o peer-monitor .

# Run locally
export GETH_RPC_URL=http://localhost:8545
./peer-monitor

# Build Docker image
docker build -t peer-monitor:latest .

# Load into Minikube
minikube image load peer-monitor:latest

# Load into Kind
kind load docker-image peer-monitor:latest

# Redeploy
kubectl delete -f k8s/peer-monitor/
kubectl apply -f k8s/peer-monitor/
```

## Viewing Metrics

```bash
# Geth metrics
kubectl port-forward -n ethereum svc/geth 6060:6060
curl http://localhost:6060/debug/metrics/prometheus

# Prysm metrics
kubectl port-forward -n ethereum svc/prysm-beacon 8080:8080
curl http://localhost:8080/metrics

# Peer monitor metrics
kubectl port-forward -n ethereum svc/peer-monitor 8080:8080
curl http://localhost:8080/metrics
```

## Grafana Operations

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000 (admin/admin)

# Get admin password (if changed)
kubectl get secret grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d

# Reset admin password
kubectl exec -n monitoring <grafana-pod> -- \
  grafana-cli admin reset-admin-password newpassword

# Import dashboard via API
curl -X POST http://localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @grafana-dashboards/ethereum-overview.json
```

## Prometheus Operations

```bash
# Access Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090

# Check configuration
curl http://localhost:9090/api/v1/status/config

# Check targets
curl http://localhost:9090/api/v1/targets

# Query instant value
curl 'http://localhost:9090/api/v1/query?query=geth_peer_count'

# Query range
curl 'http://localhost:9090/api/v1/query_range?query=geth_peer_count&start=2024-01-21T10:00:00Z&end=2024-01-21T11:00:00Z&step=60s'

# Reload configuration
curl -X POST http://localhost:9090/-/reload
```

## Environment-Specific

### Minikube

```bash
# Start with resources
minikube start --cpus=8 --memory=16384 --disk-size=1600g

# Access services
minikube service list
minikube service grafana -n monitoring

# SSH into node
minikube ssh

# Load image
minikube image load peer-monitor:latest
```

### Kind

```bash
# Load image
kind load docker-image peer-monitor:latest

# Get cluster info
kind get clusters
kind get nodes
```

### Cloud (GKE example)

```bash
# Get cluster credentials
gcloud container clusters get-credentials ethereum-node --zone us-central1-a

# Resize cluster
gcloud container clusters resize ethereum-node --num-nodes 3

# Update cluster
gcloud container clusters upgrade ethereum-node
```

## Useful Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Kubernetes
alias k='kubectl'
alias kge='kubectl get events --sort-by=.metadata.creationTimestamp'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'

# Ethereum namespace
alias keth='kubectl -n ethereum'
alias kmon='kubectl -n monitoring'

# Logs
alias geth-logs='kubectl logs -f statefulset/geth -n ethereum'
alias prysm-logs='kubectl logs -f statefulset/prysm-beacon -n ethereum'
alias peer-logs='kubectl logs -f deployment/peer-monitor -n ethereum'

# Port forwards
alias pf-grafana='kubectl port-forward -n monitoring svc/grafana 3000:3000'
alias pf-prometheus='kubectl port-forward -n monitoring svc/prometheus 9090:9090'
alias pf-geth='kubectl port-forward -n ethereum svc/geth 8545:8545'
```

## Common Workflows

### Initial Deployment
```bash
./scripts/deploy-all.sh
./scripts/check-status.sh
```

### Daily Health Check
```bash
kubectl get pods -n ethereum -n monitoring
kubectl top pods -n ethereum
kubectl logs --tail=50 statefulset/geth -n ethereum
```

### Investigating Sync Issues
```bash
# Check Geth sync
kubectl exec -n ethereum geth-0 -- geth attach http://localhost:8545 --exec "eth.syncing"

# Check peer count
kubectl exec -n ethereum geth-0 -- geth attach http://localhost:8545 --exec "admin.peers.length"

# Check recent logs
kubectl logs --tail=100 statefulset/geth -n ethereum | grep -i sync
```

### Upgrading Clients
```bash
# Update image in statefulset
kubectl set image statefulset/geth geth=ethereum/client-go:v1.14.0 -n ethereum

# Or edit directly
kubectl edit statefulset geth -n ethereum

# Restart
kubectl delete pod geth-0 -n ethereum
```

## Quick Reference

| Task | Command |
|------|---------|
| Deploy everything | `./scripts/deploy-all.sh` |
| Check status | `./scripts/check-status.sh` |
| View Geth logs | `kubectl logs -f statefulset/geth -n ethereum` |
| View Prysm logs | `kubectl logs -f statefulset/prysm-beacon -n ethereum` |
| Access Grafana | `kubectl port-forward -n monitoring svc/grafana 3000:3000` |
| Access Prometheus | `kubectl port-forward -n monitoring svc/prometheus 9090:9090` |
| Check sync status | `kubectl exec -n ethereum geth-0 -- geth attach http://localhost:8545 --exec "eth.syncing"` |
| Get peer count | `kubectl logs deployment/peer-monitor -n ethereum` |
| Cleanup | `./scripts/cleanup.sh` |
