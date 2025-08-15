# SNS Topic for Invoice Processing Notifications
resource "aws_sns_topic" "invoice_processing_notifications" {
  name = var.sns_topic_name

  tags = {
    Name        = "Invoice Processing Notifications"
    Environment = "production"
    Purpose     = "invoice-processing"
    Application = "invoice-automation"
    ManagedBy   = "terraform"
  }
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "invoice_processing_policy" {
  arn = aws_sns_topic.invoice_processing_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.invoice_processing_notifications.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "email_notification" {
  topic_arn = aws_sns_topic.invoice_processing_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# SNS Topic Subscription for Lambda (optional - for additional processing)
resource "aws_sns_topic_subscription" "lambda_notification" {
  topic_arn = aws_sns_topic.invoice_processing_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.send_notification.arn
}

# Lambda permission for SNS to invoke notification function
resource "aws_lambda_permission" "allow_sns_invoke_notification" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_notification.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.invoice_processing_notifications.arn
}
