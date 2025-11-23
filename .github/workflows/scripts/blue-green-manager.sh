#!/bin/bash
# Blue/Green Deployment Management Script
# Supports switching between blue and green deployments

set -e

NAMESPACE="deployment-strategies"
SERVICE_NAME="web-service"

print_usage() {
    echo "Blue/Green Deployment Manager"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status           - Show current active deployment (blue or green)"
    echo "  switch-to-green  - Switch traffic to green deployment"
    echo "  switch-to-blue   - Switch traffic back to blue deployment"
    echo "  scale-green      - Scale up green deployment to prepare for switch"
    echo "  scale-blue       - Scale up blue deployment to prepare for switch"
    echo "  test-both        - Test both blue and green endpoints"
    echo ""
}

get_current_slot() {
    kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.selector.slot}' 2>/dev/null || echo "unknown"
}

show_status() {
    echo "=== Blue/Green Deployment Status ==="
    CURRENT=$(get_current_slot)
    echo "Active deployment: $CURRENT"
    echo ""
    
    echo "Blue deployment:"
    kubectl get deployment web-service-blue -n $NAMESPACE -o wide 2>/dev/null || echo "Not found"
    echo ""
    
    echo "Green deployment:"
    kubectl get deployment web-service-green -n $NAMESPACE -o wide 2>/dev/null || echo "Not found"
}

switch_to_green() {
    echo "Preparing to switch to GREEN deployment..."
    echo "Step 1: Scaling up green deployment..."
    kubectl scale deployment web-service-green -n $NAMESPACE --replicas=2
    
    echo "Waiting for green pods to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/web-service-green -n $NAMESPACE
    
    echo "Step 2: Switching service selector to green..."
    kubectl patch service $SERVICE_NAME -n $NAMESPACE -p '{"spec":{"selector":{"slot":"green"}}}'
    
    echo "✓ Successfully switched to GREEN deployment"
    show_status
}

switch_to_blue() {
    echo "Preparing to switch to BLUE deployment..."
    echo "Step 1: Scaling up blue deployment..."
    kubectl scale deployment web-service-blue -n $NAMESPACE --replicas=2
    
    echo "Waiting for blue pods to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/web-service-blue -n $NAMESPACE
    
    echo "Step 2: Switching service selector to blue..."
    kubectl patch service $SERVICE_NAME -n $NAMESPACE -p '{"spec":{"selector":{"slot":"blue"}}}'
    
    echo "✓ Successfully switched to BLUE deployment"
    show_status
}

scale_green() {
    echo "Scaling up green deployment to 2 replicas..."
    kubectl scale deployment web-service-green -n $NAMESPACE --replicas=2
    echo "Waiting for green pods to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/web-service-green -n $NAMESPACE
    echo "✓ Green deployment ready"
}

scale_blue() {
    echo "Scaling up blue deployment to 2 replicas..."
    kubectl scale deployment web-service-blue -n $NAMESPACE --replicas=2
    echo "Waiting for blue pods to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/web-service-blue -n $NAMESPACE
    echo "✓ Blue deployment ready"
}

test_both() {
    echo "Testing both deployments..."
    BLUE_POD=$(kubectl get pod -n $NAMESPACE -l slot=blue -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    GREEN_POD=$(kubectl get pod -n $NAMESPACE -l slot=green -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$BLUE_POD" ]; then
        echo "Testing BLUE pod ($BLUE_POD):"
        kubectl exec -it $BLUE_POD -n $NAMESPACE -- curl -s http://localhost:5000/version | jq . || echo "Blue pod not ready"
    else
        echo "No blue pods found"
    fi
    
    echo ""
    
    if [ -n "$GREEN_POD" ]; then
        echo "Testing GREEN pod ($GREEN_POD):"
        kubectl exec -it $GREEN_POD -n $NAMESPACE -- curl -s http://localhost:5000/version | jq . || echo "Green pod not ready"
    else
        echo "No green pods found"
    fi
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
    switch-to-green)
        switch_to_green
        ;;
    switch-to-blue)
        switch_to_blue
        ;;
    scale-green)
        scale_green
        ;;
    scale-blue)
        scale_blue
        ;;
    test-both)
        test_both
        ;;
    *)
        echo "Unknown command: $1"
        print_usage
        exit 1
        ;;
esac
