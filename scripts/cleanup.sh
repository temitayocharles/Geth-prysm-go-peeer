#!/bin/bash

echo "================================"
echo "Ethereum Node Cleanup"
echo "================================"
echo
echo "⚠️  WARNING: This will delete all Ethereum node data and monitoring!"
echo
read -p "Are you sure you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY == "yes" ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo "Deleting Kubernetes resources..."
echo

echo "Deleting peer monitor..."
kubectl delete -f k8s/peer-monitor/ --ignore-not-found=true

echo "Deleting monitoring stack..."
kubectl delete -f k8s/monitoring/ --ignore-not-found=true

echo "Deleting Prysm..."
kubectl delete -f k8s/prysm/ --ignore-not-found=true

echo "Deleting Geth..."
kubectl delete -f k8s/geth/ --ignore-not-found=true

echo "Deleting namespaces..."
kubectl delete namespace ethereum --ignore-not-found=true
kubectl delete namespace monitoring --ignore-not-found=true

echo
echo "✓ Cleanup complete"
echo
echo "Note: Persistent volume data may still exist in your cluster."
echo "To completely remove all data, you may need to manually delete PVs:"
echo "  kubectl get pv"
echo "  kubectl delete pv <pv-name>"
