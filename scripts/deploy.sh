#!/bin/bash

# Deploy Ethereum Light Node (for storage-constrained environments < 100GB)
# This script deploys a minimal Ethereum setup using:
# - Geth in light sync mode (~20GB)
# - Prysm with checkpoint sync (~40GB)
# - Reduced monitoring stack (~15GB)
# Total: ~75GB

set -e

echo "========================================"
echo "Ethereum Light Node Deployment"
echo "========================================"
echo ""
echo "⚠️  WARNING: Light node limitations:"
echo "  - Cannot query historical data"
echo "  - Cannot run as validator"
echo "  - Depends on full nodes for data"
echo ""
echo "Storage required: ~75GB"
echo "  - Geth (light): 20GB"
echo "  - Prysm: 40GB"
echo "  - Prometheus: 10GB"
echo "  - Grafana: 5GB"
echo ""
read -p "Continue with light node deployment? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Step 1: Creating namespaces..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/monitoring/namespace.yaml

echo ""
echo "Step 2: Generating JWT secret..."
./scripts/generate-jwt.sh

JWT_FILE="jwt.hex"
kubectl create secret generic jwt-secret \
  --from-file=jwt.hex="$JWT_FILE" \
  --namespace=ethereum \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✓ JWT secret created in ethereum namespace"
echo ""
echo "To view the secret:"
echo "  kubectl get secret jwt-secret -n ethereum -o jsonpath='{.data.jwt\.hex}' | base64 -d"

echo ""
echo "Step 3: Deploying Geth (Light Mode)..."
kubectl apply -f k8s/geth/statefulset.yaml
kubectl apply -f k8s/geth/service.yaml

echo ""
echo "Step 4: Deploying Prysm Beacon Chain..."
kubectl apply -f k8s/prysm/statefulset.yaml
kubectl apply -f k8s/prysm/service.yaml

echo ""
echo "Step 5: Deploying Monitoring Stack..."
kubectl apply -f k8s/monitoring/prometheus-rbac.yaml
kubectl apply -f k8s/monitoring/prometheus-config.yaml
kubectl apply -f k8s/monitoring/prometheus-deployment.yaml
kubectl apply -f k8s/monitoring/grafana-config.yaml
kubectl apply -f k8s/monitoring/grafana-deployment.yaml

echo ""
echo "========================================"
echo "Deployment initiated!"
echo "========================================"
echo ""
echo "Monitoring deployment status:"
echo "  kubectl get pods -n ethereum"
echo "  kubectl get pods -n monitoring"
echo ""
echo "Check Geth logs:"
echo "  kubectl logs -f statefulset/geth -n ethereum"
echo ""
echo "Check Prysm logs:"
echo "  kubectl logs -f statefulset/prysm-beacon -n ethereum"
echo ""
echo "Access Grafana (after pods are ready):"
echo "  kubectl port-forward -n monitoring svc/grafana 3000:3000"
echo "  Then open: http://localhost:3000"
echo "  Login: admin / admin"
echo ""
echo "Monitor storage usage:"
echo "  kubectl exec -n ethereum statefulset/geth -- df -h /data"
echo "  kubectl exec -n ethereum statefulset/prysm-beacon -- df -h /data"
echo ""
echo "⚠️  Light sync will complete in minutes, but functionality is limited."
echo "    For full historical data access, consider upgrading storage and"
echo "    using the full node deployment (scripts/deploy-all.sh)"
echo ""
