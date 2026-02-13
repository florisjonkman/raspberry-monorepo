#!/bin/bash
# Cluster validation script
# Verifies that all pods are running and services are accessible

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

info() {
    echo -e "[INFO] $1"
}

section() {
    echo ""
    echo "============================================"
    echo "$1"
    echo "============================================"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    fail "kubectl is not installed or not in PATH"
    exit 1
fi

# Check cluster connectivity
section "Cluster Connectivity"

if kubectl cluster-info &> /dev/null; then
    pass "Connected to Kubernetes cluster"
else
    fail "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check nodes
section "Node Status"

NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || echo "0")

if [ "$NODE_COUNT" -eq 0 ]; then
    fail "No nodes found in cluster"
elif [ "$NODE_COUNT" -eq "$READY_NODES" ]; then
    pass "All $NODE_COUNT node(s) are Ready"
else
    fail "Only $READY_NODES of $NODE_COUNT nodes are Ready"
fi

# Check system pods
section "System Pods (kube-system)"

SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l | tr -d ' ')
RUNNING_SYSTEM=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")

if [ "$SYSTEM_PODS" -eq 0 ]; then
    fail "No system pods found"
elif [ "$SYSTEM_PODS" -eq "$RUNNING_SYSTEM" ]; then
    pass "All $SYSTEM_PODS system pods are Running"
else
    warn "$RUNNING_SYSTEM of $SYSTEM_PODS system pods are Running"
    kubectl get pods -n kube-system --no-headers | grep -v "Running"
fi

# Check monitoring namespace
section "Monitoring Pods"

if kubectl get namespace monitoring &> /dev/null; then
    MONITORING_PODS=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l | tr -d ' ')
    RUNNING_MONITORING=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | grep -c "Running" || echo "0")

    if [ "$MONITORING_PODS" -eq 0 ]; then
        warn "No monitoring pods found (stack may not be deployed yet)"
    elif [ "$MONITORING_PODS" -eq "$RUNNING_MONITORING" ]; then
        pass "All $MONITORING_PODS monitoring pods are Running"
    else
        warn "$RUNNING_MONITORING of $MONITORING_PODS monitoring pods are Running"
        kubectl get pods -n monitoring --no-headers | grep -v "Running"
    fi
else
    warn "Monitoring namespace does not exist (stack may not be deployed yet)"
fi

# Check ArgoCD namespace
section "ArgoCD Status"

if kubectl get namespace argocd &> /dev/null; then
    ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l | tr -d ' ')
    RUNNING_ARGOCD=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c "Running" || echo "0")

    if [ "$ARGOCD_PODS" -eq 0 ]; then
        warn "No ArgoCD pods found"
    elif [ "$ARGOCD_PODS" -eq "$RUNNING_ARGOCD" ]; then
        pass "All $ARGOCD_PODS ArgoCD pods are Running"
    else
        warn "$RUNNING_ARGOCD of $ARGOCD_PODS ArgoCD pods are Running"
        kubectl get pods -n argocd --no-headers | grep -v "Running"
    fi
else
    warn "ArgoCD namespace does not exist (may not be installed yet)"
fi

# Check services
section "Service Endpoints"

# Prometheus
if kubectl get svc prometheus-server -n monitoring &> /dev/null; then
    PROM_ENDPOINT=$(kubectl get endpoints prometheus-server -n monitoring -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || echo "")
    if [ -n "$PROM_ENDPOINT" ]; then
        pass "Prometheus service has endpoints"
    else
        fail "Prometheus service has no endpoints"
    fi
else
    warn "Prometheus service not found"
fi

# Grafana
if kubectl get svc grafana -n monitoring &> /dev/null; then
    GRAFANA_ENDPOINT=$(kubectl get endpoints grafana -n monitoring -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || echo "")
    if [ -n "$GRAFANA_ENDPOINT" ]; then
        pass "Grafana service has endpoints"
    else
        fail "Grafana service has no endpoints"
    fi
else
    warn "Grafana service not found"
fi

# Loki
if kubectl get svc loki -n monitoring &> /dev/null; then
    LOKI_ENDPOINT=$(kubectl get endpoints loki -n monitoring -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || echo "")
    if [ -n "$LOKI_ENDPOINT" ]; then
        pass "Loki service has endpoints"
    else
        fail "Loki service has no endpoints"
    fi
else
    warn "Loki service not found"
fi

# Check Traefik ingress
section "Ingress Controller"

if kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik --no-headers 2>/dev/null | grep -q "Running"; then
    pass "Traefik ingress controller is running"
else
    warn "Traefik ingress controller not found or not running"
fi

# Resource usage
section "Resource Usage"

if kubectl top nodes &> /dev/null; then
    info "Node resource usage:"
    kubectl top nodes
    pass "Metrics server is working"
else
    warn "Metrics server not available (kubectl top not working)"
fi

# Summary
section "Validation Summary"

TOTAL=$((PASSED + FAILED + WARNINGS))

echo ""
echo -e "${GREEN}Passed:${NC}   $PASSED"
echo -e "${RED}Failed:${NC}   $FAILED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Validation FAILED with $FAILED error(s)${NC}"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}Validation passed with $WARNINGS warning(s)${NC}"
    exit 0
else
    echo -e "${GREEN}All validations passed!${NC}"
    exit 0
fi
