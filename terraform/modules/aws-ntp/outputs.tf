# Outputs for AWS NTP Infrastructure Module

output "ntp_eip_id" {
  description = "Elastic IP allocation ID for NTP server"
  value       = aws_eip.ntp.id
}

output "ntp_eip_public_ip" {
  description = "Public IP address of the Elastic IP"
  value       = aws_eip.ntp.public_ip
}

output "ntp_security_group_id" {
  description = "Security group ID for NTP traffic"
  value       = aws_security_group.ntp.id
}

output "kubernetes_service_annotations" {
  description = "Annotations to use for the Kubernetes LoadBalancer service"
  value = {
    "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
    "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
    "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
    "service.beta.kubernetes.io/aws-load-balancer-eip-allocations" = aws_eip.ntp.id
  }
}
