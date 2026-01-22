# Design Documentation

## Design Process

### Requirements Analysis

The project required:
1. **Part A**: Deploy an Ethereum Mainnet node with Geth and Prysm on Kubernetes with Prometheus/Grafana monitoring
2. **Part B**: Create a Go program to monitor and display connected peers

### Architecture Decisions

#### 1. Kubernetes Resources

**StatefulSets over Deployments:**
- Ethereum clients require stable network identities and persistent storage
- StatefulSets provide ordered, graceful deployment and scaling
- Stable hostname enables reliable P2P networking
- Persistent volume claims are automatically bound to specific pods

**Separate Namespaces:**
- `ethereum`: Contains blockchain infrastructure (Geth, Prysm, Peer Monitor)
- `monitoring`: Isolated monitoring stack (Prometheus, Grafana)
- Separation improves security boundaries and resource management
- Simplifies RBAC and network policies

**Service Types:**
- ClusterIP for internal communication (RPC, metrics)
- NodePort for P2P networking (requires external accessibility)
- Could use LoadBalancer in cloud environments for better P2P connectivity

#### 2. Storage Strategy

**Persistent Volume Claims:**
- Geth: 1TB (mainnet currently ~800GB+, growing)
- Prysm: 500GB (beacon chain data)
- Prometheus: 50GB (30-day retention)
- Grafana: 10GB (dashboards and settings)

**Storage Class:**
- Uses `standard` storage class (available in most clusters)
- Production: Use SSD-backed storage (e.g., `gp3` on AWS, `pd-ssd` on GCP)
- Consider regional replication for disaster recovery

#### 3. JWT Authentication

**Shared Secret Approach:**
- Single JWT secret generated at deployment
- Both Geth and Prysm mount the same secret
- Enables secure Engine API communication (EIP-3675)

**Alternative Considered:**
- Separate secrets with manual sync → Rejected due to complexity
- ConfigMap storage → Rejected for security reasons

#### 4. Sync Optimization

**Geth:**
- Snap sync mode (fastest initial sync)
- Cache size: 4GB (balance between speed and memory)
- MaxPeers: 50 (adequate for home/dev setup)

**Prysm:**
- Checkpoint sync enabled (https://beaconstate.info)
- Reduces initial sync from days to hours
- Safe: checkpoint data is publicly verifiable

## Technology Choices

### Execution Client: Geth

**Why Geth:**
- Most widely adopted Ethereum client (~60% network)
- Battle-tested, stable, and well-documented
- Excellent RPC API support for peer monitoring
- Strong community and tooling ecosystem

**Alternatives Considered:**
- **Nethermind**: Better performance, but higher resource usage
- **Besu**: Java-based, good for enterprise, but larger footprint
- **Erigon**: Excellent performance, but more complex configuration

### Consensus Client: Prysm

**Why Prysm:**
- Written in Go (same as Geth, easier for team familiar with Go)
- Excellent documentation and monitoring capabilities
- Strong performance characteristics
- Native checkpoint sync support

**Alternatives Considered:**
- **Lighthouse**: Rust-based, excellent performance, but different ecosystem
- **Teku**: Java-based, good for enterprise, but higher resource usage
- **Nimbus**: Lightweight, but less widely adopted

### Client Diversity Consideration

For production, running minority clients is critical:
- Current setup (Geth + Prysm) follows majority clients
- Production recommendation: Consider Nethermind + Lighthouse for diversity
- Protects against client-specific bugs affecting network consensus

### Monitoring Stack: Prometheus + Grafana

**Why This Stack:**
- Industry standard for Kubernetes monitoring
- Native support in both Geth and Prysm
- Excellent visualization with Grafana
- Large ecosystem of pre-built dashboards
- Time-series data perfect for blockchain metrics

**What We Monitor:**
- Sync progress (blocks, epochs)
- Peer connectivity
- Resource usage (CPU, memory, disk I/O)
- Network traffic
- Block production/validation (for validators)

### Go for Peer Monitor

**Why Go:**
- Native Ethereum client libraries (go-ethereum)
- Same language as Geth and Prysm
- Excellent concurrency model for long-running monitoring
- Easy Docker containerization
- Low resource footprint

**Key Libraries:**
- `github.com/ethereum/go-ethereum`: Official Ethereum Go library
- `github.com/prometheus/client_golang`: Prometheus metrics

## Security Considerations

### Current Implementation

#### 1. JWT Secret Management

**Current:**
- Generated at deployment time using `hexdump`
- Stored in emptyDir volume (ephemeral)
- Shared between Geth and Prysm pods

**Security Level:** Medium
- Secrets exist only in memory and pod filesystem
- Not exposed to external access
- Regenerated on pod restart

#### 2. RPC Access Control

**Current:**
- HTTP RPC enabled with full API access
- Services are ClusterIP (not externally accessible)
- Admin APIs (admin_peers) available for monitoring

**Security Level:** Medium
- Protected by Kubernetes network boundaries
- No authentication on RPC endpoints
- Suitable for dev/test environments

#### 3. Network Policies

**Current:**
- Not implemented (default Kubernetes networking)
- All pods in namespace can communicate

**Security Level:** Low
- Relies on namespace isolation only

#### 4. Resource Limits

**Current:**
- Memory and CPU limits defined for all containers
- Prevents resource exhaustion attacks
- Protects cluster from runaway processes

**Security Level:** High

### Production Security Improvements

#### 1. Secret Management

**Recommended:**
- Use Kubernetes External Secrets Operator
- Integrate with cloud KMS (AWS KMS, GCP Secret Manager, Azure Key Vault)
- Rotate JWT secrets periodically
- Use sealed secrets for GitOps workflows

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: jwt-secret
  namespace: ethereum
spec:
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: jwt-secret
  data:
  - secretKey: jwt.hex
    remoteRef:
      key: ethereum/jwt-secret
```

#### 2. RPC Authentication

**Recommended:**
- Implement JWT authentication for RPC endpoints
- Use API keys for external access
- Deploy sidecar proxy (Envoy, Nginx) for auth
- Rate limiting to prevent DoS

Example Geth config:
```
--http.jwt-secret=/secrets/rpc-jwt.hex
--http.api=eth,net,web3  # Remove admin APIs
```

#### 3. Network Policies

**Recommended:**
- Implement strict ingress/egress rules
- Allow only necessary pod-to-pod communication
- Restrict external access to P2P ports only

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: geth-network-policy
  namespace: ethereum
spec:
  podSelector:
    matchLabels:
      app: geth
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: prysm-beacon
    ports:
    - protocol: TCP
      port: 8551  # Engine API only
  - from:
    - podSelector:
        matchLabels:
          app: peer-monitor
    ports:
    - protocol: TCP
      port: 8545  # RPC for monitoring
  egress:
  - to:
    - podSelector: {}
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 30303  # P2P
    - protocol: UDP
      port: 30303
```

#### 4. Pod Security Standards

**Recommended:**
- Enforce restricted Pod Security Standards
- Run containers as non-root
- Use read-only root filesystems
- Drop all capabilities

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
```

#### 5. TLS/Encryption

**Recommended:**
- Enable TLS for all HTTP/RPC endpoints
- Use cert-manager for certificate management
- Mutual TLS (mTLS) between Geth and Prysm
- Encrypt inter-pod communication with service mesh (Istio, Linkerd)

#### 6. Monitoring & Alerting

**Recommended:**
- Alert on unusual peer connection patterns
- Monitor for abnormal resource usage
- Track sync lag and block production
- Set up PagerDuty/Opsgenie integration

Example alerts:
```yaml
groups:
- name: ethereum
  rules:
  - alert: GethPeerCountLow
    expr: geth_peer_count < 3
    for: 5m
    annotations:
      summary: "Geth has too few peers"
  
  - alert: GethSyncLag
    expr: (time() - geth_chain_head_timestamp) > 300
    for: 5m
    annotations:
      summary: "Geth is not syncing"
```

#### 7. Backup & Disaster Recovery

**Recommended:**
- Regular snapshots of PVCs (Velero)
- Cross-region replication
- Automated restore testing
- Document recovery procedures

#### 8. Audit Logging

**Recommended:**
- Enable Kubernetes audit logging
- Log all RPC calls (for production environments)
- Ship logs to SIEM (Splunk, ELK)
- Implement log retention policies

### Attack Surface Analysis

#### Current Vulnerabilities

1. **P2P Network Attacks:**
   - Eclipse attacks (malicious peers)
   - DDoS via P2P ports
   - Mitigation: Peer reputation systems, rate limiting

2. **RPC API Abuse:**
   - Unauthorized admin access
   - Resource exhaustion via expensive queries
   - Mitigation: Authentication, rate limiting, API restrictions

3. **Consensus Layer Attacks:**
   - Slashing via incorrect validation
   - Attestation spamming
   - Mitigation: Proper validator key management, slashing protection

4. **Resource Exhaustion:**
   - Storage filling (DoS)
   - Memory/CPU exhaustion
   - Mitigation: Resource quotas, monitoring, alerts

5. **Supply Chain:**
   - Compromised container images
   - Vulnerable dependencies
   - Mitigation: Image scanning, SBOM, signed images

## Future Improvements for Production

### 1. High Availability

**Multi-Region Deployment:**
```
Region A          Region B          Region C
┌──────────┐     ┌──────────┐     ┌──────────┐
│ Geth+    │     │ Geth+    │     │ Geth+    │
│ Prysm    │────▶│ Prysm    │────▶│ Prysm    │
└──────────┘     └──────────┘     └──────────┘
```

**Load Balancing:**
- Deploy multiple Geth nodes behind load balancer
- Read replicas for RPC traffic
- Active-active setup with automatic failover

### 2. Validator Support

**Staking Infrastructure:**
- Add Prysm validator client
- Secure key management (HSM, remote signer)
- Slashing protection database
- MEV-boost integration for maximal rewards

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: prysm-validator
spec:
  template:
    spec:
      containers:
      - name: validator
        image: gcr.io/prysmaticlabs/prysm/validator:stable
        args:
        - --beacon-rpc-provider=prysm-beacon:4000
        - --wallet-dir=/wallet
        - --suggested-fee-recipient=0x...
        volumeMounts:
        - name: validator-keys
          mountPath: /wallet
```

### 3. Performance Optimization

**Caching Layer:**
- Redis for RPC response caching
- Reduces load on Geth
- Faster response times for common queries

**Database Tuning:**
- Separate SSD for levelDB
- Tune Geth cache parameters
- Enable ancient data pruning

**Horizontal Scaling:**
- Deploy multiple read replicas
- Route read traffic to replicas
- Keep write traffic on primary

### 4. Advanced Monitoring

**Distributed Tracing:**
- Implement OpenTelemetry
- Trace requests across services
- Identify bottlenecks

**Custom Dashboards:**
- Block production efficiency
- MEV analytics
- Gas price optimization
- Peer geographic distribution

**Anomaly Detection:**
- ML-based anomaly detection
- Predictive alerting
- Automatic remediation

### 5. Cost Optimization

**Storage Tiering:**
- Hot data on SSD
- Archive data on HDD/cold storage
- Implement pruning strategies

**Spot Instances:**
- Use spot/preemptible instances for non-critical workloads
- Automatic fallback to on-demand

**Resource Right-Sizing:**
- Continuous resource monitoring
- Auto-scaling based on load
- Vertical pod autoscaling

### 6. Compliance & Governance

**Regulatory Compliance:**
- GDPR considerations for peer IP logging
- Data residency requirements
- Transaction monitoring for AML/KYC

**Access Control:**
- RBAC for all operational access
- Audit trails for all admin actions
- Separation of duties

### 7. Automation

**GitOps:**
- Full IaC with Terraform/Pulumi
- ArgoCD/FluxCD for continuous deployment
- Automated testing in CI/CD pipeline

**Auto-Remediation:**
- Automatic pod restarts on failure
- Self-healing storage issues
- Automatic peer rotation

**Capacity Planning:**
- Predictive storage growth
- Automatic PVC expansion
- Resource forecasting

### 8. Testing Strategy

**Chaos Engineering:**
- Regularly test failure scenarios
- Network partitions
- Storage failures
- Node crashes

**Performance Testing:**
- Load testing RPC endpoints
- Stress testing P2P networking
- Benchmark sync performance

**Security Testing:**
- Regular penetration testing
- Vulnerability scanning
- Dependency auditing

### 9. Documentation & Runbooks

**Operational Runbooks:**
- Incident response procedures
- Rollback procedures
- Disaster recovery steps
- On-call playbooks

**Architecture Decision Records (ADRs):**
- Document all major decisions
- Track technology choices
- Justify trade-offs

### 10. Multi-Chain Support

**Future Expansion:**
- Support multiple networks (Sepolia, Holesky testnet)
- Cross-chain monitoring
- Unified dashboard for all chains

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: geth-sepolia
spec:
  template:
    spec:
      containers:
      - name: geth
        args:
        - --sepolia
        - --datadir=/data
```

## Conclusion

This implementation provides a solid foundation for running an Ethereum node on Kubernetes. While suitable for development and testing, production deployments should incorporate the security improvements and architectural enhancements outlined above.

Key takeaways:
- **Start simple**: Current design is intentionally straightforward
- **Security first**: Production requires significant security hardening
- **Monitor everything**: Comprehensive monitoring prevents incidents
- **Plan for failure**: HA and DR are critical for production
- **Automate**: Reduce human error through automation
- **Document**: Clear documentation enables team scaling

The modular design allows for incremental improvements, making it easy to adopt production best practices as requirements evolve.
