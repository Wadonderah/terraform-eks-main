# S3 Lifecycle Policies for Cost Optimization
resource "aws_s3_bucket_lifecycle_configuration" "raw_invoice_lifecycle" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id

  rule {
    id     = "invoice_lifecycle"
    status = "Enabled"

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

    expiration {
      days = 2555 # 7 years retention for compliance
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "processed_invoice_lifecycle" {
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
  }
}

# DynamoDB Auto Scaling
resource "aws_appautoscaling_target" "dynamodb_table_read_target" {
  max_capacity       = 100
  min_capacity       = 5
  resource_id        = "table/${aws_dynamodb_table.lambda_dynamodb.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_target" "dynamodb_table_write_target" {
  max_capacity       = 100
  min_capacity       = 5
  resource_id        = "table/${aws_dynamodb_table.lambda_dynamodb.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_table_read_policy" {
  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.dynamodb_table_read_target.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_table_read_target.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_table_read_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_table_read_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70
  }
}

resource "aws_appautoscaling_policy" "dynamodb_table_write_policy" {
  name               = "DynamoDBWriteCapacityUtilization:${aws_appautoscaling_target.dynamodb_table_write_target.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_table_write_target.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_table_write_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_table_write_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70
  }
}

# Lambda Reserved Concurrency for cost control
resource "aws_lambda_provisioned_concurrency_config" "textract_processor_concurrency" {
  function_name                     = aws_lambda_function.textract_processor.function_name
  provisioned_concurrent_executions = 2
  qualifier                         = aws_lambda_function.textract_processor.version
}

# Lambda Function URLs for direct invocation (cost-effective alternative to API Gateway for simple use cases)
resource "aws_lambda_function_url" "textract_processor_url" {
  function_name      = aws_lambda_function.textract_processor.function_name
  authorization_type = "AWS_IAM"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["date", "keep-alive"]
    max_age          = 86400
  }
}

# EventBridge Rules for scheduled cleanup (cost optimization)
resource "aws_cloudwatch_event_rule" "cleanup_old_logs" {
  name                = "cleanup-old-invoice-logs"
  description         = "Trigger cleanup of old CloudWatch logs"
  schedule_expression = "rate(7 days)"

  tags = {
    Environment = "production"
    Application = "invoice-automation"
  }
}

# Lambda function for cleanup operations
resource "aws_lambda_function" "cleanup_function" {
  filename         = data.archive_file.cleanup_zip.output_path
  function_name    = "invoice-cleanup"
  role             = aws_iam_role.cleanup_lambda_role.arn
  handler          = "cleanup.handler"
  source_code_hash = data.archive_file.cleanup_zip.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = 300

  environment {
    variables = {
      ENVIRONMENT = "production"
      LOG_LEVEL   = "info"
    }
  }

  tags = {
    Environment = "production"
    Application = "invoice-automation"
    Function    = "cleanup"
  }
}

# Archive for cleanup function
data "archive_file" "cleanup_zip" {
  type        = "zip"
  output_path = "${path.module}/script/cleanup.zip"
  
  source {
    content = <<EOF
const AWS = require('aws-sdk');
const cloudwatchlogs = new AWS.CloudWatchLogs();

exports.handler = async (event) => {
    console.log('Starting cleanup process...');
    
    try {
        // Add cleanup logic here
        // Example: Delete old log streams, clean up temporary files, etc.
        
        return {
            statusCode: 200,
            body: JSON.stringify({ message: 'Cleanup completed successfully' })
        };
    } catch (error) {
        console.error('Cleanup error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: error.message })
        };
    }
};
EOF
    filename = "cleanup.js"
  }
}

# IAM role for cleanup function
resource "aws_iam_role" "cleanup_lambda_role" {
  name = "cleanup_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cleanup_lambda_policy" {
  name = "cleanup_lambda_policy"
  role = aws_iam_role.cleanup_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DeleteLogStream",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.raw_invoice_bucket.arn,
          "${aws_s3_bucket.raw_invoice_bucket.arn}/*"
        ]
      }
    ]
  })
}

# EventBridge target
resource "aws_cloudwatch_event_target" "cleanup_target" {
  rule      = aws_cloudwatch_event_rule.cleanup_old_logs.name
  target_id = "CleanupLambdaTarget"
  arn       = aws_lambda_function.cleanup_function.arn
}

resource "aws_lambda_permission" "allow_eventbridge_cleanup" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cleanup_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cleanup_old_logs.arn
}

# Cost allocation tags for better cost tracking
locals {
  common_tags = {
    Environment   = "production"
    Application   = "invoice-automation"
    ManagedBy     = "terraform"
    CostCenter    = "finance"
    Owner         = "wadondera@gmail.com"
    Project       = "invoice-processing-system"
    CreatedDate   = formatdate("YYYY-MM-DD", timestamp())
  }
}

# Apply tags to existing resources (example for S3)
resource "aws_s3_bucket_tagging" "raw_invoice_bucket_tags" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id
  
  tag_set = local.common_tags
}

resource "aws_s3_bucket_tagging" "processed_invoice_bucket_tags" {
  bucket = aws_s3_bucket.processed_invoice_bucket.id
  
  tag_set = local.common_tags
}
