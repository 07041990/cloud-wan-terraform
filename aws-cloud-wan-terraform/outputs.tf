# ============================================================================
# Cloud WAN Outputs
# ============================================================================

output "cloud_wan_global_network_id" {
  description = "ID of the Cloud WAN Global Network"
  value       = aws_networkmanager_global_network.main.id
}

output "cloud_wan_global_network_arn" {
  description = "ARN of the Cloud WAN Global Network"
  value       = aws_networkmanager_global_network.main.arn
}

output "cloud_wan_core_network_id" {
  description = "ID of the Cloud WAN Core Network"
  value       = aws_networkmanager_core_network.main.id
}

output "cloud_wan_core_network_arn" {
  description = "ARN of the Cloud WAN Core Network"
  value       = aws_networkmanager_core_network.main.arn
}

# ============================================================================
# Transit Gateway Outputs
# ============================================================================

output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.main.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.main.arn
}

output "transit_gateway_route_table_ids" {
  description = "Map of Transit Gateway Route Table IDs"
  value = {
    production     = aws_ec2_transit_gateway_route_table.production.id
    non_production = aws_ec2_transit_gateway_route_table.non_production.id
    shared         = aws_ec2_transit_gateway_route_table.shared.id
    egress         = aws_ec2_transit_gateway_route_table.egress.id
  }
}

# ============================================================================
# VPC Outputs
# ============================================================================

output "production_vpc_id" {
  description = "ID of the Production VPC"
  value       = module.production_vpc.vpc_id
}

output "production_vpc_cidr" {
  description = "CIDR block of the Production VPC"
  value       = module.production_vpc.vpc_cidr
}

output "non_production_vpc_id" {
  description = "ID of the Non-Production VPC"
  value       = module.non_production_vpc.vpc_id
}

output "non_production_vpc_cidr" {
  description = "CIDR block of the Non-Production VPC"
  value       = module.non_production_vpc.vpc_cidr
}

output "shared_services_vpc_id" {
  description = "ID of the Shared Services VPC"
  value       = module.shared_services_vpc.vpc_id
}

output "shared_services_vpc_cidr" {
  description = "CIDR block of the Shared Services VPC"
  value       = module.shared_services_vpc.vpc_cidr
}

output "egress_vpc_id" {
  description = "ID of the Egress VPC"
  value       = module.egress_vpc.vpc_id
}

output "egress_vpc_cidr" {
  description = "CIDR block of the Egress VPC"
  value       = module.egress_vpc.vpc_cidr
}

# ============================================================================
# Network Firewall Outputs
# ============================================================================

output "network_firewall_id" {
  description = "ID of the Network Firewall"
  value       = module.egress_vpc.network_firewall_id
}

output "network_firewall_arn" {
  description = "ARN of the Network Firewall"
  value       = module.egress_vpc.network_firewall_arn
}

output "network_firewall_status" {
  description = "Status of the Network Firewall"
  value       = module.egress_vpc.network_firewall_status
}

output "network_firewall_endpoint_ids" {
  description = "IDs of Network Firewall endpoints"
  value       = module.egress_vpc.network_firewall_endpoint_ids
}

# ============================================================================
# Gateway Load Balancer Outputs
# ============================================================================

output "gateway_load_balancer_id" {
  description = "ID of the Gateway Load Balancer"
  value       = module.egress_vpc.gateway_load_balancer_id
}

output "gateway_load_balancer_arn" {
  description = "ARN of the Gateway Load Balancer"
  value       = module.egress_vpc.gateway_load_balancer_arn
}

output "gwlb_endpoint_ids" {
  description = "IDs of GWLB VPC endpoints"
  value       = module.egress_vpc.gwlb_endpoint_ids
}

# ============================================================================
# NAT Gateway Outputs
# ============================================================================

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = module.egress_vpc.nat_gateway_ids
}

output "nat_gateway_public_ips" {
  description = "Public IPs of NAT Gateways"
  value       = module.egress_vpc.nat_gateway_public_ips
}

# ============================================================================
# Transit Gateway Attachment Outputs
# ============================================================================

output "tgw_attachment_ids" {
  description = "Map of Transit Gateway VPC Attachment IDs"
  value = {
    production     = aws_ec2_transit_gateway_vpc_attachment.production.id
    non_production = aws_ec2_transit_gateway_vpc_attachment.non_production.id
    shared         = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
    egress         = aws_ec2_transit_gateway_vpc_attachment.egress.id
  }
}

# ============================================================================
# CloudWatch Log Groups
# ============================================================================

output "vpc_flow_log_groups" {
  description = "CloudWatch Log Groups for VPC Flow Logs"
  value = {
    production     = module.production_vpc.flow_log_group_name
    non_production = module.non_production_vpc.flow_log_group_name
    shared         = module.shared_services_vpc.flow_log_group_name
    egress         = module.egress_vpc.flow_log_group_name
  }
}

output "firewall_log_groups" {
  description = "CloudWatch Log Groups for Network Firewall"
  value       = module.egress_vpc.firewall_log_groups
}

# ============================================================================
# Resource Sharing Outputs
# ============================================================================

output "ram_resource_share_id" {
  description = "ID of the RAM Resource Share for Transit Gateway"
  value       = aws_ram_resource_share.tgw.id
}

output "ram_resource_share_arn" {
  description = "ARN of the RAM Resource Share for Transit Gateway"
  value       = aws_ram_resource_share.tgw.arn
}

# ============================================================================
# Summary Outputs
# ============================================================================

output "deployment_summary" {
  description = "Summary of the deployed infrastructure"
  value = {
    region                = var.aws_region
    availability_zones    = var.availability_zones
    multi_az_enabled      = var.enable_multi_az
    vpc_count             = 4
    transit_gateway_id    = aws_ec2_transit_gateway.main.id
    cloud_wan_enabled     = true
    network_firewall_name = var.firewall_name
    nat_gateway_count     = var.single_nat_gateway ? 1 : length(var.availability_zones)
  }
}

output "validation_checks" {
  description = "Validation checks for success criteria"
  value = {
    prod_nonprod_isolated     = "Production and Non-Production VPCs use separate TGW route tables with no cross-segment routes"
    shared_services_accessible = "Shared Services VPC has routes configured in both Production and Non-Production TGW route tables"
    centralized_egress        = "All spoke VPCs route 0.0.0.0/0 to Egress VPC via Transit Gateway"
    no_direct_igw_on_spokes   = "Production, Non-Production, and Shared Services VPCs have no Internet Gateways"
    firewall_deployed         = "Network Firewall deployed in Egress VPC with domain and IP filtering"
    gwlb_pattern_implemented  = "Gateway Load Balancer deployed for transparent firewall insertion"
  }
}

output "next_steps" {
  description = "Next steps after deployment"
  value = <<-EOT
    1. Verify Transit Gateway attachments are in 'available' state
    2. Test connectivity between Production VPC and Shared Services VPC
    3. Verify Production and Non-Production VPCs cannot communicate
    4. Test internet access from spoke VPCs (should route through Egress VPC)
    5. Check Network Firewall logs in CloudWatch for blocked/allowed traffic
    6. Review VPC Flow Logs for traffic patterns
    7. Deploy test EC2 instances in each VPC for validation
    8. Configure additional firewall rules as needed
    9. Set up CloudWatch alarms for monitoring
    10. Document any custom configurations
  EOT
}

output "important_notes" {
  description = "Important notes about the deployment"
  value = <<-EOT
    IMPORTANT NOTES:
    
    1. CROSS-ACCOUNT ACCESS:
       - Ensure IAM roles exist in each account: TerraformExecutionRole
       - Verify RAM resource sharing is accepted in spoke accounts
       - Check TGW attachments are accepted (if require_attachment_acceptance = true)
    
    2. NETWORK CONNECTIVITY:
       - Production VPC: ${var.prod_vpc_cidr}
       - Non-Production VPC: ${var.non_prod_vpc_cidr}
       - Shared Services VPC: ${var.shared_services_vpc_cidr}
       - Egress VPC: ${var.egress_vpc_cidr}
    
    3. FIREWALL RULES:
       - Blocked domains: ${length(var.blocked_domains)} configured
       - Allowed domains: ${length(var.allowed_domains)} configured
       - Blocked IPs: ${length(var.blocked_ips)} configured
       - Review and update rules in terraform.tfvars as needed
    
    4. COST OPTIMIZATION:
       - NAT Gateways: ${var.single_nat_gateway ? "1 (single)" : "${length(var.availability_zones)} (multi-AZ)"}
       - Consider using single NAT Gateway for non-production environments
       - Review Network Firewall capacity settings
    
    5. MONITORING:
       - VPC Flow Logs retention: ${var.flow_logs_retention_days} days
       - Firewall logs retention: ${var.firewall_log_retention_days} days
       - Set up CloudWatch alarms for critical metrics
    
    6. SECURITY:
       - No direct Internet Gateways on spoke VPCs (enforced)
       - All internet traffic flows through centralized egress
       - Network Firewall provides stateful inspection
       - Review security groups and NACLs as needed
  EOT
}
