#!/bin/bash

echo "================================"
echo "Ethereum Node Status Check"
echo "================================"
echo

echo "Pods in ethereum namespace:"
kubectl get pods -n ethereum
echo

echo "Pods in monitoring namespace:"
kubectl get pods -n monitoring
echo

echo "================================"
echo "Geth Sync Status"
echo "================================"
GETH_POD=$(kubectl get pod -n ethereum -l app=geth -o jsonpath='{.items[0].metadata.name}')
if [ -n "$GETH_POD" ]; then
    echo "Checking sync status..."
    kubectl exec -n ethereum "$GETH_POD" -- geth attach --exec "eth.syncing" http://localhost:8545 2>/dev/null || echo "Geth is not ready yet or fully synced"
else
    echo "Geth pod not found"
fi
echo

echo "================================"
echo "Prysm Sync Status"
echo "================================"
PRYSM_POD=$(kubectl get pod -n ethereum -l app=prysm-beacon -o jsonpath='{.items[0].metadata.name}')
if [ -n "$PRYSM_POD" ]; then
    echo "Checking sync status..."
    kubectl exec -n ethereum "$PRYSM_POD" -- wget -qO- http://localhost:3500/eth/v1/node/syncing 2>/dev/null || echo "Prysm is not ready yet"
else
    echo "Prysm pod not found"
fi
echo

echo "================================"
echo "Recent Logs"
echo "================================"
echo
echo "Geth (last 10 lines):"
kubectl logs -n ethereum --tail=10 statefulset/geth 2>/dev/null | tail -10
echo
echo "Prysm (last 10 lines):"
kubectl logs -n ethereum --tail=10 statefulset/prysm-beacon 2>/dev/null | tail -10
echo

echo "================================"
echo "Storage Usage"
echo "================================"
kubectl get pvc -n ethereum
echo

echo "================================"
echo "Access Commands"
echo "================================"
echo "Prometheus: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "Grafana:    kubectl port-forward -n monitoring svc/grafana 3000:3000"
echo "Geth RPC:   kubectl port-forward -n ethereum svc/geth 8545:8545"
