// Outputs for GCP k3s NTP environment

output "ntp_instance_name" {
  description = "Name of the NTP k3s instance"
  value       = google_compute_instance.ntp.name
}

output "ntp_public_ip" {
  description = "Static public IP address of the NTP server"
  value       = google_compute_address.ntp.address
}

output "pool_ntp_org_registration" {
  description = "Instructions for registering this server with pool.ntp.org"
  value       = <<-EOT

    ============================================
    pool.ntp.org Registration Information (GCP k3s)
    ============================================

    Static IP Address: ${google_compute_address.ntp.address}

    After the instance is up:
    1. SSH into the instance (if enabled) and copy kubeconfig:
       sudo cat /etc/rancher/k3s/k3s.yaml
       # copy to your local machine and update server IP to https://${google_compute_address.ntp.address}:6443 if you expose the API

    2. Use kubectl against the k3s cluster and deploy manifests:
       kubectl get nodes
       kubectl apply -k kubernetes/base

    3. From another machine, test NTP:
       ntpdate -q ${google_compute_address.ntp.address}

    4. Register at: https://manage.ntppool.org/manage
       Add your server IP: ${google_compute_address.ntp.address}

  EOT
}

