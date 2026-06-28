// GCP Compute Engine-based k3s NTP server for pool.ntp.org
// Lean architecture: single e2-micro + static IP + k3s (no managed GKE)

terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

// Static external IP for pool.ntp.org
resource "google_compute_address" "ntp" {
  name         = "${var.name}-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

// Firewall rule: NTP (UDP+TCP 123) open to the world
resource "google_compute_firewall" "ntp" {
  name    = "${var.name}-ntp"
  project = var.project_id
  network = "default"

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "udp"
    ports    = ["123"]
  }

  allow {
    protocol = "tcp"
    ports    = ["123"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.name]
}

// Firewall rule: SSH (TCP 22) only from specified CIDRs
resource "google_compute_firewall" "ssh" {
  count   = length(var.ssh_cidr_blocks) > 0 ? 1 : 0
  name    = "${var.name}-ssh"
  project = var.project_id
  network = "default"

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_cidr_blocks
  target_tags   = [var.name]
}

// Firewall rule: k3s API (TCP 6443) only from specified CIDRs
resource "google_compute_firewall" "k3s_api" {
  count   = length(var.k3s_api_cidr_blocks) > 0 ? 1 : 0
  name    = "${var.name}-k3s-api"
  project = var.project_id
  network = "default"

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = var.k3s_api_cidr_blocks
  target_tags   = [var.name]
}

// Metadata startup script to install k3s and prepare for NTP pod
locals {
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Disable default NTP to free port 123
    if systemctl is-enabled systemd-timesyncd >/dev/null 2>&1; then
      systemctl disable --now systemd-timesyncd || true
    fi
    if systemctl is-enabled chronyd >/dev/null 2>&1; then
      systemctl disable --now chronyd || true
    fi

    # Install basic tools
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl

    # Install k3s server
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --write-kubeconfig-mode 644" sh -

    # k3s kubeconfig -> /etc/rancher/k3s/k3s.yaml
  EOT
}

resource "google_compute_instance" "ntp" {
  name         = var.name
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type

  tags = [var.name]

  boot_disk {
    initialize_params {
      image = var.image
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.ntp.address
    }
  }

  metadata = {
    startup-script = local.startup_script
  }
}

