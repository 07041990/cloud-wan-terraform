terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.27.0"
    }
  }

  # S3 Backend Configuration
  # Uncomment and configure after creating the S3 bucket and DynamoDB table
  # backend "s3" {
  #   bucket         = "aws-assignment-wan-hubspoke-state"
  #   key            = "cloud-wan/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# Default provider for Network Hub account
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "aws-cloud-wan-terraform"
    }
  }
}

# Provider alias for Production account
provider "aws" {
  alias  = "production"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::119810927698:role/TerraformExecutionRole"
  }

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "production"
      ManagedBy   = "Terraform"
    }
  }
}

# Provider alias for Non-Production account
provider "aws" {
  alias  = "nonproduction"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.non_production_account_id}:role/TerraformExecutionRole"
  }

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "non-production"
      ManagedBy   = "Terraform"
    }
  }
}

# Provider alias for Shared Services account
provider "aws" {
  alias  = "shared"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.shared_services_account_id}:role/TerraformExecutionRole"
  }

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "shared-services"
      ManagedBy   = "Terraform"
    }
  }
}
