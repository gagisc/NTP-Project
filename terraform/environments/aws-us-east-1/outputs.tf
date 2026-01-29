# Outputs for AWS us-east-1 Environment

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "ntp_static_ip" {
  description = "Static IP address for pool.ntp.org registration"
  value       = module.ntp_infra.ntp_eip_public_ip
}

output "ntp_eip_allocation_id" {
  description = "Elastic IP allocation ID for Kubernetes service annotation"
  value       = module.ntp_infra.ntp_eip_id
}

output "kubernetes_service_annotations" {
  description = "Annotations to use for the Kubernetes LoadBalancer service"
  value       = module.ntp_infra.kubernetes_service_annotations
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "pool_ntp_org_registration" {
  description = "Instructions for registering with pool.ntp.org"
  value       = <<-EOT
    
    ============================================
    pool.ntp.org Registration Information
    ============================================
    
    Static IP Address: ${module.ntp_infra.ntp_eip_public_ip}
    
    After deploying the Kubernetes manifests:
    1. Verify NTP server is syncing: kubectl exec -n ntp-server <pod-name> -- chronyc tracking
    2. Register at: https://manage.ntppool.org/manage
    3. Add your static IP: ${module.ntp_infra.ntp_eip_public_ip}
    
  EOT
}
