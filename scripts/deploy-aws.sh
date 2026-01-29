#!/bin/bash
# AWS Deployment Script for NTP Server
# This script deploys the complete NTP server infrastructure to AWS EKS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_ROOT/terraform/environments/aws-us-east-1"
K8S_DIR="$PROJECT_ROOT/kubernetes/overlays/aws"
DOCKER_DIR="$PROJECT_ROOT/docker"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  NTP Server - AWS Deployment Script   ${NC}"
echo -e "${GREEN}========================================${NC}"

# Check prerequisites
check_prerequisites() {
    echo -e "\n${YELLOW}Checking prerequisites...${NC}"
    
    command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Terraform is required but not installed.${NC}" >&2; exit 1; }
    command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI is required but not installed.${NC}" >&2; exit 1; }
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
        echo -e "${RED}Please edit terraform.tfvars with your configuration and run this script again.${NC}"
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
    EIP_ID=$(terraform output -raw ntp_eip_allocation_id)
    STATIC_IP=$(terraform output -raw ntp_static_ip)
    
    echo -e "\n${GREEN}Terraform deployment complete!${NC}"
    echo -e "Cluster Name: ${CLUSTER_NAME}"
    echo -e "Static IP: ${STATIC_IP}"
    echo -e "EIP Allocation ID: ${EIP_ID}"
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
    
    # Get AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION="us-east-1"
    ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ntp-server"
    
    # Create ECR repository if it doesn't exist
    aws ecr describe-repositories --repository-names ntp-server --region "$AWS_REGION" 2>/dev/null || \
        aws ecr create-repository --repository-name ntp-server --region "$AWS_REGION"
    
    # Login to ECR
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    # Build and push
    docker build -t ntp-server:latest .
    docker tag ntp-server:latest "${ECR_REPO}:latest"
    docker push "${ECR_REPO}:latest"
    
    echo -e "${GREEN}Docker image pushed to ECR: ${ECR_REPO}:latest${NC}"
    
    # Update kustomization with correct image
    cd "$K8S_DIR"
    sed -i "s|<AWS_ACCOUNT_ID>|${AWS_ACCOUNT_ID}|g" kustomization.yaml
}

# Deploy Kubernetes resources
deploy_kubernetes() {
    echo -e "\n${YELLOW}Deploying Kubernetes resources...${NC}"
    
    cd "$TF_DIR"
    EIP_ID=$(terraform output -raw ntp_eip_allocation_id)
    
    # Update the EIP patch
    cd "$K8S_DIR"
    sed -i "s|EIP_ALLOCATION_ID|${EIP_ID}|g" eip-patch.yaml
    
    # Apply with kustomize
    kubectl apply -k .
    
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
    
    # Get external IP
    echo -e "\n${YELLOW}Waiting for LoadBalancer IP...${NC}"
    while true; do
        EXTERNAL_IP=$(kubectl get svc ntp-server -n ntp-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
        if [ -n "$EXTERNAL_IP" ]; then
            echo -e "${GREEN}LoadBalancer Hostname: ${EXTERNAL_IP}${NC}"
            break
        fi
        sleep 10
    done
    
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
