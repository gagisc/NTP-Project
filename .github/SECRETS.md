# GitHub Secrets & Environments Setup

All CI/CD workflows authenticate via **OIDC** (no long-lived credentials stored).
Configure secrets at **Settings → Secrets and variables → Actions** and create a
**`production` environment** at **Settings → Environments**.

---

## 1. Create the `production` Environment

1. Go to **Settings → Environments → New environment**
2. Name it `production`
3. Add required reviewers if you want manual approval before apply/destroy
4. The deploy workflows reference this environment to gate sensitive jobs

---

## 2. AWS Secrets

### OIDC trust (preferred — no static keys)

```bash
# One-time setup: create an IAM OIDC provider for GitHub Actions
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create an IAM role with the trust policy below and attach AdministratorAccess
# (or a scoped policy covering EKS, EC2, ECR, IAM, S3, DynamoDB)
```

Trust policy for the IAM role (`oidc-trust.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
      }
    }
  }]
}
```

| Secret name            | Value                                                         |
|------------------------|---------------------------------------------------------------|
| `AWS_OIDC_ROLE_ARN`    | `arn:aws:iam::123456789012:role/github-actions-ntp`           |
| `AWS_REGION`           | `us-east-1`                                                   |
| `AWS_ACCOUNT_ID`       | `123456789012`                                                |
| `AWS_CLUSTER_NAME`     | `ntp-server-cluster` (matches `cluster_name` in tfvars)       |
| `TF_STATE_BUCKET_AWS`  | S3 bucket name for Terraform remote state                     |
| `TF_LOCK_TABLE_AWS`    | DynamoDB table name for state locking                         |

### Create the S3 backend resources

```bash
# S3 bucket for state
aws s3api create-bucket \
  --bucket my-ntp-tf-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket my-ntp-tf-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket my-ntp-tf-state \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# DynamoDB table for locking
aws dynamodb create-table \
  --table-name my-ntp-tf-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Enable the S3 backend in Terraform

Uncomment the `backend "s3"` block in
`terraform/environments/aws-us-east-1/main.tf` and fill in your bucket/table names.

---

## 3. GCP Secrets

### Workload Identity Federation (preferred — no service account keys)

```bash
# Create a Workload Identity Pool
gcloud iam workload-identity-pools create github-pool \
  --location=global \
  --display-name="GitHub Actions Pool"

# Create an OIDC provider inside the pool
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location=global \
  --workload-identity-pool=github-pool \
  --display-name="GitHub OIDC" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Create a service account for Terraform/deployments
gcloud iam service-accounts create github-actions-ntp \
  --display-name="GitHub Actions NTP deployer"

# Grant the SA permissions (adjust to least-privilege for production)
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:github-actions-ntp@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/editor"

# Allow the WIF pool to impersonate the SA (scope to your repo)
gcloud iam service-accounts add-iam-policy-binding \
  github-actions-ntp@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_ORG/YOUR_REPO"
```

| Secret name                      | Value                                                                                           |
|----------------------------------|-------------------------------------------------------------------------------------------------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `GCP_SERVICE_ACCOUNT`            | `github-actions-ntp@YOUR_PROJECT_ID.iam.gserviceaccount.com`                                   |
| `GCP_PROJECT_ID`                 | `your-gcp-project-id`                                                                           |
| `GCP_REGION`                     | `us-central1`                                                                                   |
| `GCP_CLUSTER_NAME`               | `ntp-server-cluster`                                                                            |
| `TF_STATE_BUCKET_GCP`            | GCS bucket name for Terraform remote state                                                      |

### Create the GCS backend bucket

```bash
gsutil mb -p YOUR_PROJECT_ID -l us-central1 gs://my-ntp-tf-state/
gsutil versioning set on gs://my-ntp-tf-state/
```

### Enable the GCS backend in Terraform

Uncomment the `backend "gcs"` block in
`terraform/environments/gcp-us-central1/main.tf` and fill in your bucket name.

---

## 4. Quick Reference — All Secrets

| Secret                           | Used by                          |
|----------------------------------|----------------------------------|
| `AWS_OIDC_ROLE_ARN`              | deploy-aws.yml                   |
| `AWS_REGION`                     | deploy-aws.yml                   |
| `AWS_ACCOUNT_ID`                 | deploy-aws.yml (k8s deploy step) |
| `AWS_CLUSTER_NAME`               | deploy-aws.yml                   |
| `TF_STATE_BUCKET_AWS`            | deploy-aws.yml (terraform init)  |
| `TF_LOCK_TABLE_AWS`              | deploy-aws.yml (terraform init)  |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | deploy-gcp.yml                   |
| `GCP_SERVICE_ACCOUNT`            | deploy-gcp.yml                   |
| `GCP_PROJECT_ID`                 | deploy-gcp.yml                   |
| `GCP_REGION`                     | deploy-gcp.yml                   |
| `GCP_CLUSTER_NAME`               | deploy-gcp.yml                   |
| `TF_STATE_BUCKET_GCP`            | deploy-gcp.yml (terraform init)  |

---

## 5. Local Development (no CI)

Copy and fill in the overlay params files before running `kubectl apply -k`:

```bash
# AWS
cp kubernetes/overlays/aws/params.env.example kubernetes/overlays/aws/params.env
# Edit params.env with your ECR_IMAGE and EIP_ALLOCATION_ID

# GCP
cp kubernetes/overlays/gcp/params.env.example kubernetes/overlays/gcp/params.env
# Edit params.env with your AR_IMAGE, STATIC_IP_NAME, GCP_WORKLOAD_SA
```

These files are gitignored and will never be committed.
