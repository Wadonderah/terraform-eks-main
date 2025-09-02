# Enhanced Variables with Validation
variable "tf_region" {
  type        = string
  default     = "ca-central-1"
  description = "AWS Region for deployment"
  
  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.tf_region))
    error_message = "Region must be a valid AWS region format (e.g., us-east-1, ca-central-1)."
  }
}

variable "tf_profile" {
  type        = string
  default     = "default"
  description = "AWS CLI profile to use"
  
  validation {
    condition     = length(var.tf_profile) > 0
    error_message = "AWS profile cannot be empty."
  }
}

variable "environment" {
  type        = string
  default     = "production"
  description = "Environment name (dev, staging, production)"
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "project_name" {
  type        = string
  default     = "invoice-processing"
  description = "Project name for resource naming"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "lambda_dynamoDB" {
  type        = string
  default     = "lambda_invoice_dynamoDB"
  description = "DynamoDB table name for invoice data"
  
  validation {
    condition     = length(var.lambda_dynamoDB) >= 3 && length(var.lambda_dynamoDB) <= 255
    error_message = "DynamoDB table name must be between 3 and 255 characters."
  }
}

variable "lambda_aurora_mysql_name" {
  type        = string
  default     = "aurora-cluster-db"
  description = "Aurora MySQL cluster name"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.lambda_aurora_mysql_name))
    error_message = "Aurora cluster name must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "lambda_aurora_mysql_database_name" {
  type        = string
  default     = "aurorainvoicedb"
  description = "Aurora MySQL database name"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.lambda_aurora_mysql_database_name))
    error_message = "Database name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "textract_lambda_timeout" {
  type        = number
  default     = 300
  description = "Timeout for Textract Lambda function in seconds"
  
  validation {
    condition     = var.textract_lambda_timeout >= 30 && var.textract_lambda_timeout <= 900
    error_message = "Lambda timeout must be between 30 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  type        = number
  default     = 512
  description = "Memory allocation for Lambda functions in MB"
  
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory must be between 128 and 10240 MB."
  }
}

variable "raw_invoice_bucket_name" {
  type        = string
  default     = "invoice-uploads"
  description = "Name of the S3 bucket for raw invoice uploads"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.raw_invoice_bucket_name))
    error_message = "S3 bucket name must be lowercase, start and end with alphanumeric characters, and can contain hyphens."
  }
}

variable "processed_invoice_bucket_name" {
  type        = string
  default     = "processed-invoices"
  description = "Name of the S3 bucket for processed invoice data"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.processed_invoice_bucket_name))
    error_message = "S3 bucket name must be lowercase, start and end with alphanumeric characters, and can contain hyphens."
  }
}

variable "sns_topic_name" {
  type        = string
  default     = "invoice-processing-notifications"
  description = "Name of the SNS topic for invoice processing notifications"
  
  validation {
    condition     = length(var.sns_topic_name) <= 256
    error_message = "SNS topic name must be 256 characters or less."
  }
}

variable "notification_email" {
  type        = string
  default     = "admin@example.com"
  description = "Email address for invoice processing notifications"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Must be a valid email address."
  }
}

variable "enable_vpc" {
  type        = bool
  default     = false
  description = "Enable VPC for Lambda functions (recommended for production)"
}

variable "enable_xray_tracing" {
  type        = bool
  default     = true
  description = "Enable AWS X-Ray tracing for Lambda functions"
}

variable "enable_enhanced_monitoring" {
  type        = bool
  default     = true
  description = "Enable enhanced monitoring and alerting"
}

variable "log_retention_days" {
  type        = number
  default     = 14
  description = "CloudWatch log retention period in days"
  
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "dynamodb_billing_mode" {
  type        = string
  default     = "PAY_PER_REQUEST"
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)"
  
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "DynamoDB billing mode must be either PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "s3_lifecycle_enabled" {
  type        = bool
  default     = true
  description = "Enable S3 lifecycle policies for cost optimization"
}

variable "backup_retention_days" {
  type        = number
  default     = 30
  description = "Number of days to retain backups"
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

variable "allowed_file_types" {
  type        = list(string)
  default     = ["pdf", "png", "jpg", "jpeg", "tiff", "tif"]
  description = "Allowed file types for invoice processing"
  
  validation {
    condition     = length(var.allowed_file_types) > 0
    error_message = "At least one file type must be allowed."
  }
}

variable "max_file_size_mb" {
  type        = number
  default     = 10
  description = "Maximum file size in MB for invoice processing"
  
  validation {
    condition     = var.max_file_size_mb > 0 && var.max_file_size_mb <= 100
    error_message = "Maximum file size must be between 1 and 100 MB."
  }
}

variable "cost_center" {
  type        = string
  default     = "finance"
  description = "Cost center for billing and tagging"
}

variable "owner_email" {
  type        = string
  default     = "wadondera@gmail.com"
  description = "Owner email for resource tagging and notifications"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner_email))
    error_message = "Must be a valid email address."
  }
}

# Local values for computed configurations
locals {
  # Common tags applied to all resources
  common_tags = {
    Environment   = var.environment
    Project       = var.project_name
    ManagedBy     = "terraform"
    CostCenter    = var.cost_center
    Owner         = var.owner_email
    CreatedDate   = formatdate("YYYY-MM-DD", timestamp())
    Region        = var.tf_region
  }
  
  # Resource naming convention
  name_prefix = "${var.project_name}-${var.environment}"
  
  # S3 bucket names with random suffix for uniqueness
  raw_bucket_name       = "${local.name_prefix}-${var.raw_invoice_bucket_name}-${random_id.bucket_suffix.hex}"
  processed_bucket_name = "${local.name_prefix}-${var.processed_invoice_bucket_name}-${random_id.bucket_suffix.hex}"
  
  # Lambda function names
  lambda_functions = {
    textract_processor     = "${local.name_prefix}-textract-processor"
    store_extracted_data   = "${local.name_prefix}-store-extracted-data"
    validate_invoice       = "${local.name_prefix}-validate-invoice"
    process_invoice        = "${local.name_prefix}-process-invoice"
    send_notification      = "${local.name_prefix}-send-notification"
    cleanup_function       = "${local.name_prefix}-cleanup"
  }
}

# Random ID for unique resource naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Output important computed values
output "computed_values" {
  description = "Computed configuration values"
  value = {
    name_prefix           = local.name_prefix
    raw_bucket_name       = local.raw_bucket_name
    processed_bucket_name = local.processed_bucket_name
    lambda_functions      = local.lambda_functions
    common_tags           = local.common_tags
  }
}
