# Outputs for GCP us-central1 Environment

output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.cluster_endpoint
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = module.gke.cluster_location
}

output "ntp_static_ip" {
  description = "Static IP address for pool.ntp.org registration"
  value       = module.ntp_infra.ntp_static_ip
}

output "ntp_static_ip_name" {
  description = "Static IP resource name for Kubernetes service annotation"
  value       = module.ntp_infra.ntp_static_ip_name
}

output "kubernetes_service_annotations" {
  description = "Annotations to use for the Kubernetes LoadBalancer service"
  value       = module.ntp_infra.kubernetes_service_annotations
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = module.gke.get_credentials_command
}

output "pool_ntp_org_registration" {
  description = "Instructions for registering with pool.ntp.org"
  value       = <<-EOT
    
    ============================================
    pool.ntp.org Registration Information
    ============================================
    
    Static IP Address: ${module.ntp_infra.ntp_static_ip}
    
    After deploying the Kubernetes manifests:
    1. Verify NTP server is syncing: kubectl exec -n ntp-server <pod-name> -- chronyc tracking
    2. Register at: https://manage.ntppool.org/manage
    3. Add your static IP: ${module.ntp_infra.ntp_static_ip}
    
  EOT
}
