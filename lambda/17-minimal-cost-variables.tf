# Variables for Minimal Cost Features

variable "enable_minimal_xray" {
  type        = bool
  default     = true
  description = "Enable minimal X-Ray tracing (errors only) - $0.05/month vs $0.50"
}

variable "enable_minimal_vpc" {
  type        = bool
  default     = true
  description = "Enable minimal VPC security (security groups only) - $0/month vs $45"
}

variable "enable_lambda_warming" {
  type        = bool
  default     = true
  description = "Enable Lambda warming during business hours - $2/month vs $15"
}

variable "enable_minimal_database" {
  type        = bool
  default     = true
  description = "Enable DynamoDB as Aurora alternative - $5/month vs $50"
}

variable "enable_minimal_monitoring" {
  type        = bool
  default     = true
  description = "Enable basic monitoring (critical errors only) - $1/month vs $10"
}

variable "enable_minimal_backup" {
  type        = bool
  default     = true
  description = "Enable weekly S3 backup to cheaper region - $3/month vs $20"
}

# Cost comparison output
output "cost_comparison" {
  description = "Cost comparison between removed features and minimal alternatives"
  value = {
    xray_tracing = {
      removed = "$0.50/month (full tracing)"
      minimal = "$0.05/month (errors only)"
      savings = "90% cost reduction"
    }
    vpc_deployment = {
      removed = "$45/month (NAT Gateway)"
      minimal = "$0/month (security groups only)"
      savings = "100% cost reduction"
    }
    provisioned_concurrency = {
      removed = "$15/month (24/7 warm)"
      minimal = "$2/month (business hours warming)"
      savings = "87% cost reduction"
    }
    aurora_mysql = {
      removed = "$50/month (Aurora cluster)"
      minimal = "$5/month (DynamoDB relational)"
      savings = "90% cost reduction"
    }
    enhanced_monitoring = {
      removed = "$10/month (full monitoring)"
      minimal = "$1/month (critical alerts only)"
      savings = "90% cost reduction"
    }
    cross_region_replication = {
      removed = "$20/month (real-time replication)"
      minimal = "$3/month (weekly backup)"
      savings = "85% cost reduction"
    }
    total_monthly_savings = {
      removed_total = "$140/month"
      minimal_total = "$11/month"
      total_savings = "$129/month (92% reduction)"
    }
  }
}

# Feature toggle for easy deployment
variable "deploy_minimal_features" {
  type        = bool
  default     = true
  description = "Deploy all minimal cost features as a bundle"
}

# Conditional locals based on bundle deployment
locals {
  minimal_features_enabled = var.deploy_minimal_features ? {
    xray        = true
    vpc         = true
    warming     = true
    database    = true
    monitoring  = true
    backup      = true
  } : {
    xray        = var.enable_minimal_xray
    vpc         = var.enable_minimal_vpc
    warming     = var.enable_lambda_warming
    database    = var.enable_minimal_database
    monitoring  = var.enable_minimal_monitoring
    backup      = var.enable_minimal_backup
  }
}
