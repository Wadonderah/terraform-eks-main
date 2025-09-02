# Ultra Cost-Effective Configuration

# Override DynamoDB with pay-per-request
resource "aws_dynamodb_table" "lambda_dynamodb" {
  name         = var.lambda_dynamoDB
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "invoiceId"
  range_key    = "timestamp"

  attribute {
    name = "invoiceId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false
  }

  tags = {
    Environment = "production"
    Application = "invoice-automation"
    ManagedBy   = "terraform"
  }
}

# Aggressive S3 lifecycle
resource "aws_s3_bucket_lifecycle_configuration" "ultra_cost_lifecycle" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id

  rule {
    id     = "ultra_cost_optimization"
    status = "Enabled"

    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555
    }

    noncurrent_version_transition {
      noncurrent_days = 7
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Cost monitoring alarm
resource "aws_cloudwatch_metric_alarm" "cost_alarm" {
  alarm_name          = "invoice-processing-cost-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = "10"
  alarm_description   = "Invoice processing daily cost exceeded $10"
  alarm_actions       = [aws_sns_topic.invoice_processing_notifications.arn]

  dimensions = {
    Currency = "USD"
  }
}
