# ============================================================================
# Egress VPC Module - Centralized Egress with Network Firewall & GWLB
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
      Name = var.vpc_name
    }
  )
}

# ============================================================================
# Internet Gateway
# ============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-igw"
    }
  )
}

# ============================================================================
# Subnets
# ============================================================================

# Public Subnets (for NAT Gateways and IGW)
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-public-${var.availability_zones[count.index]}"
      Type = "public"
    }
  )
}

# Firewall Subnets (for Network Firewall endpoints)
resource "aws_subnet" "firewall" {
  count = length(var.firewall_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.firewall_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-firewall-${var.availability_zones[count.index]}"
      Type = "firewall"
    }
  )
}

# TGW Subnets (for Transit Gateway attachments)
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
# Elastic IPs for NAT Gateways
# ============================================================================

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-nat-eip-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ============================================================================
# NAT Gateways
# ============================================================================

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-nat-${var.availability_zones[count.index]}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ============================================================================
# Network Firewall - Rule Groups
# ============================================================================

# Stateful Domain List Rule Group (Block malicious domains)
resource "aws_networkfirewall_rule_group" "domain_block" {
  count = length(var.blocked_domains) > 0 ? 1 : 0

  capacity = 100
  name     = "${var.firewall_name}-domain-block"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = var.blocked_domains
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.firewall_name}-domain-block"
    }
  )
}

# Stateful Domain List Rule Group (Allow specific domains)
resource "aws_networkfirewall_rule_group" "domain_allow" {
  count = length(var.allowed_domains) > 0 ? 1 : 0

  capacity = 100
  name     = "${var.firewall_name}-domain-allow"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = var.allowed_domains
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.firewall_name}-domain-allow"
    }
  )
}

# Stateful IP Block Rule Group
resource "aws_networkfirewall_rule_group" "ip_block" {
  count = length(var.blocked_ips) > 0 ? 1 : 0

  capacity = 100
  name     = "${var.firewall_name}-ip-block"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      stateful_rule {
        action = "DROP"
        header {
          destination      = "ANY"
          destination_port = "ANY"
          direction        = "ANY"
          protocol         = "IP"
          source           = join(",", var.blocked_ips)
          source_port      = "ANY"
        }
        rule_option {
          keyword = "sid:1"
        }
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.firewall_name}-ip-block"
    }
  )
}

# ============================================================================
# Network Firewall Policy
# ============================================================================

resource "aws_networkfirewall_firewall_policy" "main" {
  name = "${var.firewall_name}-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    # Stateful rule group references
    dynamic "stateful_rule_group_reference" {
      for_each = length(var.blocked_domains) > 0 ? [1] : []
      content {
        resource_arn = aws_networkfirewall_rule_group.domain_block[0].arn
      }
    }

    dynamic "stateful_rule_group_reference" {
      for_each = length(var.allowed_domains) > 0 ? [1] : []
      content {
        resource_arn = aws_networkfirewall_rule_group.domain_allow[0].arn
      }
    }

    dynamic "stateful_rule_group_reference" {
      for_each = length(var.blocked_ips) > 0 ? [1] : []
      content {
        resource_arn = aws_networkfirewall_rule_group.ip_block[0].arn
      }
    }

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.firewall_name}-policy"
    }
  )
}

# ============================================================================
# Network Firewall
# ============================================================================

resource "aws_networkfirewall_firewall" "main" {
  name                = var.firewall_name
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
  vpc_id              = aws_vpc.main.id

  dynamic "subnet_mapping" {
    for_each = aws_subnet.firewall
    content {
      subnet_id = subnet_mapping.value.id
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.firewall_name
    }
  )
}

# ============================================================================
# CloudWatch Log Groups for Network Firewall
# ============================================================================

resource "aws_cloudwatch_log_group" "firewall_alert" {
  count = var.enable_firewall_alert_logs ? 1 : 0

  name              = "/aws/networkfirewall/${var.firewall_name}-alert"
  retention_in_days = var.firewall_log_retention

  tags = merge(
    var.tags,
    {
      Name = "${var.firewall_name}-alert-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "firewall_flow" {
  count = var.enable_firewall_flow_logs ? 1 : 0

  name              = "/aws/networkfirewall/${var.firewall_name}-flow"
  retention_in_days = var.firewall_log_retention

  tags = merge(
    var.tags,
    {
      Name = "${var.firewall_name}-flow-logs"
    }
  )
}

# ============================================================================
# Network Firewall Logging Configuration
# ============================================================================

resource "aws_networkfirewall_logging_configuration" "main" {
  firewall_arn = aws_networkfirewall_firewall.main.arn

  logging_configuration {
    dynamic "log_destination_config" {
      for_each = var.enable_firewall_alert_logs ? [1] : []
      content {
        log_destination = {
          logGroup = aws_cloudwatch_log_group.firewall_alert[0].name
        }
        log_destination_type = "CloudWatchLogs"
        log_type             = "ALERT"
      }
    }

    dynamic "log_destination_config" {
      for_each = var.enable_firewall_flow_logs ? [1] : []
      content {
        log_destination = {
          logGroup = aws_cloudwatch_log_group.firewall_flow[0].name
        }
        log_destination_type = "CloudWatchLogs"
        log_type             = "FLOW"
      }
    }
  }
}

# ============================================================================
# Gateway Load Balancer (GWLB)
# ============================================================================

resource "aws_lb" "gwlb" {
  name               = var.gwlb_name
  load_balancer_type = "gateway"
  subnets            = aws_subnet.firewall[*].id

  enable_cross_zone_load_balancing = var.gwlb_cross_zone_load_balancing

  tags = merge(
    var.tags,
    {
      Name = var.gwlb_name
    }
  )
}

# GWLB Target Group
resource "aws_lb_target_group" "gwlb" {
  name     = "${var.gwlb_name}-tg"
  port     = 6081
  protocol = "GENEVE"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled  = true
    port     = 80
    protocol = "HTTP"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.gwlb_name}-tg"
    }
  )
}

# GWLB Listener
resource "aws_lb_listener" "gwlb" {
  load_balancer_arn = aws_lb.gwlb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gwlb.arn
  }
}

# GWLB Endpoint Service
resource "aws_vpc_endpoint_service" "gwlb" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]

  tags = merge(
    var.tags,
    {
      Name = "${var.gwlb_name}-endpoint-service"
    }
  )
}

# GWLB VPC Endpoints (one per firewall subnet)
resource "aws_vpc_endpoint" "gwlb" {
  count = length(aws_subnet.firewall)

  service_name      = aws_vpc_endpoint_service.gwlb.service_name
  subnet_ids        = [aws_subnet.firewall[count.index].id]
  vpc_endpoint_type = "GatewayLoadBalancer"
  vpc_id            = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.gwlb_name}-endpoint-${count.index + 1}"
    }
  )
}

# ============================================================================
# Route Tables
# ============================================================================

# Public Route Table (IGW → Firewall → NAT)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-public-rt"
    }
  )
}

# Firewall Route Table (NAT → IGW)
resource "aws_route_table" "firewall" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-firewall-rt"
    }
  )
}

# TGW Route Table (TGW → GWLB Endpoint)
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
# Routes
# ============================================================================

# Public subnet: Default route to IGW
resource "aws_route" "public_to_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Firewall subnet: Default route to NAT Gateway
resource "aws_route" "firewall_to_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.firewall.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

# TGW subnet: Default route to GWLB Endpoint
resource "aws_route" "tgw_to_gwlb" {
  count = length(aws_vpc_endpoint.gwlb)

  route_table_id         = aws_route_table.tgw.id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = aws_vpc_endpoint.gwlb[0].id
}

# ============================================================================
# Route Table Associations
# ============================================================================

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "firewall" {
  count = length(aws_subnet.firewall)

  subnet_id      = aws_subnet.firewall[count.index].id
  route_table_id = aws_route_table.firewall.id
}

resource "aws_route_table_association" "tgw" {
  count = length(aws_subnet.tgw)

  subnet_id      = aws_subnet.tgw[count.index].id
  route_table_id = aws_route_table.tgw.id
}

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
