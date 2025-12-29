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

### Modules 

The following modules are referenced in main.tf 

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

## References

- [AWS Cloud WAN Documentation](https://docs.aws.amazon.com/vpc/latest/cloudwan/)
- [AWS Transit Gateway Documentation](https://docs.aws.amazon.com/vpc/latest/tgw/)
- [AWS Network Firewall Documentation](https://docs.aws.amazon.com/network-firewall/)
- [Gateway Load Balancer Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/gateway/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
