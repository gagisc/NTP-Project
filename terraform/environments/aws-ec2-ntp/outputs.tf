// Outputs for AWS EC2 NTP environment

output "ntp_instance_id" {
  description = "ID of the NTP EC2 instance"
  value       = aws_instance.ntp.id
}

output "ntp_public_ip" {
  description = "Public IP address of the NTP server (Elastic IP)"
  value       = aws_eip.ntp.public_ip
}

output "ntp_public_dns" {
  description = "Public DNS name of the NTP server"
  value       = aws_instance.ntp.public_dns
}

output "security_group_id" {
  description = "Security group ID used for the NTP server"
  value       = aws_security_group.ntp.id
}

output "pool_ntp_org_registration" {
  description = "Instructions for registering this server with pool.ntp.org"
  value       = <<-EOT

    ============================================
    pool.ntp.org Registration Information (AWS EC2)
    ============================================

    Static IP Address: ${aws_eip.ntp.public_ip}

    After the instance is up:
    1. SSH into the instance (if enabled) and verify Chrony:
       chronyc tracking
       chronyc sources

    2. From another machine, test NTP:
       ntpdate -q ${aws_eip.ntp.public_ip}

    3. Register at: https://manage.ntppool.org/manage
       Add your server IP: ${aws_eip.ntp.public_ip}

  EOT
}

