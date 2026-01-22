#!/bin/bash

# Deploy Ethereum Node using Helm
# This uses the light node configuration (~75GB storage)

set -e

echo "========================================"
echo "Ethereum Node Deployment (Helm)"
echo "========================================"
echo ""
echo "Storage required: ~75GB"
echo "  - Geth (light): 20GB"
echo "  - Prysm: 40GB"
echo "  - Prometheus: 10GB"
echo "  - Grafana: 5GB"
echo ""
read -p "Continue with deployment? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Step 1: Generating JWT secret..."
./scripts/generate-jwt.sh

JWT_FILE="jwt.hex"
if [ ! -f "$JWT_FILE" ]; then
    echo "Error: JWT file not found!"
    exit 1
fi

JWT_SECRET=$(cat "$JWT_FILE")

echo ""
echo "Step 2: Installing Helm chart..."
helm upgrade --install ethereum-node ./helm/ethereum-node \
  --set jwt.secret="$JWT_SECRET" \
  --wait \
  --timeout 10m

echo ""
echo "========================================"
echo "✅ Deployment Complete!"
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
echo "View Helm release:"
echo "  helm list"
echo "  helm status ethereum-node"

