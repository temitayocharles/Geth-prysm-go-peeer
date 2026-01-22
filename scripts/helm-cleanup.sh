#!/bin/bash

echo "================================"
echo "Ethereum Node Cleanup (Helm)"
echo "================================"
echo
echo "⚠️  WARNING: This will:"
echo "  - Uninstall the Helm release"
echo "  - Delete all Ethereum node data"
echo "  - Delete all monitoring data"
echo "  - Remove namespaces"
echo
read -p "Are you sure you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY == "yes" ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo "Checking for Helm release..."
if helm list -A | grep -q ethereum-node; then
    echo "Uninstalling Helm release 'ethereum-node'..."
    helm uninstall ethereum-node --wait
    echo "✓ Helm release uninstalled"
else
    echo "No Helm release 'ethereum-node' found"
fi

echo ""
echo "Deleting namespaces..."
kubectl delete namespace ethereum --ignore-not-found=true
kubectl delete namespace monitoring --ignore-not-found=true

echo ""
echo "Cleaning up cluster-wide resources..."
kubectl delete clusterrole prometheus --ignore-not-found=true
kubectl delete clusterrolebinding prometheus --ignore-not-found=true

echo ""
echo "✓ Cleanup complete"
echo
echo "Note: Persistent volume data may still exist in your cluster."
echo "To completely remove all data, you may need to manually delete PVs:"
echo "  kubectl get pv"
echo "  kubectl delete pv <pv-name>"
echo ""
echo "To verify cleanup:"
echo "  helm list -A"
echo "  kubectl get all -n ethereum"
echo "  kubectl get all -n monitoring"
