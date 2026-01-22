# Project Structure

```
debbie-k8s/
├── README.md                      # Main documentation
├── QUICKSTART.md                  # Quick setup guide
├── DESIGN.md                      # Architecture and design decisions
├── DEPLOYMENT_ENVIRONMENTS.md     # Environment-specific deployment guides
├── TESTING.md                     # Testing strategies and scripts
├── INTERVIEW_PREP.md              # Interview preparation guide
├── PROJECT_STRUCTURE.md           # This file
├── .gitignore                     # Git ignore rules
│
├── k8s/                           # Kubernetes manifests
│   ├── namespace.yaml             # Ethereum namespace
│   ├── jwt-secret.yaml            # JWT secret template
│   │
│   ├── geth/                      # Geth (Execution Client)
│   │   ├── configmap.yaml         # Geth configuration
│   │   ├── service.yaml           # Geth services (ClusterIP + NodePort)
│   │   ├── statefulset.yaml       # Geth StatefulSet with JWT init
│   │   └── persistentvolume.yaml  # PVC for blockchain data
│   │
│   ├── prysm/                     # Prysm (Consensus Client)
│   │   ├── service.yaml           # Prysm services (ClusterIP + NodePort)
│   │   ├── statefulset.yaml       # Prysm StatefulSet with checkpoint sync
│   │   └── persistentvolume.yaml  # PVC for beacon chain data
│   │
│   ├── monitoring/                # Monitoring Stack
│   │   ├── namespace.yaml         # Monitoring namespace
│   │   ├── prometheus-rbac.yaml   # ServiceAccount and RBAC for Prometheus
│   │   ├── prometheus-config.yaml # Prometheus scrape configuration
│   │   ├── prometheus-deployment.yaml  # Prometheus deployment + PVC
│   │   ├── grafana-config.yaml    # Grafana datasources and dashboards
│   │   └── grafana-deployment.yaml     # Grafana deployment + PVC
│   │
│   └── peer-monitor/              # Peer Monitoring Service
│       └── deployment.yaml        # Peer monitor deployment + service
│
├── go-peer-monitor/               # Go Peer Monitor Application
│   ├── main.go                    # Main application code
│   ├── go.mod                     # Go module definition
│   ├── Dockerfile                 # Container image definition
│   ├── Makefile                   # Build automation
│   └── README.md                  # Application documentation
│
├── scripts/                       # Deployment Scripts
│   ├── generate-jwt.sh            # Generate and create JWT secret
│   ├── deploy-all.sh              # Full deployment automation
│   ├── check-status.sh            # Health check script
│   └── cleanup.sh                 # Cleanup script
│
└── grafana-dashboards/            # Grafana Dashboard Definitions
    └── ethereum-overview.json     # Main Ethereum metrics dashboard
```

## File Descriptions

### Root Documentation

- **README.md**: Complete project documentation including architecture, prerequisites, deployment instructions, and troubleshooting
- **QUICKSTART.md**: Simplified guide to get started in under 10 minutes
- **DESIGN.md**: In-depth discussion of design decisions, technology choices, security considerations, and production improvements
- **DEPLOYMENT_ENVIRONMENTS.md**: Environment-specific guides (Minikube, Kind, GKE, EKS, AKS, bare metal)
- **TESTING.md**: Comprehensive testing guide including health checks, integration tests, load tests, and failure scenarios
- **INTERVIEW_PREP.md**: Guide for discussing the project in interviews with talking points and common questions

### Kubernetes Manifests

#### Geth (Execution Client)
- **configmap.yaml**: Geth startup flags and configuration
- **service.yaml**: Two services - ClusterIP for internal communication, NodePort for P2P networking
- **statefulset.yaml**: Geth deployment with:
  - Init container to generate JWT secret
  - Snap sync mode for faster initial sync
  - Prometheus metrics enabled
  - Resource limits and health probes
- **persistentvolume.yaml**: 1TB PVC for blockchain data

#### Prysm (Consensus Client)
- **service.yaml**: Two services - ClusterIP for internal, NodePort for P2P
- **statefulset.yaml**: Prysm beacon chain deployment with:
  - Init containers for JWT and waiting for Geth
  - Checkpoint sync for fast beacon chain sync
  - Prometheus metrics enabled
  - Resource limits and health probes
- **persistentvolume.yaml**: 500GB PVC for beacon chain data

#### Monitoring
- **prometheus-rbac.yaml**: ServiceAccount, ClusterRole, and binding for Prometheus to discover targets
- **prometheus-config.yaml**: Scrape configuration for Geth, Prysm, and peer monitor
- **prometheus-deployment.yaml**: Prometheus StatefulSet with 30-day retention and 50GB storage
- **grafana-config.yaml**: Auto-provisioned Prometheus datasource and dashboard configuration
- **grafana-deployment.yaml**: Grafana deployment with persistent storage

#### Peer Monitor
- **deployment.yaml**: Go application deployment that monitors Geth peers and exposes metrics

### Go Peer Monitor

- **main.go**: Main application that:
  - Connects to Geth RPC
  - Calls `admin_peers` every 10 seconds
  - Displays detailed peer information
  - Exposes Prometheus metrics on :8080/metrics
- **go.mod**: Declares dependencies (go-ethereum, prometheus client)
- **Dockerfile**: Multi-stage build for minimal container image
- **Makefile**: Common build tasks (build, run, test, docker)
- **README.md**: Application-specific documentation

### Scripts

- **generate-jwt.sh**: Generates a cryptographically secure JWT secret and creates Kubernetes secret
- **deploy-all.sh**: Automated deployment script that:
  - Creates namespaces
  - Generates JWT secret
  - Deploys Geth → Prysm → Monitoring → Peer Monitor in order
  - Shows status and next steps
- **check-status.sh**: Health check script that shows:
  - Pod status
  - Sync progress
  - Recent logs
  - Storage usage
  - Access commands
- **cleanup.sh**: Safe cleanup with confirmation prompt

### Dashboards

- **ethereum-overview.json**: Grafana dashboard showing:
  - Peer count
  - Sync status
  - Block height
  - Network traffic

## Component Interactions

```
┌─────────────────────────────────────────────────┐
│                Kubernetes Cluster                │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │         Ethereum Namespace                  │ │
│  │                                             │ │
│  │  ┌─────────┐          ┌──────────┐         │ │
│  │  │  Geth   │◄─JWT────►│  Prysm   │         │ │
│  │  │  :8545  │  :8551   │  Beacon  │         │ │
│  │  │  :6060  │          │  :8080   │         │ │
│  │  └────┬────┘          └─────┬────┘         │ │
│  │       │                     │               │ │
│  │       │ RPC                 │               │ │
│  │       ▼                     │               │ │
│  │  ┌──────────┐               │               │ │
│  │  │  Peer    │               │               │ │
│  │  │ Monitor  │               │               │ │
│  │  │  :8080   │               │               │ │
│  │  └─────┬────┘               │               │ │
│  └────────┼────────────────────┼───────────────┘ │
│           │                    │                  │
│           │    Metrics         │                  │
│  ┌────────▼────────────────────▼───────────────┐ │
│  │       Monitoring Namespace                   │ │
│  │                                              │ │
│  │  ┌────────────┐        ┌────────────┐      │ │
│  │  │ Prometheus │◄───────┤  Grafana   │      │ │
│  │  │   :9090    │        │   :3000    │      │ │
│  │  └────────────┘        └────────────┘      │ │
│  └──────────────────────────────────────────────┘ │
│                                                  │
│  External P2P                                    │
│  ┌────────────────┐                             │
│  │ Ethereum       │                             │
│  │ Mainnet        │◄──────────┐                 │
│  └────────────────┘           │                 │
└────────────────────────────────┼─────────────────┘
                                 │
                        NodePort :30303
```

## Data Flow

### 1. Initialization
1. Namespaces created
2. JWT secret generated (shared between Geth and Prysm)
3. PVCs provisioned for storage

### 2. Startup
1. **Geth** starts first
   - Generates JWT if not exists
   - Begins P2P discovery
   - Starts syncing blockchain
2. **Prysm** waits for Geth, then starts
   - Uses same JWT
   - Connects to Geth via Engine API (:8551)
   - Uses checkpoint sync for fast beacon chain sync
3. **Peer Monitor** starts
   - Connects to Geth RPC (:8545)
   - Queries peer information
4. **Prometheus** starts
   - Scrapes metrics from Geth, Prysm, Peer Monitor
5. **Grafana** starts
   - Connects to Prometheus
   - Displays dashboards

### 3. Runtime Operations
- Geth syncs execution layer (transactions, state)
- Prysm syncs consensus layer (beacon chain)
- Both communicate via Engine API for block production
- Peer Monitor continuously queries and displays peer info
- Prometheus collects and stores metrics
- Grafana visualizes real-time data

## Storage Requirements

| Component | Storage | Growth Rate | Purpose |
|-----------|---------|-------------|---------|
| Geth | 1TB | ~1GB/day | Blockchain data, state |
| Prysm | 500GB | ~500MB/day | Beacon chain data |
| Prometheus | 50GB | ~1GB/week | Metrics (30-day retention) |
| Grafana | 10GB | ~100MB/month | Dashboards, settings |

## Port Map

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| Geth | 8545 | TCP | HTTP RPC |
| Geth | 8546 | TCP | WebSocket RPC |
| Geth | 8551 | TCP | Engine API (JWT) |
| Geth | 30303 | TCP/UDP | P2P networking |
| Geth | 6060 | TCP | Prometheus metrics |
| Prysm | 4000 | TCP | HTTP RPC |
| Prysm | 3500 | TCP | gRPC Gateway |
| Prysm | 8080 | TCP | Prometheus metrics |
| Prysm | 13000 | TCP | P2P networking |
| Prysm | 12000 | UDP | P2P discovery |
| Peer Monitor | 8080 | TCP | Prometheus metrics |
| Prometheus | 9090 | TCP | Web UI & API |
| Grafana | 3000 | TCP | Web UI |

## Resource Allocation

### Default Resources

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| Geth | 2 cores | 4 cores | 8GB | 16GB |
| Prysm | 1 core | 2 cores | 4GB | 8GB |
| Prometheus | 0.5 core | 1 core | 2GB | 4GB |
| Grafana | 0.25 core | 0.5 core | 512MB | 1GB |
| Peer Monitor | 0.1 core | 0.2 core | 128MB | 256MB |

**Total Cluster Requirements:** 4+ cores, 16+ GB RAM, 1.5+ TB storage

## Security Model

### Network Isolation
- Two namespaces: `ethereum` and `monitoring`
- ClusterIP services for internal communication
- NodePort for P2P (required for blockchain networking)

### Secrets Management
- JWT secret stored in Kubernetes Secret (ephemeral in current implementation)
- Mounted as files in containers
- Not exposed via environment variables

### Resource Controls
- CPU and memory limits prevent DoS
- Storage quotas prevent disk exhaustion
- Network policies recommended for production

### Access Control
- RBAC for Prometheus service account
- No admin APIs exposed externally
- Grafana requires authentication (default admin/admin)

## Monitoring & Observability

### Metrics Collection
- **Geth**: Exposes 100+ metrics including sync status, peer count, transaction pool, gas price
- **Prysm**: Exposes beacon chain metrics, attestations, validators, sync committee
- **Peer Monitor**: Custom metric for peer count

### Health Probes
- **Liveness**: Ensures container is running
- **Readiness**: Ensures container is ready to serve traffic
- Both configured with appropriate delays for slow-starting blockchain clients

### Logging
- All logs available via `kubectl logs`
- Structured logging from Go applications
- Geth and Prysm provide detailed sync progress logs

## Next Steps

1. **For Deployment**: Follow QUICKSTART.md
2. **For Testing**: Follow TESTING.md
3. **For Production**: Review DESIGN.md security section
4. **For Interview**: Study INTERVIEW_PREP.md

## Contributing

When adding new components:
1. Add Kubernetes manifests to appropriate directory
2. Update this structure document
3. Add deployment steps to deploy-all.sh
4. Add health checks to check-status.sh
5. Document in README.md


