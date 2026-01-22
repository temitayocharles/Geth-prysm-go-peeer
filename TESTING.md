# Testing Guide

This guide covers testing strategies for the Ethereum node deployment.

## Pre-Deployment Testing

### 1. Validate Kubernetes Manifests

```bash
# Dry-run deployment
kubectl apply -f k8s/ --dry-run=client

# Validate with kubeval
kubeval k8s/**/*.yaml

# Lint with yamllint
yamllint k8s/
```

### 2. Test Docker Images

```bash
# Build peer monitor
cd go-peer-monitor
docker build -t peer-monitor:latest .

# Run locally with mock
docker run --rm -e GETH_RPC_URL=http://localhost:8545 peer-monitor:latest
```

### 3. Test Scripts

```bash
# Test JWT generation
./scripts/generate-jwt.sh

# Verify JWT format (should be 64 hex characters)
cat jwt.hex | wc -c  # Should output 65 (64 + newline)
```

## Post-Deployment Testing

### 1. Health Checks

```bash
# Check all pods are running
kubectl get pods -n ethereum
kubectl get pods -n monitoring

# Expected output:
# NAME                            READY   STATUS    RESTARTS   AGE
# geth-0                          1/1     Running   0          5m
# prysm-beacon-0                  1/1     Running   0          4m
# peer-monitor-xxxx               1/1     Running   0          3m

# Check pod details
kubectl describe pod geth-0 -n ethereum
```

### 2. Service Connectivity

```bash
# Test Geth RPC
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://geth.ethereum.svc.cluster.local:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}'

# Expected output: {"jsonrpc":"2.0","id":1,"result":"1"}

# Test Geth metrics
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://geth.ethereum.svc.cluster.local:6060/debug/metrics/prometheus

# Test Prysm health
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://prysm-beacon.ethereum.svc.cluster.local:3500/healthz

# Test Prometheus
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up
```

### 3. JWT Authentication

```bash
# Verify JWT secret exists in both pods
kubectl exec -n ethereum geth-0 -- cat /secrets/jwt.hex
kubectl exec -n ethereum prysm-beacon-0 -- cat /secrets/jwt.hex

# Both should output the same value
```

### 4. Peer Connectivity

```bash
# Check peer count via RPC
kubectl exec -n ethereum geth-0 -- \
  geth attach http://localhost:8545 --exec "admin.peers.length"

# Should be > 0 after a few minutes

# View peer monitor output
kubectl logs -f deployment/peer-monitor -n ethereum
```

### 5. Sync Progress

```bash
# Check Geth sync status
kubectl exec -n ethereum geth-0 -- \
  geth attach http://localhost:8545 --exec "eth.syncing"

# Returns 'false' if fully synced, or sync progress object

# Check Prysm sync status
kubectl exec -n ethereum prysm-beacon-0 -- \
  curl -s http://localhost:3500/eth/v1/node/syncing | jq .
```

### 6. Storage Verification

```bash
# Check PVC status
kubectl get pvc -n ethereum

# Expected:
# NAME                          STATUS   VOLUME              CAPACITY   ACCESS MODES
# geth-data-geth-0              Bound    pvc-xxx             1Ti        RWO
# prysm-beacon-data-prysm-0     Bound    pvc-yyy             500Gi      RWO

# Check disk usage
kubectl exec -n ethereum geth-0 -- df -h /data
kubectl exec -n ethereum prysm-beacon-0 -- df -h /data
```

### 7. Metrics Collection

```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &

# Query metrics
curl 'http://localhost:9090/api/v1/query?query=geth_peer_count'
curl 'http://localhost:9090/api/v1/query?query=up{job="geth"}'
curl 'http://localhost:9090/api/v1/query?query=up{job="prysm-beacon"}'

# Kill port forward
kill %1
```

### 8. Grafana Access

```bash
# Port forward
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Test login (default: admin/admin)
curl -u admin:admin http://localhost:3000/api/health

# Expected: {"commit":"xxx","database":"ok","version":"x.x.x"}
```

## Integration Tests

### 1. End-to-End RPC Test

```bash
# Create test script
cat > test-rpc.sh << 'EOF'
#!/bin/bash
set -e

GETH_URL="http://localhost:8545"

echo "Testing Geth RPC endpoints..."

# Test net_version
echo -n "net_version: "
curl -s -X POST $GETH_URL \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' | jq -r .result

# Test eth_blockNumber
echo -n "eth_blockNumber: "
curl -s -X POST $GETH_URL \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq -r .result

# Test admin_peers (should have peers)
PEER_COUNT=$(curl -s -X POST $GETH_URL \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"admin_peers","params":[],"id":1}' | jq '.result | length')

echo "Connected peers: $PEER_COUNT"

if [ "$PEER_COUNT" -gt 0 ]; then
  echo "✓ All tests passed"
  exit 0
else
  echo "✗ No peers connected"
  exit 1
fi
EOF

chmod +x test-rpc.sh

# Run test (requires port-forward)
kubectl port-forward -n ethereum svc/geth 8545:8545 &
sleep 2
./test-rpc.sh
kill %1
```

### 2. Monitoring Stack Test

```bash
# Test Prometheus scraping
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
sleep 2

# Check targets
TARGETS=$(curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length')
echo "Active targets: $TARGETS"

# Should be at least 3 (geth, prysm, peer-monitor)
if [ "$TARGETS" -ge 3 ]; then
  echo "✓ Prometheus scraping correctly"
else
  echo "✗ Some targets not being scraped"
fi

kill %1
```

### 3. Peer Monitor Functionality

```bash
# Check peer monitor logs for expected format
kubectl logs deployment/peer-monitor -n ethereum --tail=50 | grep "Total Peers"

# Should output lines like:
# Total Peers: 12
```

## Load Testing

### 1. RPC Load Test

```bash
# Install vegeta (load testing tool)
# brew install vegeta

# Create load test targets
cat > targets.txt << EOF
POST http://localhost:8545
Content-Type: application/json
@eth_blockNumber.json
EOF

cat > eth_blockNumber.json << EOF
{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}
EOF

# Port forward
kubectl port-forward -n ethereum svc/geth 8545:8545 &

# Run load test (100 requests per second for 30 seconds)
vegeta attack -targets=targets.txt -rate=100 -duration=30s | vegeta report

kill %1
```

### 2. Resource Usage Under Load

```bash
# Monitor resource usage during load test
kubectl top pods -n ethereum --watch
```

## Failure Testing

### 1. Pod Restart

```bash
# Delete Geth pod (should restart automatically)
kubectl delete pod geth-0 -n ethereum

# Wait and verify it comes back
kubectl wait --for=condition=ready pod/geth-0 -n ethereum --timeout=300s

# Verify data persists (check block height before/after)
```

### 2. Network Partition

```bash
# Create network policy to isolate Geth
kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-geth
  namespace: ethereum
spec:
  podSelector:
    matchLabels:
      app: geth
  policyTypes:
  - Ingress
  - Egress
EOF

# Verify Prysm can't reach Geth
kubectl exec -n ethereum prysm-beacon-0 -- nc -zv geth.ethereum.svc.cluster.local 8551

# Remove policy
kubectl delete networkpolicy isolate-geth -n ethereum
```

### 3. Storage Full

```bash
# Check current usage
kubectl exec -n ethereum geth-0 -- df -h /data

# Monitor sync with storage alerts
# (In production, set up alerts for > 80% usage)
```

## Performance Benchmarks

### 1. Sync Speed

```bash
# Record block height every minute
for i in {1..60}; do
  BLOCK=$(kubectl exec -n ethereum geth-0 -- \
    geth attach http://localhost:8545 --exec "eth.blockNumber" 2>/dev/null)
  echo "$(date +%s), $BLOCK" >> sync-speed.csv
  sleep 60
done

# Calculate blocks per minute
# Process sync-speed.csv to get sync rate
```

### 2. RPC Latency

```bash
# Measure RPC latency
kubectl port-forward -n ethereum svc/geth 8545:8545 &

for i in {1..100}; do
  curl -w "%{time_total}\n" -o /dev/null -s \
    -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
done | awk '{sum+=$1; n++} END {print "Average latency:", sum/n, "seconds"}'

kill %1
```

## Automated Testing

### CI/CD Pipeline Example

```yaml
# .github/workflows/test.yml
name: Test Ethereum Node

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Kind
      uses: helm/kind-action@v1
      with:
        cluster_name: test
    
    - name: Deploy
      run: |
        ./scripts/deploy-all.sh
    
    - name: Wait for pods
      run: |
        kubectl wait --for=condition=ready pod --all -n ethereum --timeout=300s
    
    - name: Test connectivity
      run: |
        kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
          curl http://geth.ethereum.svc.cluster.local:8545
    
    - name: Check logs
      if: always()
      run: |
        kubectl logs -n ethereum statefulset/geth
```

## Cleanup After Testing

```bash
# Remove test resources
./scripts/cleanup.sh

# Or manually
kubectl delete namespace ethereum monitoring

# Remove local JWT file
rm -f jwt.hex
```

## Common Issues

### Issue: Pods stuck in Pending

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n ethereum
```

**Common causes:**
- Insufficient storage
- No storage class available
- Resource constraints

### Issue: Geth won't sync

**Diagnosis:**
```bash
kubectl logs statefulset/geth -n ethereum | grep -i error
```

**Common causes:**
- P2P ports not accessible
- Insufficient peers
- Corrupted data (requires resync)

### Issue: Prysm can't connect to Geth

**Diagnosis:**
```bash
kubectl logs statefulset/prysm-beacon -n ethereum | grep -i "engine"
```

**Common causes:**
- JWT mismatch
- Geth not ready yet
- Network policy blocking connection

## Success Criteria

A successful deployment should meet these criteria:

- ✅ All pods in Running state
- ✅ Geth has > 5 connected peers
- ✅ Prysm has > 5 connected peers
- ✅ Sync progressing (increasing block numbers)
- ✅ Prometheus scraping all targets
- ✅ Grafana accessible and showing metrics
- ✅ Peer monitor displaying peer information
- ✅ No error logs in pods
- ✅ Storage usage increasing (indicates syncing)
- ✅ Resource usage within limits

## Next Steps

After successful testing:
1. Document any configuration changes
2. Set up monitoring alerts
3. Create runbooks for common issues
4. Schedule regular health checks
5. Plan for production deployment
