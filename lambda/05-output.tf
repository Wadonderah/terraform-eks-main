# Lambda Function Outputs
output "validate_invoice_function_name" {
  description = "Name of the invoice validation Lambda function"
  value       = aws_lambda_function.validate_invoice.function_name
}

output "validate_invoice_function_arn" {
  description = "ARN of the invoice validation Lambda function"
  value       = aws_lambda_function.validate_invoice.arn
}

output "process_invoice_function_name" {
  description = "Name of the invoice processing Lambda function"
  value       = aws_lambda_function.process_invoice.function_name
}

output "process_invoice_function_arn" {
  description = "ARN of the invoice processing Lambda function"
  value       = aws_lambda_function.process_invoice.arn
}

output "send_notification_function_name" {
  description = "Name of the notification Lambda function"
  value       = aws_lambda_function.send_notification.function_name
}

output "send_notification_function_arn" {
  description = "ARN of the notification Lambda function"
  value       = aws_lambda_function.send_notification.arn
}

# New Textract Lambda Functions
output "textract_processor_function_name" {
  description = "Name of the Textract processor Lambda function"
  value       = aws_lambda_function.textract_processor.function_name
}

output "textract_processor_function_arn" {
  description = "ARN of the Textract processor Lambda function"
  value       = aws_lambda_function.textract_processor.arn
}

output "store_extracted_data_function_name" {
  description = "Name of the data storage Lambda function"
  value       = aws_lambda_function.store_extracted_data.function_name
}

output "store_extracted_data_function_arn" {
  description = "ARN of the data storage Lambda function"
  value       = aws_lambda_function.store_extracted_data.arn
}

# Step Functions Outputs
output "step_function_arn" {
  description = "ARN of the invoice automation Step Functions state machine"
  value       = aws_sfn_state_machine.invoice_automation.arn
}

output "step_function_name" {
  description = "Name of the invoice automation Step Functions state machine"
  value       = aws_sfn_state_machine.invoice_automation.name
}

# S3 Bucket Outputs
output "raw_invoice_bucket_name" {
  description = "Name of the S3 bucket for raw invoice uploads"
  value       = aws_s3_bucket.raw_invoice_bucket.bucket
}

output "raw_invoice_bucket_arn" {
  description = "ARN of the S3 bucket for raw invoice uploads"
  value       = aws_s3_bucket.raw_invoice_bucket.arn
}

output "processed_invoice_bucket_name" {
  description = "Name of the S3 bucket for processed invoice data"
  value       = aws_s3_bucket.processed_invoice_bucket.bucket
}

output "processed_invoice_bucket_arn" {
  description = "ARN of the S3 bucket for processed invoice data"
  value       = aws_s3_bucket.processed_invoice_bucket.arn
}

output "lambda_s3_bucket_name" {
  description = "Name of the original Lambda S3 bucket"
  value       = aws_s3_bucket.lambda_s3_bucket.bucket
}

output "lambda_s3_bucket_arn" {
  description = "ARN of the original Lambda S3 bucket"
  value       = aws_s3_bucket.lambda_s3_bucket.arn
}

# DynamoDB Output
output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for invoices"
  value       = aws_dynamodb_table.lambda_dynamodb.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for invoices"
  value       = aws_dynamodb_table.lambda_dynamodb.arn
}

# SNS Outputs
output "sns_topic_name" {
  description = "Name of the SNS topic for invoice processing notifications"
  value       = aws_sns_topic.invoice_processing_notifications.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for invoice processing notifications"
  value       = aws_sns_topic.invoice_processing_notifications.arn
}

# IAM Role Outputs
output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_role.arn
}

output "step_functions_role_arn" {
  description = "ARN of the Step Functions execution role"
  value       = aws_iam_role.step_functions_role.arn
}

# Summary Output
output "invoice_processing_summary" {
  description = "Summary of the complete invoice processing system"
  value = {
    raw_upload_bucket       = aws_s3_bucket.raw_invoice_bucket.bucket
    processed_data_bucket   = aws_s3_bucket.processed_invoice_bucket.bucket
    textract_processor      = aws_lambda_function.textract_processor.function_name
    data_storage_function   = aws_lambda_function.store_extracted_data.function_name
    step_functions_workflow = aws_sfn_state_machine.invoice_automation.name
    notification_topic      = aws_sns_topic.invoice_processing_notifications.name
    database_table          = aws_dynamodb_table.lambda_dynamodb.name
  }
}

# Removed invalid output reference - aws_lambda_function.lambda_function doesn't exist
# Use specific function outputs above instead


# Aurora MySQL Outputs
output "rds_cluster_identifier" {
  description = "Aurora MySQL cluster identifier"
  value       = aws_rds_cluster.lambda_aurora_mysql.cluster_identifier
}

output "rds_writer_endpoint" {
  description = "Aurora MySQL writer endpoint"
  value       = aws_rds_cluster.lambda_aurora_mysql.endpoint
}

# Reader endpoint (load-balanced read-only)
output "rds_reader_endpoint" {
  description = "Aurora MySQL reader endpoint"
  value       = aws_rds_cluster.lambda_aurora_mysql.reader_endpoint
}

output "rds_database_name" {
  description = "Aurora MySQL database name"
  value       = aws_rds_cluster.lambda_aurora_mysql.database_name
}

output "aurora_secret_arn" {
  description = "ARN of the Aurora MySQL password secret"
  value       = aws_secretsmanager_secret.aurora_password.arn
  sensitive   = true
}
