# GCP us-central1 Environment Configuration
# NTP Server deployment for pool.ntp.org

terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  # Uncomment and configure for remote state
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "ntp-server/gcp-us-central1"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Get GKE cluster credentials
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  }
}

# GKE Cluster Module
module "gke" {
  source = "../../modules/gcp-gke"

  project_id          = var.project_id
  cluster_name        = var.cluster_name
  region              = var.region
  subnet_cidr         = var.subnet_cidr
  pods_cidr           = var.pods_cidr
  services_cidr       = var.services_cidr
  master_cidr         = var.master_cidr
  machine_type        = var.machine_type
  node_count_per_zone = var.node_count_per_zone
  node_min_count      = var.node_min_count
  node_max_count      = var.node_max_count
}

# NTP Infrastructure Module
module "ntp_infra" {
  source = "../../modules/gcp-ntp"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.region
  vpc_name     = module.gke.vpc_name
}

# Create namespace for NTP server
resource "kubernetes_namespace" "ntp_server" {
  metadata {
    name = "ntp-server"

    labels = {
      app = "ntp-server"
    }
  }

  depends_on = [module.gke]
}

# ConfigMap for storing the static IP (for Kustomize patching)
resource "kubernetes_config_map" "ntp_config" {
  metadata {
    name      = "ntp-infra-config"
    namespace = kubernetes_namespace.ntp_server.metadata[0].name
  }

  data = {
    static_ip      = module.ntp_infra.ntp_static_ip
    static_ip_name = module.ntp_infra.ntp_static_ip_name
  }

  depends_on = [kubernetes_namespace.ntp_server]
}
