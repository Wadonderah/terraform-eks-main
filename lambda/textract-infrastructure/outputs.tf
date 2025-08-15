# Outputs for Invoice Processing System

# S3 Bucket Outputs
output "raw_invoice_bucket_name" {
  description = "Name of the S3 bucket for raw invoice uploads"
  value       = module.s3_buckets.raw_bucket_name
}

output "raw_invoice_bucket_arn" {
  description = "ARN of the S3 bucket for raw invoice uploads"
  value       = module.s3_buckets.raw_bucket_arn
}

output "processed_invoice_bucket_name" {
  description = "Name of the S3 bucket for processed invoice data"
  value       = module.s3_buckets.processed_bucket_name
}

output "processed_invoice_bucket_arn" {
  description = "ARN of the S3 bucket for processed invoice data"
  value       = module.s3_buckets.processed_bucket_arn
}

# DynamoDB Outputs
output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for invoices"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for invoices"
  value       = module.dynamodb.table_arn
}

# SNS Outputs
output "sns_topic_name" {
  description = "Name of the SNS topic for invoice processing notifications"
  value       = module.sns.topic_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for invoice processing notifications"
  value       = module.sns.topic_arn
}

# Lambda Function Outputs
output "textract_processor_function_name" {
  description = "Name of the Textract processor Lambda function"
  value       = module.lambda.textract_processor_name
}

output "textract_processor_function_arn" {
  description = "ARN of the Textract processor Lambda function"
  value       = module.lambda.textract_processor_arn
}

output "store_extracted_data_function_name" {
  description = "Name of the data storage Lambda function"
  value       = module.lambda.store_extracted_data_name
}

output "store_extracted_data_function_arn" {
  description = "ARN of the data storage Lambda function"
  value       = module.lambda.store_extracted_data_arn
}

output "validate_invoice_function_name" {
  description = "Name of the invoice validation Lambda function"
  value       = module.lambda.validate_invoice_name
}

output "validate_invoice_function_arn" {
  description = "ARN of the invoice validation Lambda function"
  value       = module.lambda.validate_invoice_arn
}

output "process_invoice_function_name" {
  description = "Name of the invoice processing Lambda function"
  value       = module.lambda.process_invoice_name
}

output "process_invoice_function_arn" {
  description = "ARN of the invoice processing Lambda function"
  value       = module.lambda.process_invoice_arn
}

output "send_notification_function_name" {
  description = "Name of the notification Lambda function"
  value       = module.lambda.send_notification_name
}

output "send_notification_function_arn" {
  description = "ARN of the notification Lambda function"
  value       = module.lambda.send_notification_arn
}

# Step Functions Outputs
output "step_function_arn" {
  description = "ARN of the invoice automation Step Functions state machine"
  value       = module.step_functions.state_machine_arn
}

output "step_function_name" {
  description = "Name of the invoice automation Step Functions state machine"
  value       = module.step_functions.state_machine_name
}

# IAM Role Outputs
output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.lambda.lambda_role_arn
}

output "step_functions_role_arn" {
  description = "ARN of the Step Functions execution role"
  value       = module.step_functions.step_functions_role_arn
}

# System Summary
output "invoice_processing_system_summary" {
  description = "Complete summary of the invoice processing system"
  value = {
    # Upload and Storage
    upload_bucket         = module.s3_buckets.raw_bucket_name
    processed_data_bucket = module.s3_buckets.processed_bucket_name
    database_table        = module.dynamodb.table_name

    # Processing Functions
    textract_processor    = module.lambda.textract_processor_name
    data_storage_function = module.lambda.store_extracted_data_name

    # Workflow
    step_functions_workflow = module.step_functions.state_machine_name

    # Notifications
    notification_topic = module.sns.topic_name

    # Instructions
    usage_instructions = {
      upload_files       = "Upload PDF/image invoices to s3://${module.s3_buckets.raw_bucket_name}/"
      monitor_processing = "Check Step Functions console for workflow execution status"
      view_results       = "Processed data stored in s3://${module.s3_buckets.processed_bucket_name}/ and DynamoDB table '${module.dynamodb.table_name}'"
      notifications      = "Email notifications sent to configured address via SNS topic '${module.sns.topic_name}'"
    }
  }
}
