// Variables for GCP k3s NTP environment

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "name" {
  description = "Name prefix for NTP resources"
  type        = string
  default     = "ntp-k3s-server"
}

variable "machine_type" {
  description = "Machine type (e2-micro is free-tier eligible)"
  type        = string
  default     = "e2-micro"
}

variable "image" {
  description = "Boot image (Debian/Ubuntu)."
  type        = string
  // Debian 12 generic; user can override
  default = "debian-cloud/debian-12"
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH (22). Leave empty to disable SSH."
  type        = list(string)
  default     = []
}

variable "k3s_api_cidr_blocks" {
  description = "CIDR blocks allowed for k3s API (6443). Leave empty to restrict."
  type        = list(string)
  default     = []
}

