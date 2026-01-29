# GCP NTP Infrastructure Module
# This module creates static IP and firewall rules for NTP server

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Static External IP for NTP Server (for pool.ntp.org registration)
resource "google_compute_address" "ntp" {
  name         = "${var.cluster_name}-ntp-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"

  description = "Static IP for NTP server - pool.ntp.org"
}

# Firewall rule to allow NTP UDP traffic
resource "google_compute_firewall" "ntp_udp" {
  name        = "${var.cluster_name}-allow-ntp-udp"
  project     = var.project_id
  network     = var.vpc_name
  description = "Allow NTP UDP traffic from anywhere"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "udp"
    ports    = ["123"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ntp-server"]
}

# Firewall rule to allow NTP TCP traffic (fallback, rare)
resource "google_compute_firewall" "ntp_tcp" {
  name        = "${var.cluster_name}-allow-ntp-tcp"
  project     = var.project_id
  network     = var.vpc_name
  description = "Allow NTP TCP traffic from anywhere (fallback)"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["123"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ntp-server"]
}

# Firewall rule to allow health checks from GCP load balancer
resource "google_compute_firewall" "health_check" {
  name        = "${var.cluster_name}-allow-health-check"
  project     = var.project_id
  network     = var.vpc_name
  description = "Allow health checks from GCP load balancer ranges"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["10256"] # kubelet health check port
  }

  # GCP health check ranges
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]
  target_tags = ["ntp-server"]
}

# Firewall rule for outbound traffic to upstream NTP servers
resource "google_compute_firewall" "ntp_egress" {
  name        = "${var.cluster_name}-allow-ntp-egress"
  project     = var.project_id
  network     = var.vpc_name
  description = "Allow outbound NTP traffic to upstream servers"
  direction   = "EGRESS"
  priority    = 1000

  allow {
    protocol = "udp"
    ports    = ["123"]
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["ntp-server"]
}
