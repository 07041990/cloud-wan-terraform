# ============================================================================
# Egress VPC Module Variables
# ============================================================================

variable "vpc_name" {
  description = "Name of the Egress VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the Egress VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of CIDR blocks for public subnets (NAT GW, IGW)"
  type        = list(string)
}

variable "firewall_subnets" {
  description = "List of CIDR blocks for firewall subnets"
  type        = list(string)
}

variable "tgw_subnets" {
  description = "List of CIDR blocks for Transit Gateway subnets"
  type        = list(string)
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention" {
  description = "Number of days to retain VPC Flow Logs"
  type        = number
  default     = 30
}

# NAT Gateway Configuration
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (cost optimization) vs one per AZ"
  type        = bool
  default     = false
}

# Network Firewall Configuration
variable "firewall_name" {
  description = "Name for AWS Network Firewall"
  type        = string
}

variable "blocked_domains" {
  description = "List of domains to block"
  type        = list(string)
  default     = []
}

variable "allowed_domains" {
  description = "List of domains to explicitly allow"
  type        = list(string)
  default     = []
}

variable "blocked_ips" {
  description = "List of IP CIDR blocks to block"
  type        = list(string)
  default     = []
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

variable "firewall_log_retention" {
  description = "Number of days to retain firewall logs"
  type        = number
  default     = 90
}

# Gateway Load Balancer Configuration
variable "gwlb_name" {
  description = "Name for Gateway Load Balancer"
  type        = string
}

variable "gwlb_cross_zone_load_balancing" {
  description = "Enable cross-zone load balancing for GWLB"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
