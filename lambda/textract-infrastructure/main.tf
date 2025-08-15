# Main Terraform configuration for Invoice Processing System
# This file serves as the entry point for the modular structure

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "Invoice Processing System"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  common_tags = {
    Project     = "Invoice Processing System"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  
  bucket_suffix = random_id.bucket_suffix.hex
}

# Random ID for unique resource naming
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# S3 Buckets Module
module "s3_buckets" {
  source = "./modules/s3"
  
  raw_bucket_name       = "${var.raw_invoice_bucket_name}-${local.bucket_suffix}"
  processed_bucket_name = "${var.processed_invoice_bucket_name}-${local.bucket_suffix}"
  
  tags = local.common_tags
}

# DynamoDB Module
module "dynamodb" {
  source = "./modules/dynamodb"
  
  table_name = var.dynamodb_table_name
  
  tags = local.common_tags
}

# SNS Module
module "sns" {
  source = "./modules/sns"
  
  topic_name         = var.sns_topic_name
  notification_email = var.notification_email
  
  tags = local.common_tags
}

# Lambda Module
module "lambda" {
  source = "./modules/lambda"
  
  raw_bucket_name       = module.s3_buckets.raw_bucket_name
  processed_bucket_name = module.s3_buckets.processed_bucket_name
  dynamodb_table_name   = module.dynamodb.table_name
  sns_topic_arn         = module.sns.topic_arn
  
  lambda_timeout = var.textract_lambda_timeout
  
  tags = local.common_tags
  
  depends_on = [
    module.s3_buckets,
    module.dynamodb,
    module.sns
  ]
}

# S3 Event Notifications
resource "aws_s3_bucket_notification" "raw_invoice_notification" {
  bucket = module.s3_buckets.raw_bucket_name

  lambda_function {
    lambda_function_arn = module.lambda.textract_processor_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ""
  }

  depends_on = [module.lambda]
}

# Step Functions Module
module "step_functions" {
  source = "./modules/step-functions"
  
  validate_invoice_arn    = module.lambda.validate_invoice_arn
  process_invoice_arn     = module.lambda.process_invoice_arn
  send_notification_arn   = module.lambda.send_notification_arn
  
  tags = local.common_tags
  
  depends_on = [module.lambda]
}
