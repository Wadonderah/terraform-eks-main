# Cost-Optimized Variables

variable "cost_optimization_level" {
  type        = string
  default     = "aggressive"
  description = "Level of cost optimization: basic, moderate, aggressive"
  
  validation {
    condition     = contains(["basic", "moderate", "aggressive"], var.cost_optimization_level)
    error_message = "Cost optimization level must be basic, moderate, or aggressive."
  }
}

variable "monthly_budget_limit" {
  type        = number
  default     = 50
  description = "Monthly budget limit in USD"
  
  validation {
    condition     = var.monthly_budget_limit > 0 && var.monthly_budget_limit <= 1000
    error_message = "Monthly budget must be between $1 and $1000."
  }
}

variable "enable_cost_monitoring" {
  type        = bool
  default     = true
  description = "Enable cost monitoring and alerts"
}

variable "log_retention_days_cost_optimized" {
  type        = number
  default     = 3
  description = "CloudWatch log retention in days (cost optimized)"
  
  validation {
    condition     = contains([1, 3, 5, 7, 14], var.log_retention_days_cost_optimized)
    error_message = "Log retention must be 1, 3, 5, 7, or 14 days for cost optimization."
  }
}

variable "s3_lifecycle_transition_days" {
  type = object({
    standard_ia   = number
    glacier       = number
    deep_archive  = number
  })
  default = {
    standard_ia  = 7   # Move to IA after 7 days
    glacier      = 30  # Move to Glacier after 30 days
    deep_archive = 90  # Move to Deep Archive after 90 days
  }
  description = "S3 lifecycle transition days for cost optimization"
}

variable "lambda_memory_cost_optimized" {
  type        = number
  default     = 128
  description = "Lambda memory allocation for cost optimization (MB)"
  
  validation {
    condition     = var.lambda_memory_cost_optimized >= 128 && var.lambda_memory_cost_optimized <= 512
    error_message = "Lambda memory for cost optimization must be between 128 and 512 MB."
  }
}

variable "enable_intelligent_tiering" {
  type        = bool
  default     = true
  description = "Enable S3 Intelligent Tiering for automatic cost optimization"
}

variable "cleanup_frequency_days" {
  type        = number
  default     = 7
  description = "Frequency of cleanup operations in days"
  
  validation {
    condition     = var.cleanup_frequency_days >= 1 && var.cleanup_frequency_days <= 30
    error_message = "Cleanup frequency must be between 1 and 30 days."
  }
}

# Cost optimization configurations based on level
locals {
  cost_configs = {
    basic = {
      lambda_memory        = 256
      log_retention       = 7
      s3_ia_days         = 30
      s3_glacier_days    = 90
      s3_deep_archive_days = 365
      cleanup_days       = 30
    }
    moderate = {
      lambda_memory        = 192
      log_retention       = 5
      s3_ia_days         = 14
      s3_glacier_days    = 60
      s3_deep_archive_days = 180
      cleanup_days       = 14
    }
    aggressive = {
      lambda_memory        = 128
      log_retention       = 3
      s3_ia_days         = 7
      s3_glacier_days    = 30
      s3_deep_archive_days = 90
      cleanup_days       = 7
    }
  }
  
  selected_config = local.cost_configs[var.cost_optimization_level]
  
  # Ultra minimal tags for cost tracking
  cost_tags = {
    Project     = var.project_name
    Environment = var.environment
    CostCenter  = "finance"
  }
}

# Cost estimation outputs
output "estimated_monthly_costs" {
  description = "Estimated monthly costs breakdown"
  value = {
    lambda_invocations_1000 = "~$0.20"
    dynamodb_pay_per_request = "~$1.25 per million requests"
    s3_standard_storage_gb = "~$0.023 per GB"
    s3_intelligent_tiering = "~$0.0125 per 1000 objects"
    textract_pages = "~$1.50 per 1000 pages"
    total_estimated_light_usage = "~$5-15/month"
    total_estimated_heavy_usage = "~$25-50/month"
  }
}
