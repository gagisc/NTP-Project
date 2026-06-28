// Terratest unit tests for the gcp-ntp Terraform module.
// Run: cd tests/terraform && go test -v -run TestGcpNtpModule -timeout 5m
package terraform_test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestGcpNtpModuleValidate(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../terraform/modules/gcp-ntp",
		Vars: map[string]interface{}{
			"project_id":   "my-test-project",
			"cluster_name": "test-ntp-cluster",
			"region":       "us-central1",
			"vpc_name":     "test-ntp-cluster-vpc",
		},
		NoColor: true,
	}

	terraform.InitAndValidate(t, terraformOptions)
	assert.True(t, true, "gcp-ntp module structure is valid")
}

func TestGcpGkeModuleValidate(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../terraform/modules/gcp-gke",
		Vars: map[string]interface{}{
			"project_id":   "my-test-project",
			"cluster_name": "test-ntp-cluster",
			"region":       "us-central1",
		},
		NoColor: true,
	}

	terraform.InitAndValidate(t, terraformOptions)
	assert.True(t, true, "gcp-gke module structure is valid")
}

func TestAwsEksModuleValidate(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../terraform/modules/aws-eks",
		Vars: map[string]interface{}{
			"cluster_name": "test-ntp-cluster",
		},
		NoColor: true,
	}

	terraform.InitAndValidate(t, terraformOptions)
	assert.True(t, true, "aws-eks module structure is valid")
}
