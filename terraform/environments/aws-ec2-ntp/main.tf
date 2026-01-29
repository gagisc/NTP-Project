// AWS EC2-based k3s NTP server for pool.ntp.org
// Lean architecture: single small instance + Elastic IP + k3s (no managed EKS)

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "NTP-Server"
      Environment = "production"
      ManagedBy   = "Terraform"
      Component   = "ec2-ntp"
    }
  }
}

// Security group allowing NTP from the internet
resource "aws_security_group" "ntp" {
  name        = "${var.name}-sg"
  description = "Security group for NTP server"
  vpc_id      = data.aws_vpc.default.id

  // Allow NTP (UDP 123) from anywhere
  ingress {
    description = "NTP UDP"
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Optional TCP 123 (some clients use it)
  ingress {
    description = "NTP TCP (fallback)"
    from_port   = 123
    to_port     = 123
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // SSH from your IP (optional but recommended for maintenance)
  dynamic "ingress" {
    for_each = var.ssh_cidr_blocks
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// Use default VPC and a public subnet (cheap and simple)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "default_public" {
  id = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.default.ids[0]
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

// Elastic IP for static address (required for pool.ntp.org)
resource "aws_eip" "ntp" {
  domain = "vpc"

  tags = {
    Name = "${var.name}-eip"
  }
}

// User data to install k3s and prepare for NTP pod
locals {
  user_data = <<-EOT
    #!/bin/bash
    set -e

    # Disable any default NTP services to free UDP 123 for our pod
    if systemctl is-enabled chronyd >/dev/null 2>&1; then
      systemctl disable --now chronyd || true
    fi
    if systemctl is-enabled systemd-timesyncd >/dev/null 2>&1; then
      systemctl disable --now systemd-timesyncd || true
    fi

    # Install basic tools
    if command -v yum >/dev/null 2>&1; then
      yum update -y
      yum install -y curl
    elif command -v apt-get >/dev/null 2>&1; then
      apt-get update -y
      DEBIAN_FRONTEND=noninteractive apt-get install -y curl
    fi

    # Install k3s server
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --write-kubeconfig-mode 644" sh -

    # k3s kubeconfig will be at /etc/rancher/k3s/k3s.yaml
    # You can copy it locally to use kubectl from your workstation
  EOT
}

// EC2 instance running k3s (and hosting the NTP pod)
resource "aws_instance" "ntp" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet.default_public.id
  vpc_security_group_ids = [aws_security_group.ntp.id]
  associate_public_ip_address = true

  user_data = local.user_data

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = var.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

// Associate Elastic IP with instance
resource "aws_eip_association" "ntp" {
  allocation_id = aws_eip.ntp.id
  instance_id   = aws_instance.ntp.id
}

// Basic CloudWatch monitoring enabled by default (no extra cost)

