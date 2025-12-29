# AWS Cloud WAN + Transit Gateway Deployment Guide

## Overview

This Terraform codebase deploys a production-ready AWS Cloud WAN + Transit Gateway architecture with:
- Multi-account segmentation (Production, Non-Production, Shared Services)
- Centralized egress via Network Firewall and GWLB
- Complete network isolation between Production and Non-Production
- Shared Services accessible to all segments

## Architecture Components

### Core Infrastructure (Created)
✅ **versions.tf** - Terraform and provider configuration  
✅ **variables.tf** - All configurable variables  
✅ **terraform.tfvars.example** - Example configuration  
✅ **main.tf** - Core infrastructure (Cloud WAN, TGW, VPCs, routing)  
✅ **outputs.tf** - Comprehensive outputs and validation checks  

### Modules (Need to be Created)

The following modules are referenced in main.tf and need to be created:

#### 1. `modules/vpc/` - Standard VPC Module
Creates spoke VPCs (Production, Non-Production, Shared Services) with:
- Private subnets for workloads
- TGW subnets for Transit Gateway attachments
- VPC Flow Logs
- Route tables configured for centralized egress

**Files needed:**
- `modules/vpc/main.tf`
- `modules/vpc/variables.tf`
- `modules/vpc/outputs.tf`

#### 2. `modules/egress-vpc/` - Egress VPC Module
Creates the centralized egress VPC with:
- Public subnets (NAT Gateways, IGW)
- Firewall subnets (Network Firewall endpoints)
- TGW subnets
- AWS Network Firewall with domain/IP filtering
- Gateway Load Balancer (GWLB)
- NAT Gateways
- Complex routing for traffic flow

**Files needed:**
- `modules/egress-vpc/main.tf`
- `modules/egress-vpc/variables.tf`
- `modules/egress-vpc/outputs.tf`

## Quick Start

### Prerequisites

1. **AWS Accounts Setup**
   ```bash
   # You need 4 AWS accounts:
   - Network Hub: 111111111111 (replace with actual)
   - Production: 222222222222 (replace with actual)
   - Non-Production: 333333333333 (replace with actual)
   - Shared Services: 444444444444 (replace with actual)
   ```

2. **IAM Roles**
   Create `TerraformExecutionRole` in each account with permissions for:
   - VPC, Subnet, Route Table management
   - Transit Gateway operations
   - Network Firewall operations
   - CloudWatch Logs
   - RAM (Resource Access Manager)

3. **AWS CLI Configuration**
   ```bash
   # Configure profiles for each account
   aws configure --profile network-hub
   aws configure --profile production
   aws configure --profile non-production
   aws configure --profile shared-services
   ```

### Step 1: Configure Variables

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

Update these critical values:
```hcl
network_hub_account_id     = "YOUR_NETWORK_HUB_ACCOUNT"
production_account_id      = "YOUR_PRODUCTION_ACCOUNT"
non_production_account_id  = "YOUR_NON_PROD_ACCOUNT"
shared_services_account_id = "YOUR_SHARED_SERVICES_ACCOUNT"
organization_id            = "YOUR_ORG_ID"

aws_region = "us-east-1"  # or your preferred region
```

### Step 2: Create Terraform Modules

Before running terraform init, you need to create the VPC modules. Here's a simplified approach:

#### Option A: Use AWS VPC Module (Recommended for Quick Start)

Modify `main.tf` to use the official AWS VPC module:

```hcl
# Replace module "production_vpc" with:
module "production_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.production
  }

  name = "${var.name_prefix}-prod-vpc"
  cidr = var.prod_vpc_cidr

  azs             = var.availability_zones
  private_subnets = local.prod_subnets.private
  
  # TGW subnets
  intra_subnets = local.prod_subnets.tgw

  enable_nat_gateway = false  # No NAT in spoke VPCs
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_log                      = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_retention_in_days           = var.flow_logs_retention_days

  tags = merge(local.common_tags, {
    Segment = "production"
  })
}
```

#### Option B: Create Custom Modules

I can create the complete custom modules for you. Would you like me to:
1. Create the `modules/vpc/` module
2. Create the `modules/egress-vpc/` module with Network Firewall and GWLB

### Step 3: Initialize Terraform

```bash
terraform init
```

### Step 4: Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the plan carefully. Expected resources:
- 1 Cloud WAN Global Network
- 1 Cloud WAN Core Network
- 1 Transit Gateway
- 4 Transit Gateway Route Tables
- 4 VPCs
- 4 Transit Gateway VPC Attachments
- 1 Network Firewall
- 1 Gateway Load Balancer
- 2 NAT Gateways (if multi-AZ)
- Multiple subnets, route tables, security groups
- CloudWatch Log Groups
- RAM Resource Shares

### Step 5: Deploy Infrastructure

```bash
terraform apply tfplan
```

Deployment time: **30-45 minutes**

### Step 6: Verify Deployment

```bash
# Check outputs
terraform output

# Verify TGW attachments
terraform output tgw_attachment_ids

# Check Network Firewall status
terraform output network_firewall_status

# View validation checks
terraform output validation_checks
```

## Post-Deployment Validation

### 1. Test Network Segmentation

```bash
# Deploy test EC2 instances in each VPC
# Production VPC: 10.1.1.10
# Non-Production VPC: 10.2.1.10
# Shared Services VPC: 10.3.1.10

# From Production instance:
ping 10.2.1.10  # Should FAIL (isolated)
ping 10.3.1.10  # Should SUCCEED (shared services)
curl https://www.google.com  # Should SUCCEED (via egress VPC)

# From Non-Production instance:
ping 10.1.1.10  # Should FAIL (isolated)
ping 10.3.1.10  # Should SUCCEED (shared services)
```

### 2. Verify Centralized Egress

```bash
# From any spoke VPC instance:
curl https://malware.com  # Should be BLOCKED by firewall
curl https://www.github.com  # Should be ALLOWED

# Check Network Firewall logs:
aws logs tail /aws/networkfirewall/egress-firewall-alert --follow
aws logs tail /aws/networkfirewall/egress-firewall-flow --follow
```

### 3. Verify No Direct IGW

```bash
# Check Production VPC
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$(terraform output -raw production_vpc_id)"
# Should return empty (no IGW)

# Check Non-Production VPC
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$(terraform output -raw non_production_vpc_id)"
# Should return empty (no IGW)
```

### 4. Check Transit Gateway Routes

```bash
# Production TGW Route Table
aws ec2 describe-transit-gateway-route-tables \
  --transit-gateway-route-table-ids $(terraform output -json transit_gateway_route_table_ids | jq -r '.production')

# Should show:
# - 0.0.0.0/0 → Egress VPC attachment
# - 10.3.0.0/16 → Shared Services VPC attachment
# - NO route to 10.2.0.0/16 (Non-Prod isolated)
```

## Troubleshooting

### Issue: TGW Attachment Stuck in "Pending"

**Solution:**
```bash
# Check RAM resource share status
aws ram get-resource-shares --resource-owner SELF

# Accept resource share in spoke accounts
aws ram accept-resource-share-invitation \
  --resource-share-invitation-arn <invitation-arn> \
  --profile production
```

### Issue: No Internet Access from Spoke VPCs

**Solution:**
```bash
# 1. Check route tables in spoke VPCs
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<vpc-id>"
# Should have 0.0.0.0/0 → TGW

# 2. Check TGW route table
# Should have 0.0.0.0/0 → Egress VPC attachment

# 3. Check NAT Gateway status
aws ec2 describe-nat-gateways
# Should be "available"

# 4. Check Network Firewall status
aws network-firewall describe-firewall --firewall-name egress-firewall
# Should be "READY"
```

### Issue: Network Firewall Blocking Legitimate Traffic

**Solution:**
```bash
# 1. Check firewall logs
aws logs tail /aws/networkfirewall/egress-firewall-alert --follow

# 2. Update allowed domains in terraform.tfvars
allowed_domains = [
  "*.amazonaws.com",
  "*.your-domain.com"  # Add your domain
]

# 3. Apply changes
terraform apply
```

## Cost Optimization

### Current Configuration (Multi-AZ HA)
- Transit Gateway: ~$36/month
- TGW Attachments (4): ~$144/month
- Cloud WAN: ~$200/month
- Network Firewall: ~$395/month
- NAT Gateways (2): ~$65/month
- GWLB: ~$22/month
- **Total: ~$862/month** (excluding data transfer)

### Cost-Optimized Configuration
```hcl
# In terraform.tfvars:
enable_multi_az = false
single_nat_gateway = true
```
**Savings: ~$32/month** (single NAT Gateway)

## Security Best Practices

1. **Least Privilege IAM**
   - Use minimal IAM permissions for Terraform execution
   - Implement IAM policies with conditions

2. **Network Segmentation**
   - Keep Production and Non-Production isolated
   - Use security groups for additional layer of defense

3. **Logging**
   - Enable all VPC Flow Logs
   - Enable Network Firewall logs (alert + flow)
   - Set appropriate retention periods

4. **Firewall Rules**
   - Regularly review and update blocked/allowed domains
   - Implement deny-by-default policy
   - Use Suricata-compatible IPS rules

5. **Monitoring**
   - Set up CloudWatch alarms for:
     - TGW attachment state changes
     - Network Firewall packet drops
     - NAT Gateway errors
     - Unusual traffic patterns

## Maintenance

### Regular Tasks

**Weekly:**
- Review Network Firewall logs
- Check CloudWatch alarms
- Verify TGW attachment health

**Monthly:**
- Update firewall rules
- Review cost optimization opportunities
- Update Terraform modules

**Quarterly:**
- Conduct disaster recovery drills
- Review and update documentation
- Perform security audit

### Updating Infrastructure

```bash
# 1. Update terraform.tfvars or module code
vim terraform.tfvars

# 2. Plan changes
terraform plan

# 3. Review changes carefully
# 4. Apply updates
terraform apply

# 5. Verify no service disruption
# Monitor CloudWatch dashboards
```

## Disaster Recovery

### Backup Strategy
- Terraform state: S3 with versioning
- Configuration: Git version control
- Network Firewall rules: Exported daily
- Route tables: Automated snapshots

### Recovery Procedures

**Scenario: TGW Failure**
```bash
# TGW is highly available (multi-AZ)
# If complete failure:
terraform taint aws_ec2_transit_gateway.main
terraform apply
# RTO: 30 minutes, RPO: 0
```

**Scenario: Network Firewall Failure**
```bash
# Firewall is multi-AZ by default
# Automatic failover to healthy AZ
# RTO: < 1 minute, RPO: 0
```

## Next Steps

1. **Create the VPC Modules** (see Option A or B above)
2. **Deploy the Infrastructure** (follow steps 1-6)
3. **Validate Deployment** (run all validation checks)
4. **Deploy Workloads** (EC2, ECS, EKS, etc.)
5. **Configure Monitoring** (CloudWatch dashboards, alarms)
6. **Document Custom Configurations**

## Support

For issues or questions:
- Review this deployment guide
- Check AWS documentation
- Review Terraform AWS provider docs
- Open an issue in the repository

## OPTIONAL: PCI Compliance with Service Control Policies

The codebase includes an **optional** `scp.tf` file for PCI-DSS compliance using AWS Organizations Service Control Policies.

### What Are SCPs?

Service Control Policies (SCPs) are organization-level policies that enforce compliance requirements across all accounts in an Organizational Unit (OU). They cannot be bypassed, even by the root user.

### What's Included

The `scp.tf` file implements **10 comprehensive SCPs**:

1. **Region Restriction** - Only allows approved regions (us-east-1, us-west-2, eu-west-1)
2. **Service Disallowance** - Blocks 13+ non-approved services
3. **Public S3 Prevention** - No public buckets, ACLs, or policies allowed
4. **Public Networking Block** - Prevents IGW, NAT, EIP, public subnets
5. **Encryption Enforcement** - All storage must be encrypted (S3, EBS, RDS, EFS, DynamoDB)
6. **Mandatory Flow Logs** - VPC Flow Logs cannot be disabled
7. **Instance Type Allowlist** - Only approved EC2 instance types
8. **Security Control Protection** - CloudTrail, Config, GuardDuty cannot be disabled
9. **MFA Requirement** - MFA required for sensitive operations
10. **Root User Restriction** - Root user blocked from most actions

### Deploying SCPs (Optional)

#### Step 1: Review and Customize

```bash
# Edit the SCP configuration
vim scp.tf

# Customize the locals block:
locals {
  # Add/remove approved regions
  approved_regions = [
    "us-east-1",
    "us-west-2",
    "eu-west-1"
  ]

  # Add/remove approved instance types
  approved_instance_types = [
    "t3.medium",
    "t3.large",
    "m5.large",
    # Add more as needed
  ]

  # Add/remove disallowed services
  disallowed_services = [
    "lightsail",
    "gamelift",
    # Add more as needed
  ]
}
```

#### Step 2: Deploy SCPs

```bash
# Initialize (if not already done)
terraform init

# Plan to see what will be created
terraform plan

# Apply to create PCI OU and SCPs
terraform apply
```

This creates:
- 1 PCI Organizational Unit
- 10 Service Control Policies
- 10 Policy attachments to the PCI OU

#### Step 3: Move Accounts to PCI OU

```bash
# Get the PCI OU ID
PCI_OU_ID=$(terraform output -raw pci_ou_id)

# Move account to PCI OU
aws organizations move-account \
  --account-id YOUR_ACCOUNT_ID \
  --source-parent-id CURRENT_PARENT_ID \
  --destination-parent-id $PCI_OU_ID
```

#### Step 4: Verify SCP Enforcement

```bash
# View SCP summary
terraform output scp_summary

# View all SCP policy IDs
terraform output scp_policies

# View approved regions
terraform output approved_regions

# View approved instance types
terraform output approved_instance_types
```

### Testing SCP Enforcement

Try these commands in a PCI OU account (they should all fail):

```bash
# Test 1: Unapproved region (should FAIL)
aws ec2 describe-instances --region ap-south-1
# Expected: Access Denied

# Test 2: Public S3 bucket (should FAIL)
aws s3api create-bucket --bucket test-public --acl public-read
# Expected: Access Denied

# Test 3: Create Internet Gateway (should FAIL)
aws ec2 create-internet-gateway
# Expected: Access Denied

# Test 4: Unapproved instance type (should FAIL)
aws ec2 run-instances \
  --instance-type t2.micro \
  --image-id ami-0c55b159cbfafe1f0
# Expected: Access Denied

# Test 5: Unencrypted EBS volume (should FAIL)
aws ec2 create-volume \
  --size 10 \
  --availability-zone us-east-1a
# Expected: Access Denied (no encryption specified)

# Test 6: Delete VPC Flow Logs (should FAIL)
aws ec2 delete-flow-logs --flow-log-ids fl-xxxxxxxxx
# Expected: Access Denied
```

### Viewing SCP Violations in CloudTrail

All SCP denies are automatically logged in CloudTrail:

```bash
# Search for SCP denies in CloudTrail
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=Deny \
  --max-results 50 \
  --query 'Events[?contains(CloudTrailEvent, `AccessDenied`)].{Time:EventTime,User:Username,Event:EventName}' \
  --output table

# Or use CloudWatch Insights
# Navigate to CloudWatch > Insights
# Select your CloudTrail log group
# Run query:
fields @timestamp, userIdentity.principalId, eventName, errorCode, errorMessage
| filter errorCode = "AccessDenied"
| sort @timestamp desc
| limit 100
```

### PCI Compliance Validation

Verify all PCI requirements are enforced:

| Requirement | Test Command | Expected Result |
|-------------|--------------|-----------------|
| Disallowed services | `aws lightsail get-instances` | Access Denied |
| No public S3 | `aws s3api create-bucket --acl public-read` | Access Denied |
| No open SGs | `aws ec2 authorize-security-group-ingress --cidr 0.0.0.0/0` | Access Denied |
| Only approved regions | `aws ec2 describe-instances --region ap-south-1` | Access Denied |
| No public networking | `aws ec2 create-internet-gateway` | Access Denied |
| Mandatory Flow Logs | `aws ec2 delete-flow-logs --flow-log-ids fl-xxx` | Access Denied |
| All storage encrypted | `aws ec2 create-volume --size 10` (no encryption) | Access Denied |
| No public S3 | `aws s3api put-bucket-acl --acl public-read` | Access Denied |
| Only approved instances | `aws ec2 run-instances --instance-type t2.micro` | Access Denied |

### SCP Best Practices

1. **Test in Non-Production First**
   ```bash
   # Create a test OU first
   aws organizations create-organizational-unit \
     --parent-id ROOT_ID \
     --name "PCI-Test"
   
   # Move a test account
   # Verify all SCPs work as expected
   # Then apply to production PCI OU
   ```

2. **Document Exceptions**
   - If you need to allow specific actions, document why
   - Use condition keys in SCPs for exceptions
   - Example: Allow specific IAM roles to bypass certain restrictions

3. **Monitor SCP Violations**
   - Set up CloudWatch alarms for SCP denies
   - Review violations weekly
   - Investigate unexpected denies

4. **Regular Reviews**
   - Quarterly review of approved regions
   - Monthly review of approved instance types
   - Annual review of disallowed services

### Troubleshooting SCPs

#### Issue: Legitimate Action Blocked

**Solution:**
```bash
# 1. Check CloudTrail for the deny event
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=YOUR_ACTION

# 2. Identify which SCP is blocking
# Review the SCP policies
terraform output scp_policies

# 3. Update the SCP if needed
vim scp.tf
# Modify the relevant SCP condition

# 4. Apply changes
terraform apply
```

#### Issue: SCP Not Enforcing

**Solution:**
```bash
# 1. Verify account is in PCI OU
aws organizations list-parents --child-id ACCOUNT_ID

# 2. Verify SCP is attached to OU
aws organizations list-policies-for-target \
  --target-id $(terraform output -raw pci_ou_id) \
  --filter SERVICE_CONTROL_POLICY

# 3. Check SCP policy content
aws organizations describe-policy \
  --policy-id POLICY_ID
```

#### Issue: Need to Temporarily Bypass SCP

**Solution:**
```bash
# SCPs cannot be bypassed, but you can:

# Option 1: Move account out of PCI OU temporarily
aws organizations move-account \
  --account-id ACCOUNT_ID \
  --source-parent-id PCI_OU_ID \
  --destination-parent-id ROOT_ID

# Perform necessary action

# Move back to PCI OU
aws organizations move-account \
  --account-id ACCOUNT_ID \
  --source-parent-id ROOT_ID \
  --destination-parent-id PCI_OU_ID

# Option 2: Modify SCP temporarily (not recommended)
# Better to use Option 1
```

### Drift Detection and Auto-Remediation

Enable AWS Config for drift detection:

```bash
# Enable AWS Config
aws configservice put-configuration-recorder \
  --configuration-recorder name=default,roleARN=arn:aws:iam::ACCOUNT:role/ConfigRole \
  --recording-group allSupported=true,includeGlobalResourceTypes=true

# Enable Config Rules for PCI compliance
aws configservice put-config-rule \
  --config-rule file://pci-config-rules.json

# Enable Security Hub for compliance monitoring
aws securityhub enable-security-hub \
  --enable-default-standards
```

### Important Notes

- **Optional**: SCPs are not required for the main Cloud WAN architecture
- **Test First**: Always test in non-production before applying to production
- **Cannot Bypass**: Even root user cannot bypass SCPs
- **CloudTrail Required**: Ensure CloudTrail is enabled to log SCP violations
- **Organization Required**: SCPs require AWS Organizations to be set up
- **Gradual Rollout**: Consider rolling out SCPs gradually, one at a time

## References

- [AWS Cloud WAN Documentation](https://docs.aws.amazon.com/vpc/latest/cloudwan/)
- [AWS Transit Gateway Documentation](https://docs.aws.amazon.com/vpc/latest/tgw/)
- [AWS Network Firewall Documentation](https://docs.aws.amazon.com/network-firewall/)
- [Gateway Load Balancer Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/gateway/)
- [AWS Organizations SCPs Documentation](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
