# ============================================================================
# Egress VPC Module Outputs
# ============================================================================

output "vpc_id" {
  description = "ID of the Egress VPC"
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "ARN of the Egress VPC"
  value       = aws_vpc.main.arn
}

output "vpc_cidr" {
  description = "CIDR block of the Egress VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "firewall_subnet_ids" {
  description = "IDs of firewall subnets"
  value       = aws_subnet.firewall[*].id
}

output "tgw_subnet_ids" {
  description = "IDs of Transit Gateway subnets"
  value       = aws_subnet.tgw[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IPs of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "network_firewall_id" {
  description = "ID of the Network Firewall"
  value       = aws_networkfirewall_firewall.main.id
}

output "network_firewall_arn" {
  description = "ARN of the Network Firewall"
  value       = aws_networkfirewall_firewall.main.arn
}

output "network_firewall_status" {
  description = "Status of the Network Firewall"
  value       = aws_networkfirewall_firewall.main.firewall_status
}

output "network_firewall_endpoint_ids" {
  description = "IDs of Network Firewall endpoints"
  value       = [for endpoint in aws_networkfirewall_firewall.main.firewall_status[0].sync_states : endpoint.attachment[0].endpoint_id]
}

output "gateway_load_balancer_id" {
  description = "ID of the Gateway Load Balancer"
  value       = aws_lb.gwlb.id
}

output "gateway_load_balancer_arn" {
  description = "ARN of the Gateway Load Balancer"
  value       = aws_lb.gwlb.arn
}

output "gwlb_endpoint_ids" {
  description = "IDs of GWLB VPC endpoints"
  value       = aws_vpc_endpoint.gwlb[*].id
}

output "flow_log_group_name" {
  description = "Name of the CloudWatch Log Group for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}

output "firewall_log_groups" {
  description = "CloudWatch Log Groups for Network Firewall"
  value = {
    alert = var.enable_firewall_alert_logs ? aws_cloudwatch_log_group.firewall_alert[0].name : null
    flow  = var.enable_firewall_flow_logs ? aws_cloudwatch_log_group.firewall_flow[0].name : null
  }
}
