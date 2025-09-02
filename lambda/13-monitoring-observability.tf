# CloudWatch Dashboard for Invoice Processing System
resource "aws_cloudwatch_dashboard" "invoice_processing_dashboard" {
  dashboard_name = "InvoiceProcessingSystem"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.textract_processor.function_name],
            [".", "Errors", ".", "."],
            [".", "Invocations", ".", "."],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.store_extracted_data.function_name],
            [".", "Errors", ".", "."],
            [".", "Invocations", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.tf_region
          title   = "Lambda Function Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.lambda_dynamodb.name],
            [".", "ConsumedWriteCapacityUnits", ".", "."],
            [".", "ThrottledRequests", ".", "."]
          ]
          view   = "timeSeries"
          region = var.tf_region
          title  = "DynamoDB Metrics"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", aws_s3_bucket.raw_invoice_bucket.bucket, "StorageType", "StandardStorage"],
            [".", "NumberOfObjects", ".", ".", ".", "AllStorageTypes"]
          ]
          view   = "timeSeries"
          region = var.tf_region
          title  = "S3 Storage Metrics"
          period = 86400
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "invoice-lambda-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda error rate"
  alarm_actions       = [aws_sns_topic.invoice_processing_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.textract_processor.function_name
  }

  tags = {
    Environment = "production"
    Application = "invoice-automation"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "invoice-lambda-high-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "240000" # 4 minutes (240 seconds * 1000 ms)
  alarm_description   = "This metric monitors lambda duration"
  alarm_actions       = [aws_sns_topic.invoice_processing_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.textract_processor.function_name
  }

  tags = {
    Environment = "production"
    Application = "invoice-automation"
  }
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  alarm_name          = "invoice-dynamodb-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors DynamoDB throttles"
  alarm_actions       = [aws_sns_topic.invoice_processing_alerts.arn]

  dimensions = {
    TableName = aws_dynamodb_table.lambda_dynamodb.name
  }

  tags = {
    Environment = "production"
    Application = "invoice-automation"
  }
}

# SNS Topic for Alerts
resource "aws_sns_topic" "invoice_processing_alerts" {
  name = "invoice-processing-alerts"

  tags = {
    Environment = "production"
    Application = "invoice-automation"
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.invoice_processing_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# X-Ray Tracing for Lambda Functions
resource "aws_lambda_function" "textract_processor_with_xray" {
  filename         = data.archive_file.textract_processor_zip.output_path
  function_name    = "textract-processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "textract-processor.handler"
  source_code_hash = data.archive_file.textract_processor_zip.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = var.textract_lambda_timeout

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      ENVIRONMENT         = "production"
      LOG_LEVEL           = "info"
      SNS_TOPIC_ARN       = aws_sns_topic.invoice_processing_notifications.arn
      STORAGE_LAMBDA_NAME = "store-extracted-data"
      _X_AMZN_TRACE_ID    = "Root=1-5e1b4151-5ac6c58b1b5c6b5c6b5c6b5c"
    }
  }

  tags = {
    Environment = "production"
    Application = "invoice-automation"
    Function    = "textract-processing"
  }

  depends_on = [aws_lambda_function.textract_processor]
}

# Enhanced IAM policy for X-Ray
resource "aws_iam_role_policy_attachment" "lambda_xray_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Custom CloudWatch Log Groups with retention
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = {
    textract_processor     = aws_lambda_function.textract_processor.function_name
    store_extracted_data   = aws_lambda_function.store_extracted_data.function_name
    validate_invoice       = aws_lambda_function.validate_invoice.function_name
    process_invoice        = aws_lambda_function.process_invoice.function_name
    send_notification      = aws_lambda_function.send_notification.function_name
  }

  name              = "/aws/lambda/${each.value}"
  retention_in_days = 14

  tags = {
    Environment = "production"
    Application = "invoice-automation"
    Function    = each.key
  }
}

# CloudWatch Insights Queries
resource "aws_cloudwatch_query_definition" "lambda_errors" {
  name = "Invoice Processing - Lambda Errors"

  log_group_names = [
    "/aws/lambda/${aws_lambda_function.textract_processor.function_name}",
    "/aws/lambda/${aws_lambda_function.store_extracted_data.function_name}"
  ]

  query_string = <<EOF
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
EOF
}

resource "aws_cloudwatch_query_definition" "processing_duration" {
  name = "Invoice Processing - Duration Analysis"

  log_group_names = [
    "/aws/lambda/${aws_lambda_function.textract_processor.function_name}"
  ]

  query_string = <<EOF
fields @timestamp, @duration
| filter @type = "REPORT"
| stats avg(@duration), max(@duration), min(@duration) by bin(5m)
EOF
}
