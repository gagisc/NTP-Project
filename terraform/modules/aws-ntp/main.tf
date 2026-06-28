# AWS NTP Infrastructure Module
# This module creates Elastic IP, security groups, and NLB-related resources

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Elastic IP for NTP Server (static IP for pool.ntp.org)
resource "aws_eip" "ntp" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name                                        = "${var.cluster_name}-ntp-eip"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# Security Group for NTP Traffic
resource "aws_security_group" "ntp" {
  name        = "${var.cluster_name}-ntp-sg"
  description = "Security group for NTP server traffic"
  vpc_id      = var.vpc_id

  # Allow NTP (UDP 123) from anywhere
  ingress {
    description = "NTP UDP traffic"
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow NTP (TCP 123) for fallback (rare but some clients use it)
  ingress {
    description = "NTP TCP traffic (fallback)"
    from_port   = 123
    to_port     = 123
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic (for upstream NTP servers)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-ntp-sg"
  })
}

# Additional security group rules for NTP to EKS nodes
resource "aws_security_group_rule" "eks_ntp_ingress" {
  type                     = "ingress"
  from_port                = 123
  to_port                  = 123
  protocol                 = "udp"
  security_group_id        = var.cluster_security_group_id
  source_security_group_id = aws_security_group.ntp.id
  description              = "Allow NTP traffic from NLB security group"
}
