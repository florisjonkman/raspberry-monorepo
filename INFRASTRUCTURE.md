# Infrastructure Documentation

This document details the infrastructure setup for the Raspberry Pi Kubernetes cluster.

## Table of Contents

- [Quick Start](#quick-start)
- [SD Card Flashing](#sd-card-flashing)
- [Local Development](#local-development)
- [Raspberry Pi Setup](#raspberry-pi-setup)
- [K3s Installation](#k3s-installation)
- [Networking](#networking)
- [Storage](#storage)
- [ArgoCD](#argocd)
- [Observability Stack](#observability-stack)
- [Secret Management](#secret-management)
- [Maintenance](#maintenance)

---

## Quick Start

### Local Testing (Recommended First)

```bash
# 1. Create local K3d cluster
task k3d:create

# 2. Deploy observability stack
task local:deploy

# 3. Validate deployment
task local:test

# 4. Access services
task grafana:port-forward    # http://localhost:3000
task prometheus:port-forward # http://localhost:9090
```

### Raspberry Pi Deployment

```bash
# 1. Flash SD card (see docs/SETUP_PI.md)
# 2. Configure static IP via router DHCP reservation

# 3. Test connectivity
task pi:ping

# 4. Setup Pi
task pi:setup

# 5. Install K3s
task k3s:install

# 6. Get kubeconfig
task k3s:kubeconfig
export KUBECONFIG=~/.kube/config-pi

# 7. Install ArgoCD
task argocd:install

# 8. Validate
task k:validate
```

---

## SD Card Flashing

For detailed instructions, see [docs/SETUP_PI.md](docs/SETUP_PI.md).

### Summary

1. **Install Raspberry Pi Imager**: `brew install --cask raspberry-pi-imager`
2. **Flash SD card** with Raspberry Pi OS Lite (64-bit)
3. **Configure via Imager**:
   - Hostname: `raspberry`
   - Enable SSH
   - Set username/password
4. **Boot Pi** with Ethernet connected
5. **Configure router** DHCP reservation for `192.168.1.31`
6. **Reboot Pi** to get static IP

---

## Local Development

For detailed instructions, see [docs/LOCAL_DEVELOPMENT.md](docs/LOCAL_DEVELOPMENT.md).

### Prerequisites

```bash
brew install k3d kubectl helm go-task
```

### Workflow

```bash
# Create cluster
task k3d:create

# Deploy stack
task local:deploy

# Validate
task local:test

# Cleanup
task k3d:delete
```

### Available Tasks

| Task | Description |
|------|-------------|
| `task k3d:create` | Create local K3s cluster |
| `task k3d:delete` | Delete local cluster |
| `task k3d:start` | Start stopped cluster |
| `task k3d:stop` | Stop cluster (preserves data) |
| `task local:deploy` | Deploy full observability stack |
| `task local:test` | Validate deployment |
| `task local:reset` | Delete and recreate cluster |

---

## Raspberry Pi Setup

### Hardware Specifications

| Component | Details |
|-----------|---------|
| Model | Raspberry Pi 4 Model B |
| FCC ID | 2ABCB-RPI4B |
| IC | 20951-RPI4B |
| Architecture | ARM64 (aarch64) |
| RAM | 4GB (recommended 4GB+) |

### Network Configuration

| Setting | Value |
|---------|-------|
| Static IP | `192.168.1.31` (via DHCP reservation) |
| Gateway | `192.168.1.1` |
| SSH Port | 22 |
| K3s API | 6443 |

> Static IP is configured on the **router** via DHCP reservation, not on the Pi itself.
> See [docs/SETUP_PI.md](docs/SETUP_PI.md) for detailed instructions.

### OS Installation

1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Select **Raspberry Pi OS Lite (64-bit)**
3. Configure advanced options:
   - Set hostname: `raspberry`
   - Enable SSH with public key authentication
   - Skip WiFi (use Ethernet)
   - Set locale and timezone

### Initial Configuration

After first boot, the Ansible playbook handles:

- System updates
- Required package installation
- cgroup configuration for K3s
- Firewall rules
- SSH hardening

Run the setup playbook:

```bash
task pi:setup
```

### Manual Prerequisites (if not using Ansible)

Enable cgroups (required for K3s):

```bash
# Add to /boot/cmdline.txt (single line)
cgroup_memory=1 cgroup_enable=memory
```

Reboot after changes:

```bash
sudo reboot
```

---

## K3s Installation

### Overview

[K3s](https://k3s.io/) is a lightweight Kubernetes distribution perfect for edge computing and IoT devices like the Raspberry Pi.

### Installation via Ansible

```bash
task k3s:install
```

### Manual Installation

```bash
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable servicelb
```

> Note: We disable the default Traefik and ServiceLB to install custom versions with our configuration.

### Accessing the Cluster

Copy the kubeconfig to your development machine:

```bash
# On the Pi
sudo cat /etc/rancher/k3s/k3s.yaml

# On your machine, save to ~/.kube/config-pi
# Update the server URL to your Pi's IP address
export KUBECONFIG=~/.kube/config-pi
```

### Verify Installation

```bash
kubectl get nodes
kubectl get pods -A
```

---

## Networking

### Traefik Ingress Controller

Traefik is installed via Helm with custom values:

```yaml
# infrastructure/helm-values/traefik.yaml
```

### DNS Configuration

Option 1: Local `/etc/hosts`

```
192.168.1.31  argocd.pi.local grafana.pi.local prometheus.pi.local
```

Option 2: Local DNS server (Pi-hole, dnsmasq)

```
address=/pi.local/192.168.1.31
```

Option 3: nip.io (no configuration needed)

```
argocd.192.168.1.31.nip.io
grafana.192.168.1.31.nip.io
```

### TLS Certificates

cert-manager handles TLS certificates:

- **Local development**: Self-signed certificates
- **Public access** (optional): Let's Encrypt via DNS challenge

---

## Storage

### Local Path Provisioner

K3s includes a local path provisioner by default:

```bash
kubectl get storageclass
# NAME                   PROVISIONER             AGE
# local-path (default)   rancher.io/local-path   1d
```

### Persistent Volume Claims

Applications can request storage:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
```

### Storage Considerations

- Default storage location: `/var/lib/rancher/k3s/storage`
- Consider USB SSD for better performance and longevity
- Monitor disk usage regularly

---

## ArgoCD

### Installation

```bash
task argocd:install
```

Or manually:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f infrastructure/argocd/install/
```

### Accessing ArgoCD UI

Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Port forward (development):

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Or access via Ingress:

```
https://argocd.pi.local
```

### Application Structure

ArgoCD Applications are defined in `infrastructure/argocd/applications/`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: grafana
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://grafana.github.io/helm-charts
    targetRevision: 7.0.0
    chart: grafana
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### App of Apps Pattern

We use the "App of Apps" pattern where a root Application manages all other Applications:

```
infrastructure/argocd/applications/
├── root.yaml              # Root Application (manages others)
├── argocd.yaml           # ArgoCD self-management
├── observability.yaml    # Observability stack
└── apps.yaml             # User applications
```

---

## Observability Stack

### Components

| Component | Purpose | Helm Chart |
|-----------|---------|------------|
| Grafana | Dashboards & visualization | grafana/grafana |
| Loki | Log aggregation | grafana/loki |
| Promtail | Log shipping | grafana/promtail |
| Prometheus | Metrics collection | prometheus-community/prometheus |

### Resource Allocation

Given Pi's limited resources, use conservative limits:

```yaml
# Example resource limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Grafana

**Helm values**: `infrastructure/helm-values/grafana.yaml`

Default dashboards:
- Kubernetes cluster overview
- Node metrics
- Pod metrics
- Loki logs explorer

### Loki

**Helm values**: `infrastructure/helm-values/loki.yaml`

Configuration optimized for single-node:
- Filesystem storage backend
- Single replica
- Minimal resource usage

### Prometheus

**Helm values**: `infrastructure/helm-values/prometheus.yaml`

Scrape configs include:
- Kubernetes API server
- Node metrics (node-exporter)
- Pod metrics
- Service endpoints

### Accessing Dashboards

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Grafana | https://grafana.pi.local | admin / (see secret) |
| Prometheus | https://prometheus.pi.local | N/A |

---

## Secret Management

### SOPS with age

We use [SOPS](https://github.com/getsops/sops) with [age](https://github.com/FiloSottile/age) for encrypting secrets.

### Setup

1. Generate an age key:

```bash
age-keygen -o ~/.config/sops/age/keys.txt
```

2. Configure SOPS (`.sops.yaml`):

```yaml
creation_rules:
  - path_regex: .*\.enc\.yaml$
    age: <your-public-key>
```

### Encrypting Secrets

```bash
# Encrypt a file
sops -e secrets.yaml > secrets.enc.yaml

# Edit encrypted file
sops secrets.enc.yaml

# Decrypt (for debugging)
sops -d secrets.enc.yaml
```

### Kubernetes Integration

Use a SOPS operator or decrypt during CI/CD:

```bash
sops -d secrets.enc.yaml | kubectl apply -f -
```

---

## Maintenance

### Updating K3s

```bash
# On the Pi
curl -sfL https://get.k3s.io | sh -
```

### Updating Applications

1. Update Helm chart version in ArgoCD Application
2. Commit and push
3. ArgoCD syncs automatically

### Backup

Important data to backup:
- `/etc/rancher/k3s/` - K3s configuration
- Persistent volumes
- SOPS age keys

### Monitoring Disk Space

```bash
# Check disk usage
df -h

# Check K3s storage
du -sh /var/lib/rancher/k3s/storage/*
```

### Logs

```bash
# K3s logs
sudo journalctl -u k3s -f

# Pod logs (via kubectl)
kubectl logs -n <namespace> <pod-name>

# Pod logs (via Grafana/Loki)
# Use the Explore view with LogQL
```

---

## Troubleshooting

### K3s Won't Start

Check cgroups:
```bash
cat /proc/cgroups
```

Check logs:
```bash
sudo journalctl -u k3s --no-pager | tail -100
```

### Pods Pending/Evicted

Check resources:
```bash
kubectl describe node
kubectl top nodes
kubectl top pods -A
```

### ArgoCD Sync Failed

Check Application status:
```bash
kubectl -n argocd get applications
kubectl -n argocd describe application <name>
```

### Network Issues

Check Traefik:
```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik
kubectl -n kube-system logs -l app.kubernetes.io/name=traefik
```
