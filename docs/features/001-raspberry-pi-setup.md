# 001 - Raspberry Pi K3s Cluster Setup

This monorepo contains everything needed to run a production-grade Kubernetes cluster on a Raspberry Pi 4, with full GitOps automation and observability.

## Overview

A single-node K3s Kubernetes cluster running on a Raspberry Pi 4B with:
- **GitOps** - All deployments managed through ArgoCD
- **Observability** - Complete monitoring stack (Grafana, Prometheus, Loki)
- **Local Testing** - K3d environment to test changes before deploying to Pi
- **Infrastructure as Code** - Ansible playbooks for Pi provisioning

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                        │
│                    (florisjonkman/raspberry-monorepo)           │
└─────────────────────────────────────────────────────────────────┘
                                   │
                                   │ GitOps Sync
                                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Raspberry Pi 4B (192.168.1.31)             │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                         K3s Cluster                        │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐│  │
│  │  │   ArgoCD    │  │   Traefik   │  │    Monitoring       ││  │
│  │  │  (GitOps)   │  │  (Ingress)  │  │  ┌───────────────┐  ││  │
│  │  └─────────────┘  └─────────────┘  │  │   Grafana     │  ││  │
│  │                                     │  │   Prometheus  │  ││  │
│  │                                     │  │   Loki        │  ││  │
│  │                                     │  │   Promtail    │  ││  │
│  │                                     │  └───────────────┘  ││  │
│  │                                     └─────────────────────┘│  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Features

### GitOps with ArgoCD
- All Kubernetes resources defined in Git
- Automatic sync when changes are pushed
- App-of-Apps pattern for managing multiple applications
- Self-healing - ArgoCD corrects drift automatically

### Observability Stack
| Component | Purpose | Access |
|-----------|---------|--------|
| Grafana | Dashboards & visualization | `task grafana:port-forward` → http://localhost:3000 |
| Prometheus | Metrics collection & storage | `task prometheus:port-forward` → http://localhost:9090 |
| Loki | Log aggregation | Integrated in Grafana |
| Promtail | Log shipping from all pods | DaemonSet on all nodes |

### Local Development with K3d
- Test the full stack locally before deploying to Pi
- Mirrors production configuration
- Includes local Helm value overrides for reduced resources

### Infrastructure as Code
- Ansible playbooks for Pi provisioning
- Automated K3s installation
- cgroups v2 support for modern Raspberry Pi OS

## Directory Structure

```
raspberry-monorepo/
├── ansible/                      # Pi provisioning
│   ├── inventory/hosts.yml       # Pi connection details
│   └── playbooks/
│       ├── setup.yml             # Initial Pi setup
│       ├── k3s-install.yml       # K3s installation
│       └── reboot.yml            # Controlled reboot
├── docker/
│   └── k3d-config.yaml           # Local K3d cluster config
├── docs/
│   ├── SETUP_PI.md               # SD card flashing guide
│   ├── LOCAL_DEVELOPMENT.md      # Local testing guide
│   └── features/                 # This directory
├── infrastructure/
│   ├── argocd/
│   │   ├── applications/         # ArgoCD Application CRDs
│   │   └── install/              # ArgoCD installation
│   └── helm-values/
│       ├── grafana.yaml          # Production Grafana config
│       ├── prometheus.yaml       # Production Prometheus config
│       ├── loki.yaml             # Production Loki config
│       ├── traefik.yaml          # Production Traefik config
│       └── local/                # Local dev overrides
├── scripts/
│   └── validate-cluster.sh       # Cluster health check
├── .env.example                  # Environment template
├── Brewfile                      # macOS dependencies
├── Taskfile.yml                  # Task runner commands
└── CLAUDE.md                     # AI assistant instructions
```

## Quick Commands

```bash
# Connect to Pi cluster
export KUBECONFIG=~/.kube/config-pi

# Pi Management
task pi:ping              # Test connectivity
task pi:setup             # Run setup playbook
task pi:ssh               # SSH into Pi

# K3s Management
task k3s:install          # Install K3s
task k3s:kubeconfig       # Fetch kubeconfig

# ArgoCD
task argocd:install       # Install ArgoCD
task argocd:password      # Get admin password
task argocd:port-forward  # Access UI at https://localhost:8080

# Observability
task grafana:port-forward    # Access at http://localhost:3000
task prometheus:port-forward # Access at http://localhost:9090

# Local Development
task k3d:create           # Create local cluster
task k3d:delete           # Delete local cluster
task local:deploy         # Deploy stack locally
task local:test           # Validate deployment

# Secrets
task secrets:create       # Create shared credentials from .env

# Utilities
task k:pods               # List all pods
task k:nodes              # List nodes
task k:validate           # Run cluster validation
```

## Workflow

### Making Changes

1. **Edit files** in the repository
2. **Test locally** (optional):
   ```bash
   task k3d:create
   task local:deploy
   task local:test
   ```
3. **Commit and push**:
   ```bash
   git add -A && git commit -m "Your change" && git push
   ```
4. **ArgoCD syncs automatically** - changes deploy to Pi within minutes

### First-Time Setup

1. Install dependencies: `brew bundle`
2. Flash SD card: Follow `docs/SETUP_PI.md`
3. Configure router DHCP reservation for `192.168.1.31`
4. Copy SSH key: `ssh-copy-id pi@192.168.1.31`
5. Setup Pi: `task pi:setup`
6. Install K3s: `task k3s:install`
7. Get kubeconfig: `task k3s:kubeconfig`
8. Install ArgoCD: `task argocd:install`
9. Create secrets: Copy `.env.example` to `.env`, edit, then `task secrets:create`
10. Apply root app: `kubectl apply -f infrastructure/argocd/applications/root.yaml`

## Hardware

| Spec | Value |
|------|-------|
| Model | Raspberry Pi 4 Model B |
| RAM | 4GB |
| Storage | MicroSD (32GB+) |
| Network | Ethernet (static IP: 192.168.1.31) |
| Architecture | ARM64 (aarch64) |

## Network

| Service | Port | Access |
|---------|------|--------|
| SSH | 22 | `ssh pi@192.168.1.31` |
| K3s API | 6443 | Via kubeconfig |
| HTTP | 80 | Traefik ingress |
| HTTPS | 443 | Traefik ingress |

## Secrets Management

Secrets are managed via a `.env` file (not committed to git):

```bash
# Copy template
cp .env.example .env

# Edit with your password
nano .env

# Create Kubernetes secret
task secrets:create
```

## Resource Optimization

The stack is optimized for Raspberry Pi's limited resources:
- Loki runs in SingleBinary mode with caches disabled
- All components have conservative resource limits
- Persistence uses K3s local-path provisioner
- Alertmanager and Pushgateway can be disabled if needed
