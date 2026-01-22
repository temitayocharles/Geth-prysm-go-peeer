# Ethereum Peer Monitor

A Go application that monitors and reports connected peers from a Geth Ethereum execution client.

## Features

- Continuously monitors connected peers via Geth RPC
- Displays detailed peer information (ID, name, address, capabilities)
- Exposes Prometheus metrics for peer count
- Lightweight and containerized

## Requirements

- Go 1.21 or later
- Access to Geth RPC endpoint (default: port 8545)

## Usage

### Local Development

```bash
# Set Geth RPC URL
export GETH_RPC_URL=http://localhost:8545

# Run the application
go run main.go
```

### Build Binary

```bash
# Build
go build -o peer-monitor .

# Run
./peer-monitor
```

### Docker

```bash
# Build image
docker build -t peer-monitor:latest .

# Run container
docker run -e GETH_RPC_URL=http://geth:8545 peer-monitor:latest
```

### Kubernetes

See parent directory for Kubernetes deployment manifests.

## Output Example

```
=== Connected Peers at 2024-01-21 10:30:45 ===
Total Peers: 12

Peer 1:
  ID: enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@52.16.188.185:30303
  Name: Geth/v1.13.8-stable/linux-amd64/go1.21.5
  Remote Address: 52.16.188.185:30303
  Capabilities: [eth/67 eth/68 snap/1]
  ETH Protocol: {
    "difficulty": 58750003716598352816469,
    "head": "0x1234...",
    "version": 68
  }

================================
```

## Metrics

Prometheus metrics exposed on `:8080/metrics`:

- `geth_peer_count`: Number of connected peers (gauge)

## Configuration

Environment variables:

- `GETH_RPC_URL`: Geth RPC endpoint (default: `http://geth.ethereum.svc.cluster.local:8545`)

## Development

```bash
# Run tests
go test ./...

# Format code
go fmt ./...

# Lint
golangci-lint run
```

## License

MIT
