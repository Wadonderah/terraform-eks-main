terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region  = var.tf_region
  profile = var.tf_profile
  # Credentials will be automatically picked up from:
  # 1. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
  # 2. AWS CLI configuration (~/.aws/credentials)
  # 3. IAM roles (if running on EC2)
}

provider "random" {
  # Configuration options
}