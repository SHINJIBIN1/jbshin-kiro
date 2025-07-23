# Testing the Scalable Terraform Infrastructure

This document provides instructions for testing the scalable Terraform infrastructure, focusing on the small-scale deployment test.

## Prerequisites

Before running the tests, ensure you have the following prerequisites installed:

1. **Terraform** (version 1.0.0 or later)
2. **AWS CLI** (version 2.0.0 or later)
3. **jq** (for JSON parsing)
4. **curl** (for website accessibility testing)

Also, make sure your AWS credentials are properly configured with the necessary permissions to create and manage resources.

## Small-Scale Deployment Test

The small-scale deployment test validates that the infrastructure can be deployed in its minimal configuration, designed for up to 10 concurrent users.

### What the Test Validates

1. **Resource Creation**: Verifies that the correct resources are created for a small-scale deployment:
   - VPC and networking components
   - Single EC2 instance (no Auto Scaling Group)
   - Route53 DNS configuration for www.jbshin.shop
   - Basic CloudWatch monitoring
   - No load balancer (direct EC2 access)

2. **Functional Testing**: Validates that the deployed infrastructure functions correctly:
   - Deployment scale parameter is set to "small"
   - Website is accessible via the configured domain
   - No load balancer or Auto Scaling Group exists (as expected for small scale)
   - Infrastructure diagram is generated
   - Dashboard module is deployed

### Running the Test

To run the small-scale deployment test, use the `test_small_deployment.sh` script:

```bash
# Show help
./test_small_deployment.sh --help

# Plan the deployment (no resources created)
./test_small_deployment.sh

# Apply the deployment and run tests
./test_small_deployment.sh --apply

# Apply the deployment, run tests, and destroy resources afterward
./test_small_deployment.sh --apply --destroy
```

### Test Output

The test script provides detailed output for each validation step, with color-coded results:
- ✓ Green: Test passed
- ⚠ Yellow: Warning or information
- ✗ Red: Test failed

### Important Notes

1. **DNS Propagation**: If the website accessibility test fails, it might be due to DNS propagation delays. This can take up to 48 hours, though it's typically much faster.

2. **Resource Costs**: Running the test creates AWS resources that may incur costs. Always use the `--destroy` flag or manually destroy the resources after testing to avoid unexpected charges.

3. **AWS Region**: The test deploys resources in the us-west-2 region by default. Ensure your AWS credentials have permissions in this region.

4. **Test Duration**: The full test (apply, validate, destroy) typically takes 5-10 minutes to complete.

## Troubleshooting

If you encounter issues during testing:

1. **AWS Credentials**: Ensure your AWS credentials are valid and have the necessary permissions.

2. **Terraform State**: If Terraform state becomes corrupted, you may need to remove the `.terraform` directory and run `terraform init` again.

3. **Resource Limits**: If you hit AWS service limits, you may need to request limit increases or use a different AWS account.

4. **Terraform Version**: Ensure you're using a compatible Terraform version (1.0.0 or later).

## Next Steps

After successfully testing the small-scale deployment, you can proceed to test the medium and large-scale deployments using similar scripts (to be implemented in future tasks).