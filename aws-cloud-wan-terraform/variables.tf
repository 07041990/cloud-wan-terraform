# ============================================================================
# AWS Account Configuration
# ============================================================================

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "network_hub_account_id" {
  description = "AWS Account ID for Network Hub (manages TGW, Cloud WAN, Egress VPC)"
  type        = string
  default     = "111111111111"
}

variable "production_account_id" {
  description = "AWS Account ID for Production workloads"
  type        = string
  default     = "222222222222"
}

variable "non_production_account_id" {
  description = "AWS Account ID for Non-Production workloads"
  type        = string
  default     = "333333333333"
}

variable "shared_services_account_id" {
  description = "AWS Account ID for Shared Services"
  type        = string
  default     = "444444444444"
}

variable "organization_id" {
  description = "AWS Organization ID for resource sharing"
  type        = string
  default     = "o-xxxxxxxxxx"
}

# ============================================================================
# Project Configuration
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "cloud-wan-segmentation"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# ============================================================================
# Network Configuration - VPC CIDR Ranges
# ============================================================================

variable "prod_vpc_cidr" {
  description = "CIDR block for Production VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "non_prod_vpc_cidr" {
  description = "CIDR block for Non-Production VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "shared_services_vpc_cidr" {
  description = "CIDR block for Shared Services VPC"
  type        = string
  default     = "10.3.0.0/16"
}

variable "inspection_vpc_cidr" {
  description = "CIDR block for Inspection VPC"
  type        = string
  default     = "10.4.0.0/16"
}

variable "egress_vpc_cidr" {
  description = "CIDR block for Egress VPC"
  type        = string
  default     = "10.5.0.0/16"
}

# ============================================================================
# Availability Zones
# ============================================================================

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_multi_az" {
  description = "Enable multi-AZ deployment for high availability"
  type        = bool
  default     = true
}

# ============================================================================
# Transit Gateway Configuration
# ============================================================================

variable "tgw_asn" {
  description = "BGP ASN for Transit Gateway"
  type        = number
  default     = 64512
}

variable "tgw_dns_support" {
  description = "Enable DNS support for Transit Gateway"
  type        = bool
  default     = true
}

variable "tgw_vpn_ecmp_support" {
  description = "Enable ECMP support for VPN connections"
  type        = bool
  default     = true
}

# ============================================================================
# Cloud WAN Configuration
# ============================================================================

variable "cloud_wan_description" {
  description = "Description for Cloud WAN Global Network"
  type        = string
  default     = "Multi-account segmentation with centralized egress"
}

variable "cloud_wan_segments" {
  description = "Cloud WAN segment configuration"
  type = map(object({
    description       = string
    isolate_attachments = bool
    require_attachment_acceptance = bool
  }))
  default = {
    production = {
      description       = "Production segment - isolated from non-prod"
      isolate_attachments = true
      require_attachment_acceptance = false
    }
    non-production = {
      description       = "Non-production segment - isolated from prod"
      isolate_attachments = true
      require_attachment_acceptance = false
    }
    shared = {
      description       = "Shared services segment - accessible to all"
      isolate_attachments = false
      require_attachment_acceptance = false
    }
    inspection = {
      description       = "Inspection segment - centralized monitoring"
      isolate_attachments = false
      require_attachment_acceptance = false
    }
  }
}

# ============================================================================
# Network Firewall Configuration
# ============================================================================

variable "firewall_name" {
  description = "Name for AWS Network Firewall"
  type        = string
  default     = "egress-firewall"
}

variable "blocked_domains" {
  description = "List of domains to block in Network Firewall"
  type        = list(string)
  default = [
    "malware.com",
    "phishing.net",
    "*.badsite.org",
    "*.malicious.com",
    "cryptomining.xyz"
  ]
}

variable "allowed_domains" {
  description = "List of domains to explicitly allow in Network Firewall"
  type        = list(string)
  default = [
    "*.amazonaws.com",
    "*.amazon.com",
    "*.github.com",
    "*.ubuntu.com",
    "*.debian.org",
    "*.redhat.com",
    "*.docker.com",
    "*.npmjs.org",
    "*.pypi.org"
  ]
}

variable "blocked_ips" {
  description = "List of IP CIDR blocks to block"
  type        = list(string)
  default = [
    "192.0.2.0/24",      # TEST-NET-1 (example)
    "198.51.100.0/24",   # TEST-NET-2 (example)
    "203.0.113.0/24"     # TEST-NET-3 (example)
  ]
}

variable "firewall_policy_stateful_rule_group_reference" {
  description = "Priority for stateful rule groups"
  type        = number
  default     = 100
}

# ============================================================================
# NAT Gateway Configuration
# ============================================================================

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for egress VPC"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (cost optimization) vs one per AZ (HA)"
  type        = bool
  default     = false
}

# ============================================================================
# VPC Flow Logs Configuration
# ============================================================================

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for all VPCs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Logs"
  type        = number
  default     = 30
}

# ============================================================================
# Monitoring and Logging
# ============================================================================

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs for Network Firewall"
  type        = bool
  default     = true
}

variable "firewall_log_retention_days" {
  description = "Number of days to retain firewall logs"
  type        = number
  default     = 90
}

variable "enable_firewall_alert_logs" {
  description = "Enable alert logs for Network Firewall"
  type        = bool
  default     = true
}

variable "enable_firewall_flow_logs" {
  description = "Enable flow logs for Network Firewall"
  type        = bool
  default     = true
}

# ============================================================================
# Gateway Load Balancer Configuration
# ============================================================================

variable "gwlb_name" {
  description = "Name for Gateway Load Balancer"
  type        = string
  default     = "egress-gwlb"
}

variable "gwlb_cross_zone_load_balancing" {
  description = "Enable cross-zone load balancing for GWLB"
  type        = bool
  default     = true
}

# ============================================================================
# Resource Naming
# ============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "cwan"
}

# ============================================================================
# Tags
# ============================================================================

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
