# ============================================================================
# AWS Organizations Service Control Policies (SCPs) for PCI-Isolated Workloads
# ============================================================================
# This file implements comprehensive SCPs for PCI compliance including:
# - Service restrictions
# - Region restrictions
# - Network exposure controls
# - Encryption enforcement
# - Public access prevention
# - Instance type allowlisting
# ============================================================================

# ============================================================================
# Data Sources
# ============================================================================

data "aws_organizations_organization" "main" {}

# ============================================================================
# Variables for SCP Configuration
# ============================================================================

locals {
  # Approved AWS Regions for PCI workloads
  approved_regions = [
    "us-east-1",
    "us-west-2",
    "eu-west-1"
  ]

  # Approved EC2 instance types for PCI workloads
  approved_instance_types = [
    "t3.medium",
    "t3.large",
    "m5.large",
    "m5.xlarge",
    "m5.2xlarge",
    "c5.large",
    "c5.xlarge",
    "r5.large",
    "r5.xlarge"
  ]

  # Disallowed services for PCI workloads
  disallowed_services = [
    "lightsail",
    "gamelift",
    "sumerian",
    "chime",
    "workmail",
    "workdocs",
    "workspaces",
    "appstream",
    "comprehend",
    "forecast",
    "personalize",
    "textract",
    "transcribe",
    "translate"
  ]
}

# ============================================================================
# PCI Organizational Unit
# ============================================================================

resource "aws_organizations_organizational_unit" "pci" {
  name      = "PCI-Isolated-Workloads"
  parent_id = data.aws_organizations_organization.main.roots[0].id

  tags = {
    Compliance = "PCI-DSS"
    Environment = "Production"
    Criticality = "High"
  }
}

# ============================================================================
# SCP 1: Region Restriction Policy
# ============================================================================

resource "aws_organizations_policy" "region_restriction" {
  name        = "PCI-Region-Restriction"
  description = "Restrict PCI workloads to approved AWS regions only"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAllOutsideApprovedRegions"
        Effect = "Deny"
        NotAction = [
          # Global services that don't have region context
          "iam:*",
          "organizations:*",
          "route53:*",
          "budgets:*",
          "waf:*",
          "cloudfront:*",
          "globalaccelerator:*",
          "importexport:*",
          "support:*",
          "trustedadvisor:*",
          "health:*"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = local.approved_regions
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "region_restriction" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = aws_organizations_organizational_unit.pci.id
}

# ============================================================================
# SCP 2: Disallow Unapproved Services
# ============================================================================

resource "aws_organizations_policy" "disallow_services" {
  name        = "PCI-Disallow-Unapproved-Services"
  description = "Block access to non-approved services for PCI workloads"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyUnapprovedServices"
        Effect   = "Deny"
        Action   = [for service in local.disallowed_services : "${service}:*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "disallow_services" {
  policy_id = aws_organizations_policy.disallow_services.id
  target_id = aws_organizations_organizational_unit.pci.id
}

# ============================================================================
# SCP 3: Prevent Public S3 Buckets
# ============================================================================

resource "aws_organizations_policy" "prevent_public_s3" {
  name        = "PCI-Prevent-Public-S3"
  description = "Block creation of public S3 buckets and public ACLs"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPublicS3Buckets"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPublicAccessBlock",
          "s3:PutAccountPublicAccessBlock"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-acl" = "private"
          }
        }
      },
      {
        Sid    = "DenyPublicACLs"
        Effect = "Deny"
        Action = [
          "s3:PutObjectAcl",
          "s3:PutBucketAcl"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "s3:x-amz-acl" = [
              "public-read",
              "public-read-write",
              "authenticated-read"
            ]
          }
        }
      },
      {
        Sid    = "DenyPublicBucketPolicy"
        Effect = "Deny"
        Action = "s3:PutBucketPolicy"
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:x-amz-grant-read" = "*"
          }
        }
      },
      {
        Sid    = "RequireS3Encryption"
        Effect = "Deny"
        Action = "s3:PutObject"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = [
              "AES256",
              "aws:kms"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "prevent_public_s3" {
  policy_id = aws_organizations_policy.prevent_public_s3.id
  target_id = aws_organizations_organizational_unit.pci.id
}

# ============================================================================
# SCP 4: Block Public Network Creation
# ============================================================================

resource "aws_organizations_policy" "block_public_networking" {
  name        = "PCI-Block-Public-Networking"
  description = "Prevent creation of IGW, NAT, public subnets, and EIPs"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInternetGatewayCreation"
        Effect = "Deny"
        Action = [
          "ec2:CreateInternetGateway",
          "ec2:AttachInternetGateway"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyNATGatewayCreation"
        Effect = "Deny"
        Action = [
          "ec2:CreateNatGateway"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyElasticIPAllocation"
        Effect = "Deny"
        Action = [
          "ec2:AllocateAddress",
          "ec2:AssociateAddress"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:Domain" = "vpc"
          }
        }
      },
      {
        Sid    = "DenyPublicSubnetCreation"
        Effect = "Deny"
        Action = [
          "ec2:ModifySubnetAttribute"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:MapPublicIpOnLaunch" = "true"
          }
        }
      },
      {
        Sid    = "DenyOpenSecurityGroups"
        Effect = "Deny"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:CidrIp" = "0.0.0.0/0"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "block_public_networking" {
  policy_id = aws_organizations_policy.block_public_networking.id
  target_id = aws_organizations_organizational_unit.pci.id
}

# ============================================================================
# SCP 5: Enforce Encryption
# ============================================================================

resource "aws_organizations_policy" "enforce_encryption" {
  name        = "PCI-Enforce-Encryption"
  description = "Require encryption for all storage services (S3, EBS, RDS)"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnencryptedEBSVolumes"
        Effect = "Deny"
        Action = [
          "ec2:CreateVolume",
          "ec2:RunInstances"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "ec2:Encrypted" = "false"
          }
        }
      },
      {
        Sid    = "DenyUnencryptedRDSInstances"
        Effect = "Deny"
        Action = [
          "rds:CreateDBInstance",
          "rds:CreateDBCluster"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "rds:StorageEncrypted" = "false"
          }
        }
      },
      {
        Sid    = "DenyUnencryptedS3Objects"
        Effect = "Deny"
        Action = "s3:PutObject"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = [
              "AES256",
              "aws:kms"
            ]
          }
        }
      },
      {
        Sid    = "DenyUnencryptedEFSFileSystems"
        Effect = "Deny"
        Action = "elasticfilesystem:CreateFileSystem"
        Resource = "*"
        Condition = {
          Bool = {
            "elasticfilesystem:Encrypted" = "false"
          }
        }
      },
      {
        Sid    = "DenyUnencryptedDynamoDBTables"
        Effect = "Deny"
        Action = "dynamodb:CreateTable"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "dynamodb:EncryptionType" = "KMS"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "enforce_encryption" {
  policy_id = aws_organizations_policy.enforce_encryption.id
  target_id = aws_organizations_organizational_unit.pci.id
}

# ============================================================================
# SCP 6: Mandatory VPC and TGW Flow Logs
# ============================================================================

resource "aws_organizations_policy" "mandatory_flow_logs" {
  name        = "PCI-Mandatory-Flow-Logs"
  description = "Prevent disabling of VPC Flow Logs and TGW Flow Logs"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyVPCFlowLogDeletion"
        Effect = "Deny"
        Action = [
          "ec2:DeleteFlowLogs"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyVPCCreationWithoutFlowLogs"
        Effect = "Deny"
        Action = "ec2:CreateVpc"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestTag/FlowLogsEnabled" = "true"
          }
        }
      },
      {
        Sid    = "DenyCloudWatchLogGroupDeletion"
        Effect = "Deny"
        Action = [
          "logs:DeleteLogGroup",
          "logs:DeleteLogStream"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Purpose" = "*FlowLogs*"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "mandatory_flow_logs" {
  policy_id = aws_organizations_policy.mandatory_flow_logs.id
  target_id = aws_organizations_organizational_unit.pci.id
}

# ============================================================================
# SCP 7: Instance Type Allowlist
# ============================================================================

resource "aws_organizations_policy" "instance_type_allowlist" {
  name        = "PCI-Instance-Type-Allowlist"
  description = "Only allow approved EC2 instance types for PCI workloads"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnapprovedInstanceTypes"
        Effect = "Deny"
        Action = [
          "ec2:RunInstances",
          "ec2:StartInstances"
        ]
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringNotLike = {
            "ec2:InstanceType" = local.approved_instance_types
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "instance_type_allowlist" {
  policy_id = aws_organizations_policy.instance_type_allowlist.id
  target_id = aws_organizations_organizational_unit.pci.id
}

# ============================================================================
# SCP 8: Prevent Security Control Modifications
# ============================================================================

resource "aws_organizations_policy" "prevent_security_modifications" {
  name        = "PCI-Prevent-Security-Modifications"
  description = "Prevent disabling of security controls and monitoring"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyCloudTrailDeletion"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "cloudtrail:UpdateTrail"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyConfigDeletion"
        Effect = "Deny"
        Action = [
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "config:StopConfigurationRecorder"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyGuardDutyDisable"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "guardduty:DisassociateFromMasterAccount",
          "guardduty:StopMonitoringMembers",
          "guardduty:UpdateDetector"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenySecurityHubDisable"
        Effect = "Deny"
        Action = [
          "securityhub:DisableSecurityHub",
          "securityhub:DeleteInsight",
          "securityhub:UpdateSecurityHubConfiguration"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "prevent_security_modifications" {
  policy_id = aws_organizations_policy.prevent_security_modifications.id
  target_id = aws_organizations_organizational_unit.pci.id
}

# ============================================================================
# SCP 9: Require MFA for Sensitive Operations
# ============================================================================

resource "aws_organizations_policy" "require_mfa" {
  name        = "PCI-Require-MFA"
  description = "Require MFA for sensitive operations"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAllExceptListedIfNoMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "require_mfa" {
  policy_id = aws_organizations_policy.require_mfa.id
  target_id = aws_organizations_organizational_unit.pci.id
}

# ============================================================================
# SCP 10: Prevent Root User Actions
# ============================================================================

resource "aws_organizations_policy" "prevent_root_actions" {
  name        = "PCI-Prevent-Root-Actions"
  description = "Prevent root user from performing most actions"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyRootUserActions"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "iam:ChangePassword",
          "iam:GetAccountPasswordPolicy",
          "iam:GetAccountSummary",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "prevent_root_actions" {
  policy_id = aws_organizations_policy.prevent_root_actions.id
  target_id = aws_organizations_organizational_unit.pci.id
}

# ============================================================================
# Outputs
# ============================================================================

output "pci_ou_id" {
  description = "ID of the PCI Organizational Unit"
  value       = aws_organizations_organizational_unit.pci.id
}

output "pci_ou_arn" {
  description = "ARN of the PCI Organizational Unit"
  value       = aws_organizations_organizational_unit.pci.arn
}

output "scp_policies" {
  description = "Map of all SCP policy IDs"
  value = {
    region_restriction            = aws_organizations_policy.region_restriction.id
    disallow_services            = aws_organizations_policy.disallow_services.id
    prevent_public_s3            = aws_organizations_policy.prevent_public_s3.id
    block_public_networking      = aws_organizations_policy.block_public_networking.id
    enforce_encryption           = aws_organizations_policy.enforce_encryption.id
    mandatory_flow_logs          = aws_organizations_policy.mandatory_flow_logs.id
    instance_type_allowlist      = aws_organizations_policy.instance_type_allowlist.id
    prevent_security_modifications = aws_organizations_policy.prevent_security_modifications.id
    require_mfa                  = aws_organizations_policy.require_mfa.id
    prevent_root_actions         = aws_organizations_policy.prevent_root_actions.id
  }
}

output "approved_regions" {
  description = "List of approved AWS regions for PCI workloads"
  value       = local.approved_regions
}

output "approved_instance_types" {
  description = "List of approved EC2 instance types for PCI workloads"
  value       = local.approved_instance_types
}

output "scp_summary" {
  description = "Summary of SCP enforcement"
  value = {
    total_scps_applied = 10
    enforcement_areas = [
      "Region Restriction",
      "Service Disallowance",
      "Public S3 Prevention",
      "Public Networking Block",
      "Encryption Enforcement",
      "Mandatory Flow Logs",
      "Instance Type Allowlist",
      "Security Control Protection",
      "MFA Requirement",
      "Root User Restriction"
    ]
    compliance_framework = "PCI-DSS"
    cloudtrail_logging   = "All SCP violations logged in CloudTrail"
  }
}
