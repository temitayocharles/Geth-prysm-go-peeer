#!/bin/bash

set -e

echo "Generating JWT secret for Ethereum clients..."

JWT_FILE="jwt.hex"

if [ -f "$JWT_FILE" ]; then
    echo "JWT file already exists at $JWT_FILE"
    read -p "Do you want to regenerate it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

openssl rand -hex 32 > $JWT_FILE

echo "JWT secret generated and saved to $JWT_FILE"
echo

echo "Creating Kubernetes secret..."

kubectl create namespace ethereum --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic jwt-secret \
  --from-file=jwt.hex=$JWT_FILE \
  --namespace=ethereum \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✓ JWT secret created in ethereum namespace"
echo
echo "To view the secret:"
echo "  kubectl get secret jwt-secret -n ethereum -o jsonpath='{.data.jwt\.hex}' | base64 -d"
