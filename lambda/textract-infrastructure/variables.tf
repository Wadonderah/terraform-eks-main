# Variables for Invoice Processing System

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = "default"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# S3 Variables
variable "raw_invoice_bucket_name" {
  description = "Name of the S3 bucket for raw invoice uploads"
  type        = string
  default     = "invoice-uploads"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.raw_invoice_bucket_name))
    error_message = "Bucket name must be lowercase, start and end with alphanumeric characters, and can contain hyphens."
  }
}

variable "processed_invoice_bucket_name" {
  description = "Name of the S3 bucket for processed invoice data"
  type        = string
  default     = "processed-invoices"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.processed_invoice_bucket_name))
    error_message = "Bucket name must be lowercase, start and end with alphanumeric characters, and can contain hyphens."
  }
}

# DynamoDB Variables
variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for storing invoice metadata"
  type        = string
  default     = "Invoices"
}

# SNS Variables
variable "sns_topic_name" {
  description = "Name of the SNS topic for invoice processing notifications"
  type        = string
  default     = "invoice-processing-notifications"
}

variable "notification_email" {
  description = "Email address for invoice processing notifications"
  type        = string
  default     = "admin@example.com"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Please provide a valid email address."
  }
}

# Lambda Variables
variable "textract_lambda_timeout" {
  description = "Timeout for Textract Lambda functions in seconds"
  type        = number
  default     = 300
  
  validation {
    condition     = var.textract_lambda_timeout >= 30 && var.textract_lambda_timeout <= 900
    error_message = "Lambda timeout must be between 30 and 900 seconds."
  }
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
