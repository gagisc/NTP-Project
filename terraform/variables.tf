# Shared Terraform Variables
# These are common variables that can be referenced across environments

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ntp-server"
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "NTP-Server"
    Purpose     = "pool.ntp.org"
    ManagedBy   = "Terraform"
  }
}
