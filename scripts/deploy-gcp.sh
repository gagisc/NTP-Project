#!/bin/bash
# GCP Deployment Script for NTP Server
# This script deploys the complete NTP server infrastructure to GCP GKE

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_ROOT/terraform/environments/gcp-us-central1"
K8S_DIR="$PROJECT_ROOT/kubernetes/overlays/gcp"
DOCKER_DIR="$PROJECT_ROOT/docker"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  NTP Server - GCP Deployment Script   ${NC}"
echo -e "${GREEN}========================================${NC}"

# Check prerequisites
check_prerequisites() {
    echo -e "\n${YELLOW}Checking prerequisites...${NC}"
    
    command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Terraform is required but not installed.${NC}" >&2; exit 1; }
    command -v gcloud >/dev/null 2>&1 || { echo -e "${RED}gcloud CLI is required but not installed.${NC}" >&2; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
    command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker is required but not installed.${NC}" >&2; exit 1; }
    
    echo -e "${GREEN}All prerequisites are installed.${NC}"
}

# Deploy Terraform infrastructure
deploy_terraform() {
    echo -e "\n${YELLOW}Deploying Terraform infrastructure...${NC}"
    
    cd "$TF_DIR"
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        echo -e "${YELLOW}Creating terraform.tfvars from example...${NC}"
        cp terraform.tfvars.example terraform.tfvars
        echo -e "${RED}Please edit terraform.tfvars with your GCP project ID and run this script again.${NC}"
        exit 1
    fi
    
    terraform init
    terraform plan -out=tfplan
    
    echo -e "\n${YELLOW}Review the plan above. Apply? (yes/no)${NC}"
    read -r response
    if [ "$response" = "yes" ]; then
        terraform apply tfplan
    else
        echo -e "${RED}Deployment cancelled.${NC}"
        exit 1
    fi
    
    # Get outputs
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    STATIC_IP_NAME=$(terraform output -raw ntp_static_ip_name)
    STATIC_IP=$(terraform output -raw ntp_static_ip)
    
    echo -e "\n${GREEN}Terraform deployment complete!${NC}"
    echo -e "Cluster Name: ${CLUSTER_NAME}"
    echo -e "Static IP: ${STATIC_IP}"
    echo -e "Static IP Name: ${STATIC_IP_NAME}"
}

# Configure kubectl
configure_kubectl() {
    echo -e "\n${YELLOW}Configuring kubectl...${NC}"
    
    cd "$TF_DIR"
    CONFIGURE_CMD=$(terraform output -raw configure_kubectl)
    eval "$CONFIGURE_CMD"
    
    echo -e "${GREEN}kubectl configured successfully.${NC}"
    kubectl cluster-info
}

# Build and push Docker image
build_and_push_image() {
    echo -e "\n${YELLOW}Building and pushing Docker image...${NC}"
    
    cd "$DOCKER_DIR"
    
    # Get GCP project ID
    PROJECT_ID=$(gcloud config get-value project)
    REGION="us-central1"
    AR_REPO="${REGION}-docker.pkg.dev/${PROJECT_ID}/ntp-server"
    
    # Create Artifact Registry repository if it doesn't exist
    gcloud artifacts repositories describe ntp-server --location="$REGION" 2>/dev/null || \
        gcloud artifacts repositories create ntp-server \
            --repository-format=docker \
            --location="$REGION" \
            --description="NTP Server container images"
    
    # Configure Docker for Artifact Registry
    gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
    
    # Build and push
    docker build -t ntp-server:latest .
    docker tag ntp-server:latest "${AR_REPO}/ntp-server:latest"
    docker push "${AR_REPO}/ntp-server:latest"
    
    echo -e "${GREEN}Docker image pushed to Artifact Registry: ${AR_REPO}/ntp-server:latest${NC}"
    
    # Export for use in deploy_kubernetes
    export PROJECT_ID REGION AR_REPO
}

# Deploy Kubernetes resources
deploy_kubernetes() {
    echo -e "\n${YELLOW}Deploying Kubernetes resources...${NC}"
    
    cd "$TF_DIR"
    STATIC_IP_NAME=$(terraform output -raw ntp_static_ip_name)
    PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
    
    # Write params.env for Kustomize replacements (temp dir keeps source clean)
    OVERLAY_TMP="$(mktemp -d)"
    trap 'rm -rf "$OVERLAY_TMP"' EXIT
    cp -r "$K8S_DIR/." "$OVERLAY_TMP/"

    GCP_WORKLOAD_SA="${CLUSTER_NAME:-ntp-server-cluster}-workload@${PROJECT_ID}.iam.gserviceaccount.com"
    AR_IMAGE="${REGION:-us-central1}-docker.pkg.dev/${PROJECT_ID}/ntp-server/ntp-server:latest"

    cat > "$OVERLAY_TMP/params.env" <<EOF
AR_IMAGE=${AR_IMAGE}
STATIC_IP_NAME=${STATIC_IP_NAME}
GCP_WORKLOAD_SA=${GCP_WORKLOAD_SA}
EOF

    # Apply with kustomize from the temp overlay
    kubectl apply -k "$OVERLAY_TMP"
    
    echo -e "${GREEN}Kubernetes resources deployed.${NC}"
}

# Verify deployment
verify_deployment() {
    echo -e "\n${YELLOW}Verifying deployment...${NC}"
    
    # Wait for pods to be ready
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=ntp-server -n ntp-server --timeout=300s
    
    # Check pod status
    echo -e "\n${GREEN}Pod Status:${NC}"
    kubectl get pods -n ntp-server
    
    # Check service
    echo -e "\n${GREEN}Service Status:${NC}"
    kubectl get svc -n ntp-server
    
    # Get external IP (timeout after 10 minutes)
    echo -e "\n${YELLOW}Waiting for LoadBalancer IP (up to 10 minutes)...${NC}"
    LB_WAIT=0
    LB_TIMEOUT=60
    while [ "$LB_WAIT" -lt "$LB_TIMEOUT" ]; do
        EXTERNAL_IP=$(kubectl get svc ntp-server -n ntp-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$EXTERNAL_IP" ]; then
            echo -e "${GREEN}LoadBalancer IP: ${EXTERNAL_IP}${NC}"
            break
        fi
        LB_WAIT=$((LB_WAIT + 1))
        sleep 10
    done
    if [ -z "$EXTERNAL_IP" ]; then
        echo -e "${YELLOW}LoadBalancer IP not yet assigned. Check: kubectl get svc -n ntp-server${NC}"
    fi
    
    # Verify chrony is syncing
    echo -e "\n${GREEN}Chrony Tracking Status:${NC}"
    POD_NAME=$(kubectl get pods -n ntp-server -l app=ntp-server -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -n ntp-server "$POD_NAME" -- chronyc tracking
}

# Print registration instructions
print_instructions() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}  Deployment Complete!                  ${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    cd "$TF_DIR"
    terraform output pool_ntp_org_registration
    
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo "1. Wait for chrony to fully synchronize (check with: kubectl exec -n ntp-server <pod> -- chronyc tracking)"
    echo "2. Test NTP response: ntpdate -q <your-static-ip>"
    echo "3. Register at https://manage.ntppool.org/manage"
    echo "4. Monitor your server score at https://www.ntppool.org/scores/<your-static-ip>"
}

# Main execution
main() {
    check_prerequisites
    deploy_terraform
    configure_kubectl
    build_and_push_image
    deploy_kubernetes
    verify_deployment
    print_instructions
}

# Run main function
main "$@"
