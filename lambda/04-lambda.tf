resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key     = "lambda_role"
    Environment = "production"
    Application = "invoice-automation"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "lambda_role_policy" {
  name = "lambda_role_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = [
          aws_dynamodb_table.lambda_dynamodb.arn,
          "${aws_dynamodb_table.lambda_dynamodb.arn}/*"
        ]
      },
      {
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "textract:AnalyzeDocument",
          "textract:DetectDocumentText",
          "textract:StartDocumentAnalysis",
          "textract:GetDocumentAnalysis"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.raw_invoice_bucket.arn}/*",
          "${aws_s3_bucket.processed_invoice_bucket.arn}/*",
          "${aws_s3_bucket.lambda_s3_bucket.arn}/*"
        ]
      },
      {
        Action = [
          "sns:Publish"
        ]
        Effect   = "Allow"
        Resource = aws_sns_topic.invoice_processing_notifications.arn
      },
      {
        Action = [
          "lambda:InvokeFunction"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:secretsmanager:${var.tf_region}:*:secret:${var.lambda_aurora_mysql_name}-master-password*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Archive Lambda functions
data "archive_file" "validate_invoice_zip" {
  type        = "zip"
  source_file = "${path.module}/script/validate-invoice.js"
  output_path = "${path.module}/script/validate-invoice.zip"
}

data "archive_file" "process_invoice_zip" {
  type        = "zip"
  source_file = "${path.module}/script/process-invoice.js"
  output_path = "${path.module}/script/process-invoice.zip"
}

data "archive_file" "send_notification_zip" {
  type        = "zip"
  source_file = "${path.module}/script/send-notification.js"
  output_path = "${path.module}/script/send-notification.zip"
}

data "archive_file" "textract_processor_zip" {
  type        = "zip"
  source_file = "${path.module}/script/textract-processor.js"
  output_path = "${path.module}/script/textract-processor.zip"
}

data "archive_file" "store_extracted_data_zip" {
  type        = "zip"
  source_file = "${path.module}/script/store-extracted-data.js"
  output_path = "${path.module}/script/store-extracted-data.zip"
}

# Lambda Functions
resource "aws_lambda_function" "validate_invoice" {
  filename         = data.archive_file.validate_invoice_zip.output_path
  function_name    = "validate-invoice"
  role            = aws_iam_role.lambda_role.arn
  handler         = "validate-invoice.handler"
  source_code_hash = data.archive_file.validate_invoice_zip.output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = 30

  environment {
    variables = {
      ENVIRONMENT = "production"
      LOG_LEVEL   = "info"
    }
  }

  tags = {
    Environment = "production"
    Application = "invoice-automation"
    Function    = "validation"
  }
}

resource "aws_lambda_function" "process_invoice" {
  filename         = data.archive_file.process_invoice_zip.output_path
  function_name    = "process-invoice"
  role            = aws_iam_role.lambda_role.arn
  handler         = "process-invoice.handler"
  source_code_hash = data.archive_file.process_invoice_zip.output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = 30

  environment {
    variables = {
      ENVIRONMENT        = "production"
      LOG_LEVEL         = "info"
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.lambda_dynamodb.name
    }
  }

  tags = {
    Environment = "production"
    Application = "invoice-automation"
    Function    = "processing"
  }
}

resource "aws_lambda_function" "send_notification" {
  filename         = data.archive_file.send_notification_zip.output_path
  function_name    = "send-notification"
  role            = aws_iam_role.lambda_role.arn
  handler         = "send-notification.handler"
  source_code_hash = data.archive_file.send_notification_zip.output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = 30

  environment {
    variables = {
      ENVIRONMENT = "production"
      LOG_LEVEL   = "info"
    }
  }

  tags = {
    Environment = "production"
    Application = "invoice-automation"
    Function    = "notification"
  }
}

# New Textract Lambda Functions
resource "aws_lambda_function" "textract_processor" {
  filename         = data.archive_file.textract_processor_zip.output_path
  function_name    = "textract-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "textract-processor.handler"
  source_code_hash = data.archive_file.textract_processor_zip.output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = var.textract_lambda_timeout

  environment {
    variables = {
      ENVIRONMENT        = "production"
      LOG_LEVEL         = "info"
      SNS_TOPIC_ARN     = aws_sns_topic.invoice_processing_notifications.arn
      STORAGE_LAMBDA_NAME = "store-extracted-data"
    }
  }

  tags = {
    Environment = "production"
    Application = "invoice-automation"
    Function    = "textract-processing"
  }
}

resource "aws_lambda_function" "store_extracted_data" {
  filename         = data.archive_file.store_extracted_data_zip.output_path
  function_name    = "store-extracted-data"
  role            = aws_iam_role.lambda_role.arn
  handler         = "store-extracted-data.handler"
  source_code_hash = data.archive_file.store_extracted_data_zip.output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = 60

  environment {
    variables = {
      ENVIRONMENT          = "production"
      LOG_LEVEL           = "info"
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.lambda_dynamodb.name
      PROCESSED_BUCKET_NAME = aws_s3_bucket.processed_invoice_bucket.bucket
      SNS_TOPIC_ARN       = aws_sns_topic.invoice_processing_notifications.arn
    }
  }

  tags = {
    Environment = "production"
    Application = "invoice-automation"
    Function    = "data-storage"
  }
}
