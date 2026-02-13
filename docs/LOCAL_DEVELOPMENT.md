# Local Development Guide

This guide explains how to test the full Kubernetes stack locally using K3d before deploying to the Raspberry Pi.

## Overview

K3d runs K3s (lightweight Kubernetes) inside Docker, providing a local environment that closely mirrors production. This allows you to:

- Test Helm charts and configurations before deploying to the Pi
- Iterate quickly without waiting for remote deployments
- Debug issues in a controlled environment
- Validate ArgoCD applications

## Prerequisites

### Required Tools

Install all dependencies at once using the Brewfile:

```bash
# From project root
brew bundle
```

Or install individually:

```bash
brew install go-task k3d kubectl helm ansible sops age
brew install --cask docker
```

### Verify Installations

```bash
docker --version      # Docker 24+
k3d version           # K3d 5+
kubectl version       # Client version
helm version          # Helm 3+
task --version        # Task 3+
```

## Quick Start

```bash
# 1. Create local cluster
task k3d:create

# 2. Deploy the full stack
task local:deploy

# 3. Validate everything is working
task local:test

# 4. Access services (see URLs below)
```

## Cluster Management

### Create Cluster

```bash
task k3d:create
```

This creates a single-node K3d cluster with:
- K3s without Traefik (we install our own)
- Port mappings for HTTP (80) and HTTPS (443)
- Local registry at `localhost:5050`

### Delete Cluster

```bash
task k3d:delete
```

Completely removes the cluster and all data.

### Stop/Start Cluster

```bash
# Stop (preserves data)
task k3d:stop

# Start again
task k3d:start
```

### Check Cluster Status

```bash
# View nodes
kubectl get nodes

# View all pods
kubectl get pods -A
```

## Deploying the Stack

### Full Stack Deployment

```bash
task local:deploy
```

This deploys:
1. Traefik ingress controller
2. Prometheus (metrics)
3. Loki (logs)
4. Promtail (log shipping)
5. Grafana (dashboards)

### Individual Components

```bash
# Deploy only Traefik
helm upgrade --install traefik traefik/traefik \
  -n kube-system \
  -f infrastructure/helm-values/local/traefik.yaml

# Deploy only Prometheus
helm upgrade --install prometheus prometheus-community/prometheus \
  -n monitoring --create-namespace \
  -f infrastructure/helm-values/local/prometheus.yaml
```

## Accessing Services

### Port Forwarding (Recommended for Development)

```bash
# ArgoCD (if installed)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
```

Then access:
- ArgoCD: https://localhost:8080
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090

### Via Ingress (localhost)

Add to `/etc/hosts`:

```
127.0.0.1 grafana.local prometheus.local argocd.local
```

Then access via browser:
- http://grafana.local
- http://prometheus.local

### Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Grafana | admin | admin (change on first login) |
| ArgoCD | admin | Run `task argocd:password` |

## Validation

### Run Full Validation

```bash
task local:test
```

This checks:
- All pods are running
- Services are accessible
- Prometheus is scraping metrics
- Loki is receiving logs
- Grafana dashboards load

### Manual Checks

```bash
# Check all pods are running
kubectl get pods -A

# Check services
kubectl get svc -A

# Check ingress routes
kubectl get ingress -A

# View logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

## Working with Local Images

### Building and Loading Images

```bash
# Build image
docker build -t my-app:local ./apps/my-app

# Load into K3d cluster
k3d image import my-app:local -c k3s-local

# Or use the local registry
docker tag my-app:local localhost:5050/my-app:local
docker push localhost:5050/my-app:local
```

### Using Local Registry in Deployments

```yaml
# In your Kubernetes manifest
containers:
  - name: my-app
    image: localhost:5050/my-app:local
```

## Differences from Production

| Aspect | Local (K3d) | Production (Pi) |
|--------|-------------|-----------------|
| Architecture | x86_64 | ARM64 |
| Resources | Generous | Limited (4GB RAM) |
| Storage | Docker volumes | Local-path provisioner |
| Ingress | localhost | Static IP (192.168.1.100) |
| TLS | Self-signed | Self-signed (or Let's Encrypt) |

### Resource Limits

Local values use reduced resource limits compared to production:

```yaml
# Local values (example)
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

## Troubleshooting

### Cluster Won't Start

```bash
# Check Docker is running
docker ps

# Check K3d clusters
k3d cluster list

# Delete and recreate if stuck
task k3d:delete
task k3d:create
```

### Pods Stuck in Pending

```bash
# Check events
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl describe node

# Common fix: increase Docker resources in Docker Desktop settings
```

### Can't Access Services

```bash
# Check port mappings
docker ps | grep k3d

# Verify service endpoints
kubectl get endpoints -A

# Check ingress controller
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

### Helm Chart Errors

```bash
# Update Helm repos
helm repo update

# Check chart values
helm show values <chart-name>

# Debug with dry-run
helm upgrade --install <release> <chart> -f values.yaml --dry-run --debug
```

### Reset Everything

```bash
# Nuclear option - delete everything and start fresh
task k3d:delete
task k3d:create
task local:deploy
```

## Development Workflow

### Recommended Workflow

1. **Make changes** to Helm values or manifests
2. **Test locally** with `task local:deploy`
3. **Validate** with `task local:test`
4. **Commit** changes
5. **Deploy to Pi** - ArgoCD syncs automatically

### Iterating on Changes

```bash
# Quick redeploy after changes
helm upgrade --install <release> <chart> -f values.yaml

# Watch pods restart
kubectl get pods -n monitoring -w
```

## Next Steps

Once your changes work locally:

1. Commit and push changes
2. ArgoCD on the Pi will detect changes
3. Automatic sync applies updates to production

For first-time Pi setup, see [SETUP_PI.md](SETUP_PI.md).
