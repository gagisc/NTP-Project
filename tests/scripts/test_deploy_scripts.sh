#!/bin/bash
# Unit tests for deployment scripts using bats-core (or plain bash assertions)
# Run: bash tests/scripts/test_deploy_scripts.sh
# Requires: shellcheck, bash 4+

set -euo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_contains() {
  local label="$1" needle="$2" file="$3"
  if grep -q "$needle" "$file"; then
    pass "$label"
  else
    fail "$label — '$needle' not found in $file"
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" file="$3"
  if ! grep -q "$needle" "$file"; then
    pass "$label"
  else
    fail "$label — '$needle' should NOT be in $file"
  fi
}

assert_file_exists() {
  local label="$1" file="$2"
  if [ -f "$file" ]; then
    pass "$label"
  else
    fail "$label — file not found: $file"
  fi
}

echo "============================================"
echo "  Script & Configuration Tests"
echo "============================================"

echo ""
echo "-- deploy-aws.sh --"
AWS_SCRIPT="$REPO_ROOT/scripts/deploy-aws.sh"
assert_file_exists "deploy-aws.sh exists" "$AWS_SCRIPT"
assert_contains "set -e is present" "set -e" "$AWS_SCRIPT"
assert_not_contains "sed -i on kustomization.yaml (tracked file)" \
  'sed -i.*kustomization.yaml"$' "$AWS_SCRIPT"
assert_contains "Uses mktemp for temp overlay" "mktemp -d" "$AWS_SCRIPT"
assert_contains "Cleans up temp dir with trap" 'trap.*rm -rf' "$AWS_SCRIPT"
assert_contains "LB wait has a timeout counter" "LB_TIMEOUT" "$AWS_SCRIPT"
assert_contains "region from terraform output (not hardcoded)" \
  'terraform output -raw region' "$AWS_SCRIPT"

echo ""
echo "-- deploy-gcp.sh --"
GCP_SCRIPT="$REPO_ROOT/scripts/deploy-gcp.sh"
assert_file_exists "deploy-gcp.sh exists" "$GCP_SCRIPT"
assert_contains "set -e is present" "set -e" "$GCP_SCRIPT"
assert_not_contains "sed -i on kustomization.yaml (tracked file)" \
  'sed -i.*kustomization.yaml"$' "$GCP_SCRIPT"
assert_contains "Uses mktemp for temp overlay" "mktemp -d" "$GCP_SCRIPT"
assert_contains "Cleans up temp dir with trap" 'trap.*rm -rf' "$GCP_SCRIPT"
assert_contains "LB wait has a timeout counter" "LB_TIMEOUT" "$GCP_SCRIPT"

echo ""
echo "-- verify-ntp.sh --"
VERIFY_SCRIPT="$REPO_ROOT/scripts/verify-ntp.sh"
assert_file_exists "verify-ntp.sh exists" "$VERIFY_SCRIPT"
assert_contains "set -e is present" "set -e" "$VERIFY_SCRIPT"
assert_contains "Accepts NTP_IP from arg or env" "NTP_SERVER_IP" "$VERIFY_SCRIPT"

echo ""
echo "============================================"
echo "  Dockerfile Tests"
echo "============================================"
DOCKERFILE="$REPO_ROOT/docker/Dockerfile"
assert_file_exists "Dockerfile exists" "$DOCKERFILE"
assert_contains "Uses Alpine base" "FROM alpine:" "$DOCKERFILE"
assert_contains "Installs chrony" "chrony" "$DOCKERFILE"
assert_contains "Exposes UDP 123" "EXPOSE 123/udp" "$DOCKERFILE"
assert_contains "Has HEALTHCHECK" "HEALTHCHECK" "$DOCKERFILE"
assert_contains "Entrypoint is chronyd" "chronyd" "$DOCKERFILE"

echo ""
echo "============================================"
echo "  Kubernetes Manifest Tests"
echo "============================================"
DEPLOY_YAML="$REPO_ROOT/kubernetes/base/deployment.yaml"
assert_file_exists "deployment.yaml exists" "$DEPLOY_YAML"
assert_contains "hostNetwork enabled" "hostNetwork: true" "$DEPLOY_YAML"
assert_contains "dnsPolicy is ClusterFirstWithHostNet" "ClusterFirstWithHostNet" "$DEPLOY_YAML"
assert_not_contains "No conflicting ClusterFirst dnsPolicy" "dnsPolicy: ClusterFirst$" "$DEPLOY_YAML"
assert_contains "SYS_TIME capability" "SYS_TIME" "$DEPLOY_YAML"
assert_contains "readinessProbe defined" "readinessProbe" "$DEPLOY_YAML"
assert_contains "livenessProbe defined" "livenessProbe" "$DEPLOY_YAML"
assert_contains "resource limits defined" "limits:" "$DEPLOY_YAML"
assert_contains "podAntiAffinity defined" "podAntiAffinity" "$DEPLOY_YAML"

HPA_YAML="$REPO_ROOT/kubernetes/base/hpa.yaml"
assert_file_exists "hpa.yaml exists" "$HPA_YAML"
assert_contains "autoscaling/v2 API version" "autoscaling/v2" "$HPA_YAML"
assert_contains "minReplicas >= 2" "minReplicas: 2" "$HPA_YAML"

PDB_YAML="$REPO_ROOT/kubernetes/base/pdb.yaml"
assert_file_exists "pdb.yaml exists" "$PDB_YAML"
assert_contains "policy/v1 API version" "policy/v1" "$PDB_YAML"
assert_contains "minAvailable set" "minAvailable:" "$PDB_YAML"

CONFIGMAP_YAML="$REPO_ROOT/kubernetes/base/configmap.yaml"
assert_file_exists "configmap.yaml exists" "$CONFIGMAP_YAML"
assert_contains "allow all for NTP clients" "allow all" "$CONFIGMAP_YAML"
assert_not_contains "No pool.ntp.org aliases as upstream" "pool.ntp.org" "$CONFIGMAP_YAML"
assert_contains "minsources set" "minsources" "$CONFIGMAP_YAML"

echo ""
echo "============================================"
echo "  Terraform Structure Tests"
echo "============================================"
for env in aws-us-east-1 aws-ec2-ntp gcp-us-central1 gcp-k3s-ntp; do
  DIR="$REPO_ROOT/terraform/environments/$env"
  assert_file_exists "$env/main.tf" "$DIR/main.tf"
  assert_file_exists "$env/variables.tf" "$DIR/variables.tf"
  assert_file_exists "$env/outputs.tf" "$DIR/outputs.tf"
  assert_file_exists "$env/terraform.tfvars.example" "$DIR/terraform.tfvars.example"
  assert_contains "$env required_version >= 1.3" '>= 1.3' "$DIR/main.tf"
done

for mod in aws-eks aws-ntp gcp-gke gcp-ntp; do
  DIR="$REPO_ROOT/terraform/modules/$mod"
  assert_file_exists "$mod/main.tf" "$DIR/main.tf"
  assert_file_exists "$mod/variables.tf" "$DIR/variables.tf"
  assert_file_exists "$mod/outputs.tf" "$DIR/outputs.tf"
  assert_contains "$mod required_version >= 1.0" '>= 1.' "$DIR/main.tf"
done

echo ""
echo "============================================"
echo "  aws-ec2-ntp AMI Fallback Test"
echo "============================================"
EC2_MAIN="$REPO_ROOT/terraform/environments/aws-ec2-ntp/main.tf"
assert_contains "al2023 data source defined" 'data "aws_ami" "al2023"' "$EC2_MAIN"
assert_contains "local.resolved_ami used" "local.resolved_ami" "$EC2_MAIN"
assert_contains "key_name supported" "var.key_name" "$EC2_MAIN"

echo ""
echo "============================================"
echo "  GCP k3s Firewall Isolation Test"
echo "============================================"
GCP_K3S_MAIN="$REPO_ROOT/terraform/environments/gcp-k3s-ntp/main.tf"
assert_not_contains "No merged source_ranges with 0.0.0.0/0 + SSH CIDRs" \
  'source_ranges = concat' "$GCP_K3S_MAIN"
assert_contains "Separate SSH firewall resource" 'google_compute_firewall" "ssh"' "$GCP_K3S_MAIN"
assert_contains "Separate k3s API firewall resource" 'google_compute_firewall" "k3s_api"' "$GCP_K3S_MAIN"
assert_contains "count-gated SSH rule" 'count.*ssh_cidr_blocks' "$GCP_K3S_MAIN"

echo ""
echo "============================================"
echo "  CI/CD Workflow Tests"
echo "============================================"
for wf in ci deploy-aws deploy-gcp; do
  assert_file_exists ".github/workflows/$wf.yml" \
    "$REPO_ROOT/.github/workflows/$wf.yml"
done
assert_contains "ci.yml: docker build job" "docker-build" \
  "$REPO_ROOT/.github/workflows/ci.yml"
assert_contains "ci.yml: k8s-validate job" "k8s-validate" \
  "$REPO_ROOT/.github/workflows/ci.yml"
assert_contains "ci.yml: terraform-validate job" "terraform-validate" \
  "$REPO_ROOT/.github/workflows/ci.yml"
assert_contains "ci.yml: shellcheck job" "shellcheck" \
  "$REPO_ROOT/.github/workflows/ci.yml"
assert_contains "deploy-aws.yml: OIDC auth" "id-token: write" \
  "$REPO_ROOT/.github/workflows/deploy-aws.yml"
assert_contains "deploy-gcp.yml: OIDC auth" "id-token: write" \
  "$REPO_ROOT/.github/workflows/deploy-gcp.yml"

echo ""
echo "============================================"
echo "  Results"
echo "============================================"
echo "  PASSED: $PASS"
echo "  FAILED: $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "SOME TESTS FAILED"
  exit 1
else
  echo "ALL TESTS PASSED"
fi
