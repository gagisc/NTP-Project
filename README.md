# NTP Server for pool.ntp.org

A production-ready NTP server deployment for joining the [pool.ntp.org](https://www.ntppool.org/) network. This project provides infrastructure-as-code for deploying Chrony NTP servers on **AWS EKS** and **GCP GKE** with automatic scaling, static IP addresses, and full compliance with pool.ntp.org requirements.

## Features

- **Pool.ntp.org Compliant**: Follows all [guidelines](https://www.ntppool.org/join.html) for joining the NTP pool
- **Multi-Cloud**: Supports both AWS and GCP deployments
- **Auto-Scaling**: Horizontal Pod Autoscaler (HPA) for handling traffic spikes
- **Static IPs**: Elastic IP (AWS) / Static External IP (GCP) for pool registration
- **Infrastructure as Code**: Complete Terraform modules for reproducible deployments
- **Kubernetes Native**: Kustomize-based deployments with cloud-specific overlays

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │              pool.ntp.org                    │
                    │         (DNS load balancing)                 │
                    └──────────────┬──────────────────────────────┘
                                   │
              ┌────────────────────┴────────────────────┐
              │                                         │
              ▼                                         ▼
    ┌─────────────────────┐               ┌─────────────────────┐
    │   AWS us-east-1     │               │  GCP us-central1    │
    │                     │               │                     │
    │  ┌───────────────┐  │               │  ┌───────────────┐  │
    │  │  Elastic IP   │  │               │  │  Static IP    │  │
    │  └───────┬───────┘  │               │  └───────┬───────┘  │
    │          │          │               │          │          │
    │  ┌───────▼───────┐  │               │  ┌───────▼───────┐  │
    │  │      NLB      │  │               │  │   NLB (L4)    │  │
    │  │   (UDP:123)   │  │               │  │   (UDP:123)   │  │
    │  └───────┬───────┘  │               │  └───────┬───────┘  │
    │          │          │               │          │          │
    │  ┌───────▼───────┐  │               │  ┌───────▼───────┐  │
    │  │  EKS Cluster  │  │               │  │  GKE Cluster  │  │
    │  │ ┌───────────┐ │  │               │  │ ┌───────────┐ │  │
    │  │ │Chrony Pods│ │  │               │  │ │Chrony Pods│ │  │
    │  │ │  (HPA)    │ │  │               │  │ │  (HPA)    │ │  │
    │  │ └───────────┘ │  │               │  │ └───────────┘ │  │
    │  └───────────────┘  │               │  └───────────────┘  │
    └─────────────────────┘               └─────────────────────┘
              │                                         │
              └──────────────────┬──────────────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────────────────────────┐
                    │         Upstream Stratum 1/2 Servers         │
                    │  time.nist.gov, tick.usno.navy.mil, etc.    │
                    └─────────────────────────────────────────────┘
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Docker](https://www.docker.com/get-started)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Kustomize](https://kustomize.io/) (or kubectl with built-in kustomize)
- **AWS**: [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- **GCP**: [gcloud CLI](https://cloud.google.com/sdk/gcloud) configured with appropriate project

## Quick Start

### AWS Deployment

```bash
# 1. Configure AWS credentials
aws configure

# 2. Edit Terraform variables
cd terraform/environments/aws-us-east-1
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Run deployment script
cd ../../../scripts
chmod +x deploy-aws.sh
./deploy-aws.sh
```

### GCP Deployment

```bash
# 1. Configure GCP credentials
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# 2. Edit Terraform variables
cd terraform/environments/gcp-us-central1
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project ID

# 3. Run deployment script
cd ../../../scripts
chmod +x deploy-gcp.sh
./deploy-gcp.sh
```

## Manual Deployment Steps

### Step 1: Deploy Infrastructure with Terraform

```bash
# AWS
cd terraform/environments/aws-us-east-1
terraform init
terraform apply

# GCP
cd terraform/environments/gcp-us-central1
terraform init
terraform apply
```

### Step 2: Build and Push Docker Image

```bash
cd docker

# AWS ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker build -t ntp-server .
docker tag ntp-server:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/ntp-server:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/ntp-server:latest

# GCP Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev
docker build -t ntp-server .
docker tag ntp-server:latest us-central1-docker.pkg.dev/<project-id>/ntp-server/ntp-server:latest
docker push us-central1-docker.pkg.dev/<project-id>/ntp-server/ntp-server:latest
```

### Step 3: Deploy Kubernetes Resources

```bash
# AWS
kubectl apply -k kubernetes/overlays/aws

# GCP
kubectl apply -k kubernetes/overlays/gcp
```

### Step 4: Verify Deployment

```bash
# Check pods
kubectl get pods -n ntp-server

# Check service and get external IP
kubectl get svc -n ntp-server

# Verify Chrony is syncing
kubectl exec -n ntp-server <pod-name> -- chronyc tracking
kubectl exec -n ntp-server <pod-name> -- chronyc sources
```

## pool.ntp.org Registration

After deployment, register your server with pool.ntp.org:

1. **Get your static IP** from Terraform outputs:
   ```bash
   # AWS
   terraform -chdir=terraform/environments/aws-us-east-1 output ntp_static_ip
   
   # GCP
   terraform -chdir=terraform/environments/gcp-us-central1 output ntp_static_ip
   ```

2. **Verify NTP is working**:
   ```bash
   ntpdate -q <your-static-ip>
   ```

3. **Register at**: https://manage.ntppool.org/manage

4. **Monitor your score**: https://www.ntppool.org/scores/<your-static-ip>

## Configuration

### Chrony Configuration

The Chrony configuration follows pool.ntp.org guidelines:

- Uses 5 statically chosen Stratum 1/2 upstream servers
- No `*.pool.ntp.org` aliases as upstream
- No LOCAL clock driver
- `noquery` restriction enabled for security
- Allows NTP queries from all clients

See `docker/chrony.conf` or `kubernetes/base/configmap.yaml` for the full configuration.

### Upstream Servers

Default upstream servers (can be customized in ConfigMap):

| Server | Organization | Location |
|--------|--------------|----------|
| time.nist.gov | NIST | USA |
| time-a-g.nist.gov | NIST | USA |
| time-b-g.nist.gov | NIST | USA |
| tick.usno.navy.mil | US Naval Observatory | USA |
| ptbtime1.ptb.de | PTB | Germany |

### Auto-Scaling

The HPA is configured to handle pool.ntp.org traffic patterns:

- **Normal traffic**: 5-15 packets/sec
- **Traffic spikes**: 60-120 packets/sec
- **Min replicas**: 2 (high availability)
- **Max replicas**: 10

## Project Structure

```
NTP-Project/
├── terraform/
│   ├── modules/
│   │   ├── aws-eks/           # EKS cluster module
│   │   ├── aws-ntp/           # AWS NTP infrastructure
│   │   ├── gcp-gke/           # GKE cluster module
│   │   └── gcp-ntp/           # GCP NTP infrastructure
│   └── environments/
│       ├── aws-us-east-1/     # AWS production environment
│       └── gcp-us-central1/   # GCP production environment
├── kubernetes/
│   ├── base/                  # Kustomize base manifests
│   └── overlays/
│       ├── aws/               # AWS-specific patches
│       └── gcp/               # GCP-specific patches
├── docker/
│   ├── Dockerfile             # Chrony container image
│   └── chrony.conf            # Chrony configuration
└── scripts/
    ├── deploy-aws.sh          # AWS deployment script
    ├── deploy-gcp.sh          # GCP deployment script
    └── verify-ntp.sh          # NTP verification script
```

## Monitoring

### Chrony Status Commands

```bash
# Get pod name
POD=$(kubectl get pods -n ntp-server -l app=ntp-server -o jsonpath='{.items[0].metadata.name}')

# Check tracking status
kubectl exec -n ntp-server $POD -- chronyc tracking

# Check sources
kubectl exec -n ntp-server $POD -- chronyc sources -v

# Check source statistics
kubectl exec -n ntp-server $POD -- chronyc sourcestats
```

### Key Metrics to Monitor

- **Stratum**: Should be 2-4 (depends on upstream servers)
- **Root delay**: Lower is better (< 50ms ideal)
- **Root dispersion**: Lower is better
- **System time offset**: Should be < 1ms
- **Leap status**: Should be "Normal"

## Troubleshooting

### Pod not syncing

```bash
# Check if upstream servers are reachable
kubectl exec -n ntp-server $POD -- chronyc sources

# Check for errors
kubectl logs -n ntp-server $POD
```

### LoadBalancer not getting IP

```bash
# AWS - Check AWS Load Balancer Controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# GCP - Check service events
kubectl describe svc ntp-server -n ntp-server
```

### NTP queries not working

1. Verify security group/firewall allows UDP 123
2. Check that service has external IP
3. Test with: `ntpdate -q <external-ip>`

## Cost Estimates

| Component | AWS (us-east-1) | GCP (us-central1) |
|-----------|-----------------|-------------------|
| EKS/GKE Cluster | ~$73/month | ~$73/month |
| Nodes (2x t3.medium/e2-medium) | ~$60/month | ~$50/month |
| NLB | ~$20/month | ~$20/month |
| NAT Gateway | ~$45/month | ~$30/month |
| **Total** | **~$198/month** | **~$173/month** |

*Estimates based on typical usage patterns. Actual costs may vary.*

## Contributing

Contributions are welcome! Please read the contributing guidelines before submitting PRs.

## License

MIT License - see LICENSE file for details.

## References

- [pool.ntp.org Join Page](https://www.ntppool.org/join.html)
- [pool.ntp.org Configuration Guidelines](https://www.ntppool.org/join/configuration.html)
- [Chrony Documentation](https://chrony.tuxfamily.org/documentation.html)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [GKE LoadBalancer Services](https://cloud.google.com/kubernetes-engine/docs/concepts/service-load-balancer)
