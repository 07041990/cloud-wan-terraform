# ============================================================================
# AWS Cloud WAN + Transit Gateway Multi-Account Architecture
# ============================================================================

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )

  # Calculate subnet CIDRs for each VPC
  prod_subnets = {
    private = [for i, az in var.availability_zones : cidrsubnet(var.prod_vpc_cidr, 8, i)]
    tgw     = [cidrsubnet(var.prod_vpc_cidr, 8, 255)]
  }

  non_prod_subnets = {
    private = [for i, az in var.availability_zones : cidrsubnet(var.non_prod_vpc_cidr, 8, i)]
    tgw     = [cidrsubnet(var.non_prod_vpc_cidr, 8, 255)]
  }

  shared_services_subnets = {
    private = [for i, az in var.availability_zones : cidrsubnet(var.shared_services_vpc_cidr, 8, i)]
    tgw     = [cidrsubnet(var.shared_services_vpc_cidr, 8, 255)]
  }

  inspection_subnets = {
    firewall = [for i, az in var.availability_zones : cidrsubnet(var.inspection_vpc_cidr, 8, 10 + i)]
    tgw      = [cidrsubnet(var.inspection_vpc_cidr, 8, 255)]
  }

  egress_subnets = {
    public   = [for i, az in var.availability_zones : cidrsubnet(var.egress_vpc_cidr, 8, i)]
    firewall = [for i, az in var.availability_zones : cidrsubnet(var.egress_vpc_cidr, 8, 10 + i)]
    tgw      = [cidrsubnet(var.egress_vpc_cidr, 8, 255)]
  }
}

# ============================================================================
# AWS Cloud WAN - Global Network
# ============================================================================

resource "aws_networkmanager_global_network" "main" {
  description = var.cloud_wan_description

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-global-network"
    }
  )
}

resource "aws_networkmanager_core_network" "main" {
  global_network_id = aws_networkmanager_global_network.main.id
  description       = "Core network for multi-account segmentation"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-core-network"
    }
  )
}

# Cloud WAN Policy Document
resource "aws_networkmanager_core_network_policy_attachment" "main" {
  core_network_id = aws_networkmanager_core_network.main.id
  policy_document = jsonencode({
    version = "2021.12"
    core-network-configuration = {
      vpn-ecmp-support = var.tgw_vpn_ecmp_support
      asn-ranges       = ["64512-65534"]
      edge-locations = [
        {
          location = var.aws_region
          asn      = var.tgw_asn
        }
      ]
    }
    segments = [
      {
        name                          = "production"
        description                   = var.cloud_wan_segments["production"].description
        isolate-attachments           = var.cloud_wan_segments["production"].isolate_attachments
        require-attachment-acceptance = var.cloud_wan_segments["production"].require_attachment_acceptance
      },
      {
        name                          = "non-production"
        description                   = var.cloud_wan_segments["non-production"].description
        isolate-attachments           = var.cloud_wan_segments["non-production"].isolate_attachments
        require-attachment-acceptance = var.cloud_wan_segments["non-production"].require_attachment_acceptance
      },
      {
        name                          = "shared"
        description                   = var.cloud_wan_segments["shared"].description
        isolate-attachments           = var.cloud_wan_segments["shared"].isolate_attachments
        require-attachment-acceptance = var.cloud_wan_segments["shared"].require_attachment_acceptance
      },
      {
        name                          = "inspection"
        description                   = var.cloud_wan_segments["inspection"].description
        isolate-attachments           = var.cloud_wan_segments["inspection"].isolate_attachments
        require-attachment-acceptance = var.cloud_wan_segments["inspection"].require_attachment_acceptance
      }
    ]
    segment-actions = [
      {
        action  = "share"
        mode    = "attachment-route"
        segment = "shared"
        share-with = [
          "production",
          "non-production"
        ]
      }
    ]
    attachment-policies = [
      {
        rule-number     = 100
        condition-logic = "or"
        conditions = [
          {
            type     = "tag-value"
            operator = "equals"
            key      = "Segment"
            value    = "production"
          }
        ]
        action = {
          association-method = "constant"
          segment            = "production"
        }
      },
      {
        rule-number     = 200
        condition-logic = "or"
        conditions = [
          {
            type     = "tag-value"
            operator = "equals"
            key      = "Segment"
            value    = "non-production"
          }
        ]
        action = {
          association-method = "constant"
          segment            = "non-production"
        }
      },
      {
        rule-number     = 300
        condition-logic = "or"
        conditions = [
          {
            type     = "tag-value"
            operator = "equals"
            key      = "Segment"
            value    = "shared"
          }
        ]
        action = {
          association-method = "constant"
          segment            = "shared"
        }
      },
      {
        rule-number     = 400
        condition-logic = "or"
        conditions = [
          {
            type     = "tag-value"
            operator = "equals"
            key      = "Segment"
            value    = "inspection"
          }
        ]
        action = {
          association-method = "constant"
          segment            = "inspection"
        }
      }
    ]
  })
}

# ============================================================================
# Transit Gateway (Network Hub Account)
# ============================================================================

resource "aws_ec2_transit_gateway" "main" {
  description                     = "Transit Gateway for multi-account connectivity"
  amazon_side_asn                 = var.tgw_asn
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = var.tgw_dns_support ? "enable" : "disable"
  vpn_ecmp_support                = var.tgw_vpn_ecmp_support ? "enable" : "disable"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-tgw"
    }
  )
}

# Transit Gateway Route Tables
resource "aws_ec2_transit_gateway_route_table" "production" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.name_prefix}-tgw-rt-production"
      Segment = "production"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table" "non_production" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.name_prefix}-tgw-rt-non-production"
      Segment = "non-production"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table" "shared" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.name_prefix}-tgw-rt-shared"
      Segment = "shared"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table" "egress" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.name_prefix}-tgw-rt-egress"
      Segment = "egress"
    }
  )
}

# Resource Access Manager (RAM) - Share TGW with other accounts
resource "aws_ram_resource_share" "tgw" {
  name                      = "${var.name_prefix}-tgw-share"
  allow_external_principals = false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-tgw-share"
    }
  )
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = aws_ec2_transit_gateway.main.arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "production" {
  principal          = var.production_account_id
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "non_production" {
  principal          = var.non_production_account_id
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "shared_services" {
  principal          = var.shared_services_account_id
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

# ============================================================================
# VPC Modules
# ============================================================================

# Production VPC (in Production Account)
module "production_vpc" {
  source = "./modules/vpc"

#  providers = {
#    aws = aws.production
#  }

  vpc_name            = "${var.name_prefix}-prod-vpc"
  vpc_cidr            = var.prod_vpc_cidr
  availability_zones  = var.availability_zones
  private_subnets     = local.prod_subnets.private
  tgw_subnets         = local.prod_subnets.tgw
  enable_flow_logs    = var.enable_vpc_flow_logs
  flow_logs_retention = var.flow_logs_retention_days
  segment             = "production"

  tags = local.common_tags
}

# Non-Production VPC (in Non-Production Account)
module "non_production_vpc" {
  source = "./modules/vpc"

  providers = {
    aws = aws.nonproduction
  }

  vpc_name            = "${var.name_prefix}-nonprod-vpc"
  vpc_cidr            = var.non_prod_vpc_cidr
  availability_zones  = var.availability_zones
  private_subnets     = local.non_prod_subnets.private
  tgw_subnets         = local.non_prod_subnets.tgw
  enable_flow_logs    = var.enable_vpc_flow_logs
  flow_logs_retention = var.flow_logs_retention_days
  segment             = "non-production"

  tags = local.common_tags
}

# Shared Services VPC (in Shared Services Account)
module "shared_services_vpc" {
  source = "./modules/vpc"

  providers = {
    aws = aws.shared
  }

  vpc_name            = "${var.name_prefix}-shared-vpc"
  vpc_cidr            = var.shared_services_vpc_cidr
  availability_zones  = var.availability_zones
  private_subnets     = local.shared_services_subnets.private
  tgw_subnets         = local.shared_services_subnets.tgw
  enable_flow_logs    = var.enable_vpc_flow_logs
  flow_logs_retention = var.flow_logs_retention_days
  segment             = "shared"

  tags = local.common_tags
}

# Egress VPC (in Network Hub Account)
module "egress_vpc" {
  source = "./modules/egress-vpc"

  vpc_name            = "${var.name_prefix}-egress-vpc"
  vpc_cidr            = var.egress_vpc_cidr
  availability_zones  = var.availability_zones
  public_subnets      = local.egress_subnets.public
  firewall_subnets    = local.egress_subnets.firewall
  tgw_subnets         = local.egress_subnets.tgw
  enable_flow_logs    = var.enable_vpc_flow_logs
  flow_logs_retention = var.flow_logs_retention_days
  
  # NAT Gateway configuration
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  # Network Firewall configuration
  firewall_name              = var.firewall_name
  blocked_domains            = var.blocked_domains
  allowed_domains            = var.allowed_domains
  blocked_ips                = var.blocked_ips
  enable_firewall_alert_logs = var.enable_firewall_alert_logs
  enable_firewall_flow_logs  = var.enable_firewall_flow_logs
  firewall_log_retention     = var.firewall_log_retention_days

  # GWLB configuration
  gwlb_name                      = var.gwlb_name
  gwlb_cross_zone_load_balancing = var.gwlb_cross_zone_load_balancing

  tags = local.common_tags
}

# ============================================================================
# Transit Gateway Attachments
# ============================================================================

# Production VPC TGW Attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "production" {
  provider = aws.production

  subnet_ids         = module.production_vpc.tgw_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = module.production_vpc.vpc_id

  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.name_prefix}-tgw-attach-production"
      Segment = "production"
    }
  )
}

# Non-Production VPC TGW Attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "non_production" {
  provider = aws.nonproduction

  subnet_ids         = module.non_production_vpc.tgw_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = module.non_production_vpc.vpc_id

  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.name_prefix}-tgw-attach-non-production"
      Segment = "non-production"
    }
  )
}

# Shared Services VPC TGW Attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "shared_services" {
  provider = aws.shared

  subnet_ids         = module.shared_services_vpc.tgw_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = module.shared_services_vpc.vpc_id

  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.name_prefix}-tgw-attach-shared"
      Segment = "shared"
    }
  )
}

# Egress VPC TGW Attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "egress" {
  subnet_ids         = module.egress_vpc.tgw_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = module.egress_vpc.vpc_id

  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.name_prefix}-tgw-attach-egress"
      Segment = "egress"
    }
  )
}

# ============================================================================
# Transit Gateway Route Table Associations
# ============================================================================

resource "aws_ec2_transit_gateway_route_table_association" "production" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.production.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.production.id
}

resource "aws_ec2_transit_gateway_route_table_association" "non_production" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.non_production.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.non_production.id
}

resource "aws_ec2_transit_gateway_route_table_association" "shared_services" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
}

resource "aws_ec2_transit_gateway_route_table_association" "egress" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}

# ============================================================================
# Transit Gateway Routes - Centralized Egress Pattern
# ============================================================================

# Production -> Egress (for internet traffic)
resource "aws_ec2_transit_gateway_route" "production_to_egress" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.production.id
}

# Production -> Shared Services
resource "aws_ec2_transit_gateway_route" "production_to_shared" {
  destination_cidr_block         = var.shared_services_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.production.id
}

# Non-Production -> Egress (for internet traffic)
resource "aws_ec2_transit_gateway_route" "non_production_to_egress" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.non_production.id
}

# Non-Production -> Shared Services
resource "aws_ec2_transit_gateway_route" "non_production_to_shared" {
  destination_cidr_block         = var.shared_services_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.non_production.id
}

# Shared Services -> Production
resource "aws_ec2_transit_gateway_route" "shared_to_production" {
  destination_cidr_block         = var.prod_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.production.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
}

# Shared Services -> Non-Production
resource "aws_ec2_transit_gateway_route" "shared_to_non_production" {
  destination_cidr_block         = var.non_prod_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.non_production.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
}

# Shared Services -> Egress
resource "aws_ec2_transit_gateway_route" "shared_to_egress" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
}

# Egress -> Production
resource "aws_ec2_transit_gateway_route" "egress_to_production" {
  destination_cidr_block         = var.prod_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.production.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}

# Egress -> Non-Production
resource "aws_ec2_transit_gateway_route" "egress_to_non_production" {
  destination_cidr_block         = var.non_prod_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.non_production.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}

# Egress -> Shared Services
resource "aws_ec2_transit_gateway_route" "egress_to_shared" {
  destination_cidr_block         = var.shared_services_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}
