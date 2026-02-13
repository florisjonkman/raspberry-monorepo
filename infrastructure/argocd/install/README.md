# ArgoCD Installation

This directory contains ArgoCD installation manifests.

## Installation

### Option 1: Using Task

```bash
task argocd:install
```

### Option 2: Using kubectl

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Post-Installation

1. Get the initial admin password:

```bash
task argocd:password
```

2. Access the UI via port-forward:

```bash
task argocd:port-forward
# Open https://localhost:8080
```

3. Login with username `admin` and the password from step 1.

4. Apply the root application to bootstrap all other applications:

```bash
kubectl apply -f ../applications/root.yaml
```

## Upgrading

To upgrade ArgoCD, update the manifest URL version and re-apply:

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.0/manifests/install.yaml
```
