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

echo "✓ JWT secret generated and saved to $JWT_FILE"
echo
echo "Note: The Kubernetes secret will be created by Helm during deployment."
