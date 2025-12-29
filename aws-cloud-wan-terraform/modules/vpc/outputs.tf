# ============================================================================
# VPC Module Outputs
# ============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.main.arn
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "tgw_subnet_ids" {
  description = "IDs of Transit Gateway subnets"
  value       = aws_subnet.tgw[*].id
}

output "tgw_subnet_cidrs" {
  description = "CIDR blocks of Transit Gateway subnets"
  value       = aws_subnet.tgw[*].cidr_block
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

output "tgw_route_table_id" {
  description = "ID of the TGW route table"
  value       = aws_route_table.tgw.id
}

output "flow_log_group_name" {
  description = "Name of the CloudWatch Log Group for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}

output "flow_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].arn : null
}

output "default_security_group_id" {
  description = "ID of the default security group"
  value       = aws_default_security_group.default.id
}
