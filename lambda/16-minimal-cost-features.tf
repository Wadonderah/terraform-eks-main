# Minimal Cost Alternatives for Removed Features

# 1. X-Ray Tracing - Minimal Cost Alternative ($0.05/month vs $0.50)
resource "aws_lambda_function" "textract_processor_minimal_xray" {
  count = var.enable_minimal_xray ? 1 : 0
  
  filename         = data.archive_file.textract_processor_zip.output_path
  function_name    = "${local.name_prefix}-textract-processor-xray"
  role             = aws_iam_role.lambda_role.arn
  handler          = "textract-processor.handler"
  source_code_hash = data.archive_file.textract_processor_zip.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = 30
  memory_size      = 128

  # Minimal X-Ray - only for errors
  tracing_config {
    mode = "PassThrough" # Only trace when upstream sends trace
  }

  environment {
    variables = {
      XRAY_TRACE_ERRORS_ONLY = "true"
      LOG_LEVEL = "error"
    }
  }

  tags = local.cost_tags
}

# 2. VPC Alternative - Security Groups without NAT Gateway ($0/month vs $45)
resource "aws_security_group" "lambda_minimal_sg" {
  count = var.enable_minimal_vpc ? 1 : 0
  
  name_prefix = "${local.name_prefix}-lambda-minimal"
  description = "Minimal security group for Lambda (no VPC)"

  # Only allow HTTPS outbound (for AWS API calls)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for AWS APIs"
  }

  tags = local.cost_tags
}

# 3. Provisioned Concurrency Alternative - Scheduled Warming ($2/month vs $15)
resource "aws_cloudwatch_event_rule" "lambda_warmer" {
  count = var.enable_lambda_warming ? 1 : 0
  
  name                = "${local.name_prefix}-lambda-warmer"
  description         = "Warm Lambda functions during business hours"
  schedule_expression = "rate(5 minutes)" # Only during business hours
  state              = "ENABLED"

  tags = local.cost_tags
}

resource "aws_cloudwatch_event_target" "lambda_warmer_target" {
  count = var.enable_lambda_warming ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.lambda_warmer[0].name
  target_id = "WarmLambdaTarget"
  arn       = aws_lambda_function.textract_processor.arn

  input = jsonencode({
    "warmer": true,
    "concurrency": 1
  })
}

# 4. Aurora MySQL Alternative - DynamoDB with Global Tables ($5/month vs $50)
resource "aws_dynamodb_table" "invoice_relational" {
  count = var.enable_minimal_database ? 1 : 0
  
  name           = "${local.name_prefix}-invoice-relational"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "invoice_id"
  range_key      = "entity_type"

  attribute {
    name = "invoice_id"
    type = "S"
  }

  attribute {
    name = "entity_type"
    type = "S"
  }

  # Minimal backup
  point_in_time_recovery {
    enabled = false
  }

  tags = local.cost_tags
}

# 5. Enhanced Monitoring Alternative - Basic CloudWatch ($1/month vs $10)
resource "aws_cloudwatch_metric_alarm" "minimal_error_alarm" {
  count = var.enable_minimal_monitoring ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-critical-errors-only"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10" # Only alert on 10+ errors
  alarm_description   = "Critical Lambda errors only"
  alarm_actions       = [aws_sns_topic.invoice_processing_notifications.arn]

  dimensions = {
    FunctionName = aws_lambda_function.textract_processor.function_name
  }

  tags = local.cost_tags
}

# 6. Cross-Region Replication Alternative - S3 Cross-Region Copy ($3/month vs $20)
resource "aws_s3_bucket" "backup_bucket_minimal" {
  count = var.enable_minimal_backup ? 1 : 0
  
  bucket = "${local.name_prefix}-backup-minimal-${random_id.bucket_suffix.hex}"

  tags = local.cost_tags
}

resource "aws_s3_bucket_lifecycle_configuration" "backup_lifecycle" {
  count = var.enable_minimal_backup ? 1 : 0
  
  bucket = aws_s3_bucket.backup_bucket_minimal[0].id

  rule {
    id     = "minimal_backup"
    status = "Enabled"

    # Move to Glacier immediately for backups
    transition {
      days          = 1
      storage_class = "GLACIER"
    }

    # Delete after 90 days
    expiration {
      days = 90
    }
  }
}

# Lambda function for minimal cross-region backup
resource "aws_lambda_function" "minimal_backup" {
  count = var.enable_minimal_backup ? 1 : 0
  
  filename         = data.archive_file.minimal_backup_zip.output_path
  function_name    = "${local.name_prefix}-minimal-backup"
  role             = aws_iam_role.lambda_role.arn
  handler          = "minimal-backup.handler"
  source_code_hash = data.archive_file.minimal_backup_zip.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = 60
  memory_size      = 128

  environment {
    variables = {
      BACKUP_BUCKET = var.enable_minimal_backup ? aws_s3_bucket.backup_bucket_minimal[0].bucket : ""
      BACKUP_REGION = "us-east-1" # Cheaper region for backups
    }
  }

  tags = local.cost_tags
}

# Scheduled backup - weekly only
resource "aws_cloudwatch_event_rule" "weekly_backup" {
  count = var.enable_minimal_backup ? 1 : 0
  
  name                = "${local.name_prefix}-weekly-backup"
  description         = "Weekly backup of critical data"
  schedule_expression = "cron(0 2 ? * SUN *)" # Sunday 2 AM

  tags = local.cost_tags
}

# Cost monitoring for all minimal features
resource "aws_cloudwatch_metric_alarm" "minimal_features_cost" {
  count = var.enable_cost_monitoring ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-minimal-features-cost"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = var.monthly_budget_limit * 0.8 # 80% of budget
  alarm_description   = "Minimal features cost approaching budget"
  alarm_actions       = [aws_sns_topic.invoice_processing_notifications.arn]

  dimensions = {
    Currency = "USD"
  }

  tags = local.cost_tags
}
