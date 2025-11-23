#!/bin/bash
# Canary Deployment Management Script
# Supports gradual traffic shifting for canary deployments

set -e

NAMESPACE="deployment-strategies"
SERVICE_NAME="web-service-canary"

print_usage() {
    echo "Canary Deployment Manager"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status              - Show current canary deployment status"
    echo "  start-canary        - Start canary deployment with 1 replica"
    echo "  scale-canary <n>    - Scale canary to N replicas (increases traffic %)"
    echo "  promote-canary      - Promote canary to stable (make it the main version)"
    echo "  rollback-canary     - Rollback by scaling down canary"
    echo "  test-traffic        - Test traffic distribution across pods"
    echo ""
}

get_pod_counts() {
    STABLE_PODS=$(kubectl get pods -n $NAMESPACE -l track=stable --no-headers 2>/dev/null | wc -l)
    CANARY_PODS=$(kubectl get pods -n $NAMESPACE -l track=canary --no-headers 2>/dev/null | wc -l)
}

show_status() {
    echo "=== Canary Deployment Status ==="
    
    get_pod_counts
    
    echo "Stable (v1.0) deployment:"
    kubectl get deployment web-service-stable -n $NAMESPACE -o wide 2>/dev/null || echo "Not found"
    echo "Replicas: $STABLE_PODS"
    echo ""
    
    echo "Canary (v2.0) deployment:"
    kubectl get deployment web-service-canary -n $NAMESPACE -o wide 2>/dev/null || echo "Not found"
    echo "Replicas: $CANARY_PODS"
    echo ""
    
    TOTAL=$((STABLE_PODS + CANARY_PODS))
    if [ $TOTAL -gt 0 ]; then
        CANARY_PERCENT=$((CANARY_PODS * 100 / TOTAL))
        echo "Traffic distribution:"
        echo "  Stable: $STABLE_PODS pods ($((100 - CANARY_PERCENT))%)"
        echo "  Canary: $CANARY_PODS pods ($CANARY_PERCENT%)"
    fi
}

start_canary() {
    echo "Starting canary deployment with 1 replica..."
    kubectl scale deployment web-service-canary -n $NAMESPACE --replicas=1
    echo "Waiting for canary pods to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/web-service-canary -n $NAMESPACE
    echo "✓ Canary deployment started"
    show_status
}

scale_canary() {
    if [ -z "$1" ]; then
        echo "Error: Please specify number of replicas"
        echo "Usage: $0 scale-canary <number>"
        exit 1
    fi
    
    REPLICAS=$1
    echo "Scaling canary deployment to $REPLICAS replicas..."
    kubectl scale deployment web-service-canary -n $NAMESPACE --replicas=$REPLICAS
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/web-service-canary -n $NAMESPACE 2>/dev/null || true
    echo "✓ Canary scaled to $REPLICAS replicas"
    show_status
}

promote_canary() {
    echo "Promoting canary to stable..."
    echo "This will:"
    echo "  1. Scale canary up to 3 replicas"
    echo "  2. Update stable deployment image to v2.0"
    echo "  3. Scale down canary to 0 replicas"
    
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        return 1
    fi
    
    echo "Step 1: Scaling canary to 3 replicas..."
    kubectl scale deployment web-service-canary -n $NAMESPACE --replicas=3
    kubectl wait --for=condition=available --timeout=300s deployment/web-service-canary -n $NAMESPACE
    
    echo "Step 2: Updating stable deployment to use v2.0 image..."
    kubectl set image deployment/web-service-stable web-service=web-service:2.0 -n $NAMESPACE
    kubectl set env deployment/web-service-stable SERVICE_VERSION=2.0 -n $NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/web-service-stable -n $NAMESPACE
    
    echo "Step 3: Scaling down canary..."
    kubectl scale deployment web-service-canary -n $NAMESPACE --replicas=0
    
    echo "✓ Canary promoted to stable"
    show_status
}

rollback_canary() {
    echo "Rolling back canary deployment..."
    kubectl scale deployment web-service-canary -n $NAMESPACE --replicas=0
    echo "✓ Canary rolled back"
    show_status
}

test_traffic() {
    echo "Testing traffic distribution across pods..."
    
    # Get all pods
    PODS=$(kubectl get pods -n $NAMESPACE -l app=web-service-canary -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$PODS" ]; then
        echo "No pods found"
        return 1
    fi
    
    echo "Sending 10 requests to service and tracking which pod responds:"
    echo ""
    
    declare -A pod_counts
    SERVICE_IP=$(kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost")
    
    for i in {1..10}; do
        # Try to determine which pod responded by checking pod IPs
        RESPONSE=$(kubectl run test-$i --image=curlimages/curl:latest --rm -i --restart=Never -- curl -s http://$SERVICE_IP/version 2>/dev/null || echo "{}")
        VERSION=$(echo "$RESPONSE" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        echo "Request $i: Version $VERSION"
    done
}

# Main script
if [ $# -eq 0 ]; then
    print_usage
    exit 1
fi

case "$1" in
    status)
        show_status
        ;;
    start-canary)
        start_canary
        ;;
    scale-canary)
        scale_canary "$2"
        ;;
    promote-canary)
        promote_canary
        ;;
    rollback-canary)
        rollback_canary
        ;;
    test-traffic)
        test_traffic
        ;;
    *)
        echo "Unknown command: $1"
        print_usage
        exit 1
        ;;
esac
