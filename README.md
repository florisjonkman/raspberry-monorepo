# Raspberry Pi Kubernetes Monorepo

A home Kubernetes cluster running on a Raspberry Pi 4 Model B, featuring GitOps with ArgoCD and a full observability stack.

## Overview

This monorepo contains everything needed to run a production-grade Kubernetes environment on a Raspberry Pi:

- **K3s** - Lightweight Kubernetes distribution
- **ArgoCD** - GitOps continuous delivery
- **Observability** - Grafana, Loki, Prometheus
- **Applications** - TypeScript/Next.js apps

## Prerequisites

### Hardware
- Raspberry Pi 4 Model B (4GB+ RAM recommended)
- MicroSD card (32GB+ recommended) or USB SSD
- Ethernet connection (recommended) or WiFi

### Software (Development Machine)
- [Docker](https://docs.docker.com/get-docker/)
- [pnpm](https://pnpm.io/installation)
- [Task](https://taskfile.dev/installation/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [SOPS](https://github.com/getsops/sops)
- [age](https://github.com/FiloSottile/age)

### Software (Raspberry Pi)
- Raspberry Pi OS Lite (64-bit) or Ubuntu Server 22.04+
- SSH enabled

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/<your-username>/raspberry-monorepo.git
cd raspberry-monorepo
pnpm install
```

### 2. Configure the Raspberry Pi

Update the Ansible inventory with your Pi's IP address:

```bash
# Edit ansible/inventory/hosts.yml with your Pi's details
task pi:setup
```

### 3. Install K3s

```bash
task k3s:install
```

### 4. Install ArgoCD

```bash
task argocd:install
```

### 5. Deploy Observability Stack

ArgoCD will automatically sync the observability stack from the git repository.

## Project Structure

```
raspberry-monorepo/
├── apps/                    # Application source code
│   └── <app-name>/
│       ├── Dockerfile
│       ├── package.json
│       └── src/
│
├── ansible/                 # Raspberry Pi provisioning
│   ├── inventory/          # Host configuration
│   ├── playbooks/          # Ansible playbooks
│   └── roles/              # Reusable roles
│
├── infrastructure/
│   ├── argocd/
│   │   ├── install/        # ArgoCD installation manifests
│   │   └── applications/   # ArgoCD Application CRDs
│   │
│   └── helm-values/        # Helm chart value overrides
│       ├── grafana.yaml
│       ├── loki.yaml
│       └── prometheus.yaml
│
├── docker/                  # Local development
│   └── docker-compose.yml
│
├── scripts/                 # Utility scripts
│
└── .github/
    └── workflows/           # CI/CD pipelines
```

## Local Development

Start the local development environment:

```bash
task dev
```

This starts Docker Compose with local versions of:
- Application containers
- Mock services

Stop the environment:

```bash
task down
```

## Available Tasks

Run `task --list` to see all available tasks:

| Task | Description |
|------|-------------|
| `task dev` | Start local development environment |
| `task down` | Stop local development environment |
| `task pi:setup` | Initial Raspberry Pi setup |
| `task k3s:install` | Install K3s on Raspberry Pi |
| `task argocd:install` | Install ArgoCD |
| `task build` | Build all applications |

## Accessing Services

Once deployed, services are available at:

| Service | URL |
|---------|-----|
| ArgoCD | https://argocd.pi.local |
| Grafana | https://grafana.pi.local |
| Prometheus | https://prometheus.pi.local |

> Note: Add entries to your `/etc/hosts` or configure local DNS to resolve `*.pi.local` to your Pi's IP address.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Raspberry Pi 4B                         │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                      K3s Cluster                      │  │
│  │                                                       │  │
│  │  ┌─────────┐  ┌─────────┐  ┌──────────────────────┐   │  │
│  │  │ ArgoCD  │  │ Traefik │  │    Observability     │   │  │
│  │  │         │  │ Ingress │  │  Grafana | Loki      │   │  │
│  │  └─────────┘  └─────────┘  │  Prometheus          │   │  │
│  │                            └──────────────────────┘   │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │              Application Pods                   │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         ▲
         │ GitOps (ArgoCD syncs from git)
         │
┌────────┴────────┐
│  GitHub Repo    │◄──── GitHub Actions (CI)
│                 │────► ghcr.io (Container Registry)
└─────────────────┘
```

## GitOps Workflow

1. Make changes to application code or infrastructure
2. Push to GitHub
3. GitHub Actions builds and pushes container images
4. ArgoCD detects changes and syncs to the cluster

## Contributing

1. Create a feature branch
2. Make your changes
3. Test locally with `task dev`
4. Submit a pull request

## License

MIT
