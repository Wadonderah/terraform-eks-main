# Step Functions IAM Role
resource "aws_iam_role" "step_functions_role" {
  name = "step-functions-invoice-automation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_functions_policy" {
  name = "step-functions-invoice-policy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.validate_invoice.arn,
          aws_lambda_function.process_invoice.arn,
          aws_lambda_function.send_notification.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "invoice_automation" {
  name     = "invoice-automation-workflow"
  role_arn = aws_iam_role.step_functions_role.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "Invoice Automation Workflow - Validates, processes, and sends notifications for invoices"
    StartAt = "ValidateInvoice"
    States = {
      ValidateInvoice = {
        Type     = "Task"
        Resource = aws_lambda_function.validate_invoice.arn
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.TaskFailed"]
            Next        = "ValidationFailed"
            ResultPath  = "$.error"
          }
        ]
        Next = "CheckValidation"
      }

      CheckValidation = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.isValid"
            BooleanEquals = true
            Next          = "ProcessInvoice"
          }
        ]
        Default = "ValidationFailed"
      }

      ProcessInvoice = {
        Type     = "Task"
        Resource = aws_lambda_function.process_invoice.arn
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.TaskFailed"]
            Next        = "ProcessingFailed"
            ResultPath  = "$.error"
          }
        ]
        Next = "CheckProcessing"
      }

      CheckProcessing = {
        Type = "Choice"
        Choices = [
          {
            Variable        = "$.statusCode"
            NumericEquals   = 200
            Next            = "SendSuccessNotification"
          },
          {
            Variable        = "$.statusCode"
            NumericEquals   = 409
            Next            = "DuplicateInvoiceNotification"
          }
        ]
        Default = "ProcessingFailed"
      }

      SendSuccessNotification = {
        Type     = "Task"
        Resource = aws_lambda_function.send_notification.arn
        Parameters = {
          "invoice.$"        = "$.invoice"
          "notificationType" = "success"
        }
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
        Next = "InvoiceProcessedSuccessfully"
      }

      DuplicateInvoiceNotification = {
        Type     = "Task"
        Resource = aws_lambda_function.send_notification.arn
        Parameters = {
          "invoice.$"        = "$.invoice"
          "notificationType" = "duplicate"
        }
        Next = "DuplicateInvoiceHandled"
      }

      ValidationFailed = {
        Type     = "Task"
        Resource = aws_lambda_function.send_notification.arn
        Parameters = {
          "invoice.$"        = "$.invoice"
          "notificationType" = "validation_failed"
          "error.$"          = "$.error"
        }
        Next = "InvoiceValidationFailed"
      }

      ProcessingFailed = {
        Type     = "Task"
        Resource = aws_lambda_function.send_notification.arn
        Parameters = {
          "invoice.$"        = "$.invoice"
          "notificationType" = "processing_failed"
          "error.$"          = "$.error"
        }
        Next = "InvoiceProcessingFailed"
      }

      InvoiceProcessedSuccessfully = {
        Type = "Pass"
        Result = {
          status  = "SUCCESS"
          message = "Invoice has been validated, processed, and notification sent successfully"
        }
        End = true
      }

      DuplicateInvoiceHandled = {
        Type = "Pass"
        Result = {
          status  = "DUPLICATE"
          message = "Duplicate invoice detected and handled"
        }
        End = true
      }

      InvoiceValidationFailed = {
        Type = "Pass"
        Result = {
          status  = "VALIDATION_FAILED"
          message = "Invoice validation failed"
        }
        End = true
      }

      InvoiceProcessingFailed = {
        Type = "Pass"
        Result = {
          status  = "PROCESSING_FAILED"
          message = "Invoice processing failed"
        }
        End = true
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions_logs.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = {
    Environment = "production"
    Application = "invoice-automation"
    Service     = "step-functions"
  }
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions_logs" {
  name              = "/aws/stepfunctions/invoice-automation"
  retention_in_days = 14

  tags = {
    Environment = "production"
    Application = "invoice-automation"
    ManagedBy   = "terraform"
  }
}