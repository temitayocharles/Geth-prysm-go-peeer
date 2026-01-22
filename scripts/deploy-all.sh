#!/bin/bash

set -e

echo "================================"
echo "Ethereum Mainnet Node Deployment"
echo "================================"
echo

if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found. Please install kubectl first."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster. Please configure kubectl."
    exit 1
fi

echo "Step 1: Creating namespaces..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/monitoring/namespace.yaml
echo "✓ Namespaces created"
echo

echo "Step 2: Generating JWT secret..."
if [ ! -f jwt.hex ]; then
    openssl rand -hex 32 > jwt.hex
    echo "✓ JWT secret generated"
else
    echo "✓ JWT secret already exists"
fi

kubectl create secret generic jwt-secret \
  --from-file=jwt.hex=jwt.hex \
  --namespace=ethereum \
  --dry-run=client -o yaml | kubectl apply -f -
echo "✓ JWT secret created in Kubernetes"
echo

echo "Step 3: Deploying Geth (Execution Client)..."
kubectl apply -f k8s/geth/
echo "✓ Geth deployed"
echo

echo "Waiting for Geth to start (30 seconds)..."
sleep 30

echo "Step 4: Deploying Prysm (Consensus Client)..."
kubectl apply -f k8s/prysm/
echo "✓ Prysm deployed"
echo

echo "Step 5: Deploying Monitoring Stack..."
kubectl apply -f k8s/monitoring/prometheus-rbac.yaml
kubectl apply -f k8s/monitoring/prometheus-config.yaml
kubectl apply -f k8s/monitoring/prometheus-deployment.yaml
kubectl apply -f k8s/monitoring/grafana-config.yaml
kubectl apply -f k8s/monitoring/grafana-deployment.yaml
echo "✓ Monitoring stack deployed"
echo

echo "Step 6: Building Peer Monitor..."
if [ -f go-peer-monitor/Dockerfile ]; then
    echo "Building Docker image..."
    docker build -t peer-monitor:latest go-peer-monitor/
    
    if kubectl config current-context | grep -q "minikube"; then
        echo "Loading image into Minikube..."
        minikube image load peer-monitor:latest
    elif kubectl config current-context | grep -q "kind"; then
        echo "Loading image into Kind..."
        kind load docker-image peer-monitor:latest
    fi
    
    echo "✓ Peer monitor built"
else
    echo "⚠ Peer monitor Dockerfile not found, skipping build"
fi
echo

echo "Step 7: Deploying Peer Monitor..."
kubectl apply -f k8s/peer-monitor/
echo "✓ Peer monitor deployed"
echo

echo "================================"
echo "Deployment Complete!"
echo "================================"
echo
echo "Checking pod status..."
echo
kubectl get pods -n ethereum
echo
kubectl get pods -n monitoring
echo
echo "Next steps:"
echo
echo "1. Monitor Geth sync:"
echo "   kubectl logs -f statefulset/geth -n ethereum"
echo
echo "2. Monitor Prysm sync:"
echo "   kubectl logs -f statefulset/prysm-beacon -n ethereum"
echo
echo "3. View peer information:"
echo "   kubectl logs -f deployment/peer-monitor -n ethereum"
echo
echo "4. Access Prometheus:"
echo "   kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "   Open http://localhost:9090"
echo
echo "5. Access Grafana:"
echo "   kubectl port-forward -n monitoring svc/grafana 3000:3000"
echo "   Open http://localhost:3000 (admin/admin)"
echo
