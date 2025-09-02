# Enhanced S3 Configuration with Security and Lifecycle Policies

# S3 bucket for raw invoice uploads
resource "aws_s3_bucket" "raw_invoice_bucket" {
  bucket = local.raw_bucket_name

  tags = merge(local.common_tags, {
    Name        = "Raw Invoice Bucket"
    Purpose     = "invoice-uploads"
    DataClass   = "sensitive"
  })
}

# S3 bucket for processed invoice data
resource "aws_s3_bucket" "processed_invoice_bucket" {
  bucket = local.processed_bucket_name

  tags = merge(local.common_tags, {
    Name        = "Processed Invoice Bucket"
    Purpose     = "processed-invoices"
    DataClass   = "processed"
  })
}

# Lambda deployment bucket
resource "aws_s3_bucket" "lambda_s3_bucket" {
  bucket = "${local.name_prefix}-lambda-deployments-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name        = "Lambda Deployment Bucket"
    Purpose     = "lambda-code"
    DataClass   = "code"
  })
}

# Bucket versioning
resource "aws_s3_bucket_versioning" "raw_invoice_versioning" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "processed_invoice_versioning" {
  bucket = aws_s3_bucket.processed_invoice_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "lambda_versioning" {
  bucket = aws_s3_bucket.lambda_s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "raw_invoice_encryption" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.invoice_processing_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed_invoice_encryption" {
  bucket = aws_s3_bucket.processed_invoice_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.invoice_processing_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_encryption" {
  bucket = aws_s3_bucket.lambda_s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Public access block (security best practice)
resource "aws_s3_bucket_public_access_block" "raw_invoice_pab" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "processed_invoice_pab" {
  bucket = aws_s3_bucket.processed_invoice_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "lambda_pab" {
  bucket = aws_s3_bucket.lambda_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policies for secure access
resource "aws_s3_bucket_policy" "raw_invoice_policy" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

resource "aws_s3_bucket_policy" "processed_invoice_policy" {
  bucket = aws_s3_bucket.processed_invoice_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

# Lifecycle configurations for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "raw_invoice_lifecycle" {
  count  = var.s3_lifecycle_enabled ? 1 : 0
  bucket = aws_s3_bucket.raw_invoice_bucket.id

  rule {
    id     = "invoice_lifecycle"
    status = "Enabled"

    # Current version transitions
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    # Expiration for compliance (7 years)
    expiration {
      days = 2555
    }

    # Non-current version management
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    # Incomplete multipart upload cleanup
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "processed_invoice_lifecycle" {
  count  = var.s3_lifecycle_enabled ? 1 : 0
  bucket = aws_s3_bucket.processed_invoice_bucket.id

  rule {
    id     = "processed_invoice_lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555 # 7 years retention
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# S3 bucket notifications for Lambda triggers
resource "aws_s3_bucket_notification" "raw_invoice_notification" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.textract_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ""
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# Lambda permission for S3 to invoke function
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.textract_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_invoice_bucket.arn
}

# S3 bucket logging (optional but recommended for security)
resource "aws_s3_bucket" "access_logs" {
  bucket = "${local.name_prefix}-access-logs-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name        = "S3 Access Logs Bucket"
    Purpose     = "access-logs"
    DataClass   = "logs"
  })
}

resource "aws_s3_bucket_public_access_block" "access_logs_pab" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "raw_invoice_logging" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "raw-invoice-access-logs/"
}

resource "aws_s3_bucket_logging" "processed_invoice_logging" {
  bucket = aws_s3_bucket.processed_invoice_bucket.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "processed-invoice-access-logs/"
}

# S3 bucket metrics for monitoring
resource "aws_s3_bucket_metric" "raw_invoice_metrics" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id
  name   = "EntireBucket"
}

resource "aws_s3_bucket_metric" "processed_invoice_metrics" {
  bucket = aws_s3_bucket.processed_invoice_bucket.id
  name   = "EntireBucket"
}

# S3 bucket inventory for cost optimization
resource "aws_s3_bucket_inventory" "raw_invoice_inventory" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id
  name   = "EntireBucketDaily"

  included_object_versions = "All"

  schedule {
    frequency = "Daily"
  }

  destination {
    bucket {
      format     = "CSV"
      bucket_arn = aws_s3_bucket.access_logs.arn
      prefix     = "inventory/raw-invoices/"
    }
  }

  optional_fields = [
    "Size",
    "LastModifiedDate",
    "StorageClass",
    "ETag",
    "IsMultipartUploaded",
    "ReplicationStatus",
    "EncryptionStatus"
  ]
}

# Cross-region replication for disaster recovery (optional)
resource "aws_s3_bucket_replication_configuration" "raw_invoice_replication" {
  count  = var.enable_cross_region_replication ? 1 : 0
  role   = aws_iam_role.replication[0].arn
  bucket = aws_s3_bucket.raw_invoice_bucket.id

  rule {
    id     = "replicate_invoices"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.raw_invoice_backup[0].arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.invoice_processing_key.arn
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.raw_invoice_versioning]
}

# Backup bucket in different region (conditional)
resource "aws_s3_bucket" "raw_invoice_backup" {
  count    = var.enable_cross_region_replication ? 1 : 0
  bucket   = "${local.name_prefix}-raw-invoices-backup-${random_id.bucket_suffix.hex}"
  provider = aws.backup_region

  tags = merge(local.common_tags, {
    Name        = "Raw Invoice Backup Bucket"
    Purpose     = "disaster-recovery"
    DataClass   = "backup"
  })
}

# IAM role for replication (conditional)
resource "aws_iam_role" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  name  = "${local.name_prefix}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  name  = "${local.name_prefix}-s3-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl"
        ]
        Resource = "${aws_s3_bucket.raw_invoice_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.raw_invoice_bucket.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = "${aws_s3_bucket.raw_invoice_backup[0].arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "replication" {
  count      = var.enable_cross_region_replication ? 1 : 0
  role       = aws_iam_role.replication[0].name
  policy_arn = aws_iam_policy.replication[0].arn
}

# Add variable for cross-region replication
variable "enable_cross_region_replication" {
  type        = bool
  default     = false
  description = "Enable cross-region replication for disaster recovery"
}

# Provider for backup region (conditional)
provider "aws" {
  alias  = "backup_region"
  region = var.backup_region
}

variable "backup_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for backup replication"
}
