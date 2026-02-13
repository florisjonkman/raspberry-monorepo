# CLAUDE.md - Project Instructions for Claude Code

This file provides context and guidelines for Claude Code when working on this project.

## Project Overview

This is a monorepo for a home Kubernetes cluster running on a **Raspberry Pi 4 Model B**. The project contains:

- **Infrastructure as Code** for a K3s cluster with GitOps (ArgoCD)
- **Observability stack** (Grafana, Loki, Prometheus)
- **Applications** (primarily TypeScript/Next.js)

## Architecture

- **Single-node K3s cluster** on Raspberry Pi 4B (ARM64)
- **GitOps** with ArgoCD - all deployments are declarative
- **Local development** uses Docker Compose
- **Production** is the Raspberry Pi on local network

## Tech Stack

### Infrastructure
- **K3s** - Lightweight Kubernetes
- **Traefik** - Ingress controller (bundled with K3s)
- **ArgoCD** - GitOps continuous delivery
- **Helm** - Package manager for Kubernetes
- **Ansible** - Raspberry Pi provisioning
- **SOPS** - Secret encryption in git

### Observability
- **Grafana** - Dashboards
- **Loki** - Log aggregation
- **Promtail** - Log shipping
- **Prometheus** - Metrics

### Applications
- **pnpm** - Package manager
- **Turborepo** - Monorepo build system
- **TypeScript** - Primary language
- **Next.js** - Web framework

### Development
- **Docker Compose** - Local environment
- **Taskfile** - Task runner
- **GitHub Actions** - CI/CD
- **ghcr.io** - Container registry

## Directory Structure

```
raspberry-monorepo/
├── apps/                    # Application source code
├── ansible/                 # Pi provisioning playbooks
├── infrastructure/
│   ├── argocd/             # ArgoCD setup and Application CRDs
│   └── helm-values/        # Helm value overrides
├── docker/                  # Docker Compose for local dev
├── scripts/                 # Utility scripts
└── .github/workflows/       # CI/CD pipelines
```

## Common Commands

```bash
# Task runner (preferred)
task --list                  # List all available tasks

# Local development
task dev                     # Start local dev environment
task down                    # Stop local dev environment

# Kubernetes
task k3s:install            # Install K3s on Pi (via Ansible)
task argocd:install         # Install ArgoCD on cluster

# Applications
pnpm install                 # Install dependencies
pnpm build                   # Build all apps
pnpm dev                     # Run app in dev mode (from app directory)
```

## Development Guidelines

### General
- All Kubernetes resources are managed via GitOps (ArgoCD)
- Never apply manifests directly with `kubectl apply` in production
- Use Helm charts with custom values in `infrastructure/helm-values/`
- Encrypt secrets with SOPS before committing

### Applications
- Each app lives in `apps/<app-name>/`
- Apps must have a `Dockerfile` for containerization
- Use multi-stage builds to keep images small
- Target ARM64 architecture for production builds

### Infrastructure
- Ansible playbooks should be idempotent
- Document any manual steps in INFRASTRUCTURE.md
- Test Helm values locally before pushing

## Raspberry Pi Details

- **Model**: Raspberry Pi 4 Model B
- **FCC ID**: 2ABCB-RPI4B
- **IC**: 20951-RPI4B
- **Architecture**: ARM64 (aarch64)
- **OS**: Raspberry Pi OS Lite (64-bit) or Ubuntu Server

## Important Considerations

### ARM64 Compatibility
- Always verify container images support `linux/arm64`
- Use multi-arch builds in CI/CD
- Some tools may need ARM-specific configurations

### Resource Constraints
- Pi 4B has limited RAM (typically 4GB or 8GB)
- Set appropriate resource limits on all pods
- Loki is preferred over Elasticsearch for logs (lower resource usage)
- Use lightweight alternatives where possible

### Networking
- Production cluster is on local network
- Traefik handles ingress routing
- Consider using `.local` domains or nip.io for local DNS

## Environment Variables

Applications may need these environment variables:

```bash
# Local development
NODE_ENV=development

# Production (set in Kubernetes secrets)
NODE_ENV=production
```

## Secrets Management

- Use SOPS with age encryption for secrets
- Never commit unencrypted secrets
- Secret files should have `.enc.yaml` extension
- See `.sops.yaml` for encryption rules
