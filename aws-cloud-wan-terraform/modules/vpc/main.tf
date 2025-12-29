# ============================================================================
# Standard VPC Module for Spoke VPCs
# Used for: Production, Non-Production, and Shared Services VPCs
# ============================================================================

# ============================================================================
# VPC
# ============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name    = var.vpc_name
      Segment = var.segment
    }
  )
}

# ============================================================================
# Private Subnets (for workloads)
# ============================================================================

resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-private-${var.availability_zones[count.index]}"
      Type = "private"
    }
  )
}

# ============================================================================
# TGW Subnets (for Transit Gateway attachments)
# ============================================================================

resource "aws_subnet" "tgw" {
  count = length(var.tgw_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.tgw_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-tgw-${var.availability_zones[count.index]}"
      Type = "tgw"
    }
  )
}

# ============================================================================
# Route Tables
# ============================================================================

# Private Route Table (routes to TGW for internet and cross-VPC traffic)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-private-rt"
    }
  )
}

# TGW Route Table
resource "aws_route_table" "tgw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-tgw-rt"
    }
  )
}

# ============================================================================
# Route Table Associations
# ============================================================================

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "tgw" {
  count = length(aws_subnet.tgw)

  subnet_id      = aws_subnet.tgw[count.index].id
  route_table_id = aws_route_table.tgw.id
}

# ============================================================================
# Default Route to TGW (for internet access via centralized egress)
# Note: TGW ID will be added after TGW attachment is created
# ============================================================================

# This route will be added by the root module after TGW attachment
# Placeholder for documentation purposes
# Route: 0.0.0.0/0 → Transit Gateway

# ============================================================================
# VPC Flow Logs
# ============================================================================

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/flow-logs/${var.vpc_name}"
  retention_in_days = var.flow_logs_retention

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-flow-logs"
    }
  )
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.vpc_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.vpc_name}-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-flow-log"
    }
  )
}

# ============================================================================
# Default Security Group (restrictive by default)
# ============================================================================

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No ingress rules (deny all inbound by default)
  
  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-default-sg"
    }
  )
}

# ============================================================================
# Network ACLs (default - allow all, use Security Groups for restrictions)
# ============================================================================

resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.main.default_network_acl_id

  # Allow all inbound
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Allow all outbound
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-default-nacl"
    }
  )
}
