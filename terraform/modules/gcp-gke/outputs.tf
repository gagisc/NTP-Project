# Outputs for GCP GKE Module

output "cluster_id" {
  description = "GKE cluster ID"
  value       = google_container_cluster.ntp.id
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.ntp.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.ntp.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = google_container_cluster.ntp.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.ntp.location
}

output "vpc_id" {
  description = "VPC network ID"
  value       = google_compute_network.ntp.id
}

output "vpc_name" {
  description = "VPC network name"
  value       = google_compute_network.ntp.name
}

output "subnet_id" {
  description = "Subnet ID"
  value       = google_compute_subnetwork.ntp.id
}

output "subnet_name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.ntp.name
}

output "workload_identity_sa_email" {
  description = "Service account email for Workload Identity"
  value       = google_service_account.ntp_workload.email
}

output "node_pool_name" {
  description = "GKE node pool name"
  value       = google_container_node_pool.ntp.name
}

output "get_credentials_command" {
  description = "Command to get cluster credentials"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.ntp.name} --region ${var.region} --project ${var.project_id}"
}
