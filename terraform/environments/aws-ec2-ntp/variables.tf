// Variables for AWS EC2 NTP environment

variable "region" {
  description = "AWS region to deploy the NTP server in"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for NTP resources"
  type        = string
  default     = "ntp-ec2-server"
}

variable "instance_type" {
  description = "EC2 instance type (use free-tier eligible where possible)"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID to use for the instance (Amazon Linux 2 or Ubuntu). Leave empty to auto-select latest Amazon Linux 2."
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Optional subnet ID to place the instance in. If empty, the first default VPC subnet is used."
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access. Leave empty to disable SSH key attachment."
  type        = string
  default     = ""
}

variable "ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed to SSH to the instance. Leave empty to disable SSH."
  type        = list(string)
  default     = []
}

