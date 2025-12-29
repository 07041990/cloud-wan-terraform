# ============================================================================
# AWS Cloud WAN + Transit Gateway Configuration
# Copy this file to terraform.tfvars and update with your values
# ============================================================================

# ============================================================================
# AWS Account IDs
# Replace with your actual AWS account IDs
# ============================================================================
network_hub_account_id     = "111111111111"  # Network Hub Account
production_account_id      = "222222222222"  # Production Account
non_production_account_id  = "333333333333"  # Non-Production Account
shared_services_account_id = "444444444444"  # Shared Services Account
organization_id            = "o-xxxxxxxxxx"  # AWS Organization ID

# ============================================================================
# Region Configuration
# ============================================================================
aws_region = "us-east-1"

# Availability Zones (adjust based on your region)
availability_zones = ["us-east-1a", "us-east-1b"]

# ============================================================================
# Project Configuration
# ============================================================================
project_name = "cloud-wan-segmentation"
environment  = "production"
name_prefix  = "cwan"

# ============================================================================
# Network CIDR Ranges
# Adjust these if they conflict with existing networks
# ============================================================================
prod_vpc_cidr            = "10.1.0.0/16"
non_prod_vpc_cidr        = "10.2.0.0/16"
shared_services_vpc_cidr = "10.3.0.0/16"
inspection_vpc_cidr      = "10.4.0.0/16"
egress_vpc_cidr          = "10.5.0.0/16"

# ============================================================================
# High Availability Configuration
# ============================================================================
enable_multi_az      = true   # Set to false for cost optimization
single_nat_gateway   = false  # Set to true to use only 1 NAT Gateway (saves cost)

# ============================================================================
# Network Firewall Rules
# Customize based on your security requirements
# ============================================================================

# Domains to block
blocked_domains = [
  "malware.com",
  "phishing.net",
  "*.badsite.org",
  "*.malicious.com",
  "cryptomining.xyz"
]

# Domains to explicitly allow
allowed_domains = [
  "*.amazonaws.com",
  "*.amazon.com",
  "*.github.com",
  "*.ubuntu.com",
  "*.debian.org",
  "*.redhat.com",
  "*.docker.com",
  "*.npmjs.org",
  "*.pypi.org",
  "*.cloudflare.com"
]

# IP ranges to block
blocked_ips = [
  "192.0.2.0/24",      # TEST-NET-1 (example - replace with actual malicious IPs)
  "198.51.100.0/24",   # TEST-NET-2 (example)
  "203.0.113.0/24"     # TEST-NET-3 (example)
]

# ============================================================================
# Transit Gateway Configuration
# ============================================================================
tgw_asn              = 64512
tgw_dns_support      = true
tgw_vpn_ecmp_support = true

# ============================================================================
# Logging and Monitoring
# ============================================================================
enable_vpc_flow_logs         = true
flow_logs_retention_days     = 30
enable_cloudwatch_logs       = true
firewall_log_retention_days  = 90
enable_firewall_alert_logs   = true
enable_firewall_flow_logs    = true

# ============================================================================
# Gateway Load Balancer
# ============================================================================
gwlb_cross_zone_load_balancing = true

# ============================================================================
# Additional Tags
# Add any custom tags for your organization
# ============================================================================
additional_tags = {
  CostCenter  = "NetworkOps"
  Owner       = "CloudTeam"
  Compliance  = "SOC2"
  Backup      = "Daily"
}
