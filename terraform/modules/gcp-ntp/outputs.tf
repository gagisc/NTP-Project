# Outputs for GCP NTP Infrastructure Module

output "ntp_static_ip" {
  description = "Static external IP address for NTP server"
  value       = google_compute_address.ntp.address
}

output "ntp_static_ip_name" {
  description = "Name of the static IP resource"
  value       = google_compute_address.ntp.name
}

output "ntp_static_ip_self_link" {
  description = "Self link of the static IP resource"
  value       = google_compute_address.ntp.self_link
}

output "firewall_rule_udp_name" {
  description = "Name of the UDP firewall rule"
  value       = google_compute_firewall.ntp_udp.name
}

output "firewall_rule_tcp_name" {
  description = "Name of the TCP firewall rule"
  value       = google_compute_firewall.ntp_tcp.name
}

output "kubernetes_service_annotations" {
  description = "Annotations to use for the Kubernetes LoadBalancer service"
  value = {
    "cloud.google.com/l4-rbs"                       = "enabled"
    "networking.gke.io/load-balancer-ip-addresses"  = google_compute_address.ntp.name
  }
}

output "pool_ntp_org_registration_ip" {
  description = "IP address to register with pool.ntp.org"
  value       = google_compute_address.ntp.address
}
