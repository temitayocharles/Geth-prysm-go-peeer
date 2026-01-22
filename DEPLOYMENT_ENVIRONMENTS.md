# Deployment Environment Guide

This guide covers deploying the Ethereum node on various Kubernetes environments.

## Quick Comparison: Local Development Tools

| Tool | Platform | Speed | Resources | Best For | Difficulty |
|------|----------|-------|-----------|----------|------------|
| **OrbStack** | Mac only | ⚡⚡⚡ Fastest | Low | Mac users (Recommended) | Easy |
| **Rancher Desktop** | Mac/Win/Linux | ⚡⚡ Fast | Medium | Cross-platform, Docker Desktop alternative | Easy |
| **k3d** | Mac/Win/Linux | ⚡⚡⚡ Fastest | Low | Multiple clusters, testing | Medium |
| **Minikube** | Mac/Win/Linux | ⚡ Slow | High | Traditional setup, full features | Medium |
| **Kind** | Mac/Win/Linux | ⚡⚡ Fast | Medium | CI/CD, testing | Medium |
| **Docker Desktop** | Mac/Windows | ⚡ Slow | High | Simplicity, beginners | Easy |

### Recommendations by Use Case

**Mac Users:**
1. **OrbStack** (Best choice) - Fastest, lowest resource usage, native feel
2. **Rancher Desktop** - Good Docker Desktop alternative
3. **k3d** - If you need multiple clusters

**Windows Users:**
1. **Rancher Desktop** - Best overall experience
2. **k3d** - Lightweight and fast
3. **Docker Desktop** - Easiest setup

**Linux Users:**
1. **k3d** - Lightweight and fast
2. **Rancher Desktop** - Full-featured
3. **Minikube** - Traditional option

**For Testing/CI:**
- **k3d** - Fast cluster creation/deletion, multiple clusters

## Local Development

### Minikube

**Setup:**

```bash
# Start Minikube with sufficient resources
minikube start \
  --cpus=8 \
  --memory=16384 \
  --disk-size=1600g \
  --driver=docker

# Enable metrics-server
minikube addons enable metrics-server

# Deploy
./scripts/deploy-all.sh

# Access services
minikube service list -n ethereum
minikube service list -n monitoring
```

**Accessing Grafana:**

```bash
# Option 1: Port forwarding
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Option 2: Minikube service
minikube service grafana -n monitoring
```

**Notes:**
- Storage: Uses hostPath by default
- P2P networking may have NAT issues
- Good for development and testing
- Not suitable for production

### Kind (Kubernetes in Docker)

**Setup:**

```bash
# Create cluster with extra mounts for storage
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /tmp/ethereum-data
    containerPath: /data
  extraPortMappings:
  - containerPort: 30303
    hostPort: 30303
    protocol: TCP
  - containerPort: 30303
    hostPort: 30303
    protocol: UDP
  - containerPort: 3000
    hostPort: 3000
    protocol: TCP
EOF

# Install Rancher local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Set as default storage class
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Deploy
./scripts/deploy-all.sh

# Load peer monitor image
kind load docker-image peer-monitor:latest
```

**Accessing Services:**

```bash
# Port forward for services
kubectl port-forward -n monitoring svc/grafana 3000:3000
kubectl port-forward -n monitoring svc/prometheus 9090:9090
kubectl port-forward -n ethereum svc/geth 8545:8545
```

**Notes:**
- P2P ports exposed via port mappings
- Better isolation than Minikube
- Good for CI/CD testing

### Docker Desktop Kubernetes

**Setup:**

```bash
# Enable Kubernetes in Docker Desktop settings
# Then deploy:
./scripts/deploy-all.sh
```

**Notes:**
- Easy setup on Mac/Windows
- Limited resources
- Good for basic testing

### OrbStack (Mac - Recommended)

**Why OrbStack:**
- Significantly faster than Docker Desktop on Mac
- Lower resource usage (CPU, memory)
- Native Apple Silicon support
- Built-in Kubernetes cluster
- Excellent performance for local development

**Setup:**

```bash
# Install OrbStack (https://orbstack.dev)
brew install orbstack

# Or download from https://orbstack.dev

# Start OrbStack and enable Kubernetes in settings
# OrbStack starts automatically on login

# Verify cluster
kubectl cluster-info

# Deploy
./scripts/deploy-all.sh

# Build and load peer monitor image
cd go-peer-monitor
docker build -t peer-monitor:latest .
# OrbStack automatically makes images available to k8s
cd ..

# Deploy peer monitor
kubectl apply -f k8s/peer-monitor/
```

**Accessing Services:**

```bash
# Port forward (same as other environments)
kubectl port-forward -n monitoring svc/grafana 3000:3000
kubectl port-forward -n monitoring svc/prometheus 9090:9090
kubectl port-forward -n ethereum svc/geth 8545:8545
```

**Storage:**
- OrbStack includes a default storage class
- No additional configuration needed
- Excellent disk I/O performance

**Notes:**
- Much faster than Docker Desktop on Mac
- Lower battery consumption
- Seamless Docker and Kubernetes integration
- Can run Linux machines alongside containers
- Native networking (no port forwarding complexity)

**Pro Tips:**
```bash
# Check OrbStack status
orb status

# View resource usage
orb info

# OrbStack has excellent DNS - services are accessible at:
# <service>.<namespace>.orb.local
# Example: geth.ethereum.orb.local
```

### Rancher Desktop (Mac/Windows/Linux)

**Why Rancher Desktop:**
- Open source alternative to Docker Desktop
- Available on Mac, Windows, and Linux
- Choose between containerd or dockerd
- Built-in Kubernetes (k3s)
- No licensing restrictions

**Setup:**

```bash
# Install Rancher Desktop
# Mac: brew install rancher
# Or download from https://rancherdesktop.io

# Windows: Download installer from https://rancherdesktop.io
# Or use Chocolatey: choco install rancher-desktop

# Launch Rancher Desktop and configure:
# - Container Runtime: dockerd (for Docker compatibility)
# - Kubernetes: Enable and select version
# - Memory: 16GB
# - CPUs: 8

# Verify cluster
kubectl cluster-info

# Verify storage class
kubectl get storageclass
# Should see 'local-path' as default

# Deploy
./scripts/deploy-all.sh

# Build peer monitor image
cd go-peer-monitor

# For dockerd runtime:
docker build -t peer-monitor:latest .

# For containerd runtime:
nerdctl build -t peer-monitor:latest .

# Image is automatically available to k8s
cd ..
```

**Windows-Specific Setup:**

```powershell
# Install Rancher Desktop via Chocolatey
choco install rancher-desktop

# Or download installer from https://rancherdesktop.io

# After installation, configure in Rancher Desktop UI:
# Settings → Kubernetes → Enable Kubernetes
# Settings → Virtual Machine → Memory: 16GB, CPUs: 8

# Verify setup (PowerShell)
kubectl cluster-info
kubectl get nodes

# Deploy
.\scripts\deploy-all.sh  # If using Git Bash
# Or follow manual deployment steps
```

**Accessing Services:**

```bash
# Same port-forward commands work on all platforms
kubectl port-forward -n monitoring svc/grafana 3000:3000
kubectl port-forward -n monitoring svc/prometheus 9090:9090
kubectl port-forward -n ethereum svc/geth 8545:8545
```

**Notes:**
- Uses k3s under the hood (lightweight Kubernetes)
- local-path-provisioner included by default
- Good Docker Desktop alternative
- Free and open source
- Consistent experience across platforms

**Troubleshooting:**

```bash
# Reset Kubernetes if having issues
# Rancher Desktop → Settings → Kubernetes → Reset Kubernetes

# Check k3s logs (Mac/Linux)
rdctl shell
journalctl -u k3s -f

# Windows: Check logs in Rancher Desktop UI
```

### k3d (Mac/Windows/Linux)

**Why k3d:**
- Extremely lightweight (k3s in Docker)
- Multiple clusters on one machine
- Very fast cluster creation/deletion
- Perfect for testing
- Cross-platform (Mac, Windows, Linux)

**Setup:**

```bash
# Install k3d
# Mac:
brew install k3d

# Windows (PowerShell):
choco install k3d

# Linux:
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Create cluster with port mappings for P2P and services
k3d cluster create ethereum \
  --agents 2 \
  --port 30303:30303@loadbalancer \
  --port 8080:80@loadbalancer \
  --port 3000:3000@server:0 \
  --volume /tmp/ethereum-data:/data@all \
  --k3s-arg "--disable=traefik@server:0"

# Verify cluster
kubectl cluster-info
kubectl get nodes

# k3d includes local-path storage by default
kubectl get storageclass

# Deploy
./scripts/deploy-all.sh

# Build and load peer monitor image
cd go-peer-monitor
docker build -t peer-monitor:latest .
k3d image import peer-monitor:latest -c ethereum
cd ..

# Deploy peer monitor
kubectl apply -f k8s/peer-monitor/
```

**Windows-Specific Commands:**

```powershell
# Create cluster (PowerShell)
k3d cluster create ethereum `
  --agents 2 `
  --port "30303:30303@loadbalancer" `
  --port "8080:80@loadbalancer" `
  --port "3000:3000@server:0" `
  --k3s-arg "--disable=traefik@server:0"

# Import image (PowerShell)
k3d image import peer-monitor:latest -c ethereum
```

**Advanced Configuration:**

```bash
# Create cluster with custom config file
cat <<EOF > k3d-config.yaml
apiVersion: k3d.io/v1alpha4
kind: Simple
metadata:
  name: ethereum
servers: 1
agents: 2
ports:
  - port: 30303:30303
    nodeFilters:
      - loadbalancer
  - port: 3000:3000
    nodeFilters:
      - server:0
options:
  k3s:
    extraArgs:
      - arg: --disable=traefik
        nodeFilters:
          - server:*
  kubeconfig:
    updateDefaultKubeconfig: true
    switchCurrentContext: true
EOF

k3d cluster create --config k3d-config.yaml

# Deploy
./scripts/deploy-all.sh
```

**Accessing Services:**

```bash
# With port mappings, some services are directly accessible:
# Grafana: http://localhost:3000

# For other services, use port-forward:
kubectl port-forward -n monitoring svc/prometheus 9090:9090
kubectl port-forward -n ethereum svc/geth 8545:8545
```

**Cluster Management:**

```bash
# List clusters
k3d cluster list

# Stop cluster (preserves data)
k3d cluster stop ethereum

# Start cluster
k3d cluster start ethereum

# Delete cluster
k3d cluster delete ethereum

# Create multiple clusters for testing
k3d cluster create ethereum-test
k3d cluster create ethereum-prod

# Switch between clusters
kubectl config get-contexts
kubectl config use-context k3d-ethereum-test
```

**Notes:**
- Very fast: cluster creation in ~20 seconds
- Multiple clusters don't interfere with each other
- Easy cleanup: `k3d cluster delete <name>`
- Great for CI/CD pipelines
- Lower resource usage than full Kubernetes

**Troubleshooting:**

```bash
# Check k3d version
k3d version

# View cluster info
k3d cluster list
k3d node list

# Get kubeconfig
k3d kubeconfig get ethereum

# Check Docker containers
docker ps | grep k3d

# View logs
k3d cluster logs ethereum
```

## Cloud Providers

### Google Kubernetes Engine (GKE)

**Setup:**

```bash
# Create cluster
gcloud container clusters create ethereum-node \
  --zone us-central1-a \
  --machine-type n2-standard-8 \
  --disk-size 100 \
  --num-nodes 2 \
  --enable-autoscaling \
  --min-nodes 2 \
  --max-nodes 4

# Get credentials
gcloud container clusters get-credentials ethereum-node --zone us-central1-a

# Deploy
./scripts/deploy-all.sh
```

**Storage Class Configuration:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ethereum-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
allowVolumeExpansion: true
```

**Update PVCs to use `ethereum-ssd` storage class for better performance.**

**Networking:**

```bash
# Create firewall rules for P2P
gcloud compute firewall-rules create ethereum-p2p \
  --allow tcp:30303,udp:30303 \
  --source-ranges 0.0.0.0/0 \
  --target-tags ethereum-node
```

**LoadBalancer for Grafana:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: grafana-lb
  namespace: monitoring
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 3000
  selector:
    app: grafana
```

**Cost Estimates:**
- 2 x n2-standard-8: ~$350/month
- 1.5TB SSD storage: ~$270/month
- Network egress: ~$50-100/month
- **Total: ~$670-720/month**

### Amazon EKS

**Setup:**

```bash
# Create cluster with eksctl
eksctl create cluster \
  --name ethereum-node \
  --region us-east-1 \
  --node-type m5.2xlarge \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 4 \
  --managed

# Deploy
./scripts/deploy-all.sh
```

**Storage Class Configuration:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ethereum-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
allowVolumeExpansion: true
```

**Security Group for P2P:**

```bash
# Get node security group
NODE_SG=$(aws eks describe-cluster \
  --name ethereum-node \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text)

# Allow P2P traffic
aws ec2 authorize-security-group-ingress \
  --group-id $NODE_SG \
  --protocol tcp \
  --port 30303 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id $NODE_SG \
  --protocol udp \
  --port 30303 \
  --cidr 0.0.0.0/0
```

**IAM Roles:**

```bash
# Create service account for external secrets
eksctl create iamserviceaccount \
  --name ethereum-secrets \
  --namespace ethereum \
  --cluster ethereum-node \
  --attach-policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite \
  --approve
```

**Cost Estimates:**
- 2 x m5.2xlarge: ~$280/month
- 1.5TB gp3 storage: ~$120/month
- Network egress: ~$50-100/month
- **Total: ~$450-500/month**

### Azure Kubernetes Service (AKS)

**Setup:**

```bash
# Create resource group
az group create --name ethereum-rg --location eastus

# Create cluster
az aks create \
  --resource-group ethereum-rg \
  --name ethereum-node \
  --node-count 2 \
  --node-vm-size Standard_D8s_v3 \
  --enable-managed-identity \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group ethereum-rg --name ethereum-node

# Deploy
./scripts/deploy-all.sh
```

**Storage Class Configuration:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ethereum-premium-ssd
provisioner: disk.csi.azure.com
parameters:
  storageaccounttype: Premium_LRS
  kind: Managed
allowVolumeExpansion: true
```

**Network Security:**

```bash
# Get node resource group
NODE_RG=$(az aks show -g ethereum-rg -n ethereum-node --query nodeResourceGroup -o tsv)

# Create NSG rule for P2P
az network nsg rule create \
  --resource-group $NODE_RG \
  --nsg-name ethereum-nsg \
  --name allow-p2p \
  --priority 100 \
  --destination-port-ranges 30303 \
  --protocol '*' \
  --access Allow
```

**Cost Estimates:**
- 2 x Standard_D8s_v3: ~$350/month
- 1.5TB Premium SSD: ~$240/month
- Network egress: ~$50-100/month
- **Total: ~$640-690/month**

## Bare Metal / Self-Hosted

### Requirements

- Kubernetes cluster (k3s, kubeadm, RKE2)
- NFS or Ceph for persistent storage
- Static IPs or DDNS for P2P connectivity

### k3s Setup (Lightweight)

```bash
# Install k3s on master
curl -sfL https://get.k3s.io | sh -

# Get kubeconfig
sudo k3s kubectl config view --raw > ~/.kube/config

# Install local-path provisioner (included by default)

# Deploy
./scripts/deploy-all.sh
```

### Storage Configuration

**NFS StorageClass:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
provisioner: nfs-client-provisioner
parameters:
  archiveOnDelete: "false"
```

**Longhorn (Distributed Storage):**

```bash
# Install Longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml

# Set as default
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Storage Optimization by Environment

### Development

```yaml
# Reduced storage for testing
spec:
  resources:
    requests:
      storage: 100Gi  # Geth (will sync partially)
```

### Staging

```yaml
spec:
  resources:
    requests:
      storage: 500Gi  # Geth (enough for snap sync + some history)
```

### Production

```yaml
spec:
  resources:
    requests:
      storage: 1.5Ti  # Geth (full archive node)
```

## Resource Tuning by Environment

### Development (Minimal)

```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "1000m"
  limits:
    memory: "8Gi"
    cpu: "2000m"
```

### Production (Optimized)

```yaml
resources:
  requests:
    memory: "16Gi"
    cpu: "4000m"
  limits:
    memory: "32Gi"
    cpu: "8000m"
```

## Monitoring Access

### Development

```bash
# Port forwarding
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

### Production

**Ingress with TLS:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: grafana-basic-auth
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - grafana.yourdomain.com
    secretName: grafana-tls
  rules:
  - host: grafana.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
```

## Backup Strategies

### Cloud Providers

```bash
# GKE
gcloud compute disks snapshot geth-data-pv \
  --snapshot-names=geth-backup-$(date +%Y%m%d)

# EKS (using AWS Backup)
aws backup start-backup-job \
  --backup-vault-name ethereum-vault \
  --resource-arn arn:aws:ec2:region:account:volume/vol-xxx

# AKS
az snapshot create \
  --resource-group ethereum-rg \
  --name geth-snapshot \
  --source /subscriptions/.../volumes/geth-data
```

### Velero (Universal)

```bash
# Install Velero
velero install \
  --provider aws \
  --bucket ethereum-backups \
  --secret-file ./credentials-velero

# Backup
velero backup create ethereum-backup \
  --include-namespaces ethereum

# Restore
velero restore create --from-backup ethereum-backup
```

## Troubleshooting by Environment

### Minikube

- **Storage full**: `minikube ssh` and check `/tmp/hostpath-provisioner/`
- **Can't access services**: Use `minikube tunnel` in a separate terminal

### Kind

- **Port conflicts**: Ensure host ports 30303, 3000 are free
- **Image pull issues**: Use `kind load docker-image` for local images

### Cloud Providers

- **P2P not working**: Check security groups/firewall rules
- **Storage issues**: Verify CSI drivers are installed
- **High costs**: Review storage class, use lifecycle policies

### Bare Metal

- **Storage performance**: Use SSDs, tune filesystem (ext4 vs xfs)
- **Network issues**: Configure static IPs, port forwarding
- **Resource contention**: Use node affinity, taints/tolerations

## Next Steps

After deployment:
1. ✅ Verify all pods are running
2. ✅ Check sync progress
3. ✅ Access monitoring dashboards
4. ✅ Set up alerting
5. ✅ Configure backups
6. ✅ Document runbooks
