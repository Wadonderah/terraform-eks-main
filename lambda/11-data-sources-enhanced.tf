# Enhanced Data Sources
data "aws_caller_identity" "current" {
  # Get current AWS account ID and user information
}

data "aws_region" "current" {
  # Get current AWS region information
}

data "aws_availability_zones" "available" {
  state = "available"
  
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_partition" "current" {
  # Get AWS partition (aws, aws-cn, aws-us-gov)
}

# Get the latest Amazon Linux 2 AMI (useful for future EC2 instances)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get VPC information if using default VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get existing KMS keys (if any)
data "aws_kms_key" "s3" {
  key_id = "alias/aws/s3"
}

data "aws_kms_key" "dynamodb" {
  key_id = "alias/aws/dynamodb"
}

# Get IAM policy documents for common AWS services
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "step_functions_assume_role" {
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
    
    actions = ["sts:AssumeRole"]
  }
}

# Get existing SNS topics (if any)
data "aws_sns_topics" "existing" {}

# Get S3 bucket policy for secure access
data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    sid    = "DenyInsecureConnections"
    effect = "Deny"
    
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    
    actions = ["s3:*"]
    
    resources = [
      "arn:aws:s3:::${local.raw_bucket_name}",
      "arn:aws:s3:::${local.raw_bucket_name}/*",
      "arn:aws:s3:::${local.processed_bucket_name}",
      "arn:aws:s3:::${local.processed_bucket_name}/*"
    ]
    
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
  
  statement {
    sid    = "AllowLambdaAccess"
    effect = "Allow"
    
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.lambda_role.arn]
    }
    
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    
    resources = [
      "arn:aws:s3:::${local.raw_bucket_name}/*",
      "arn:aws:s3:::${local.processed_bucket_name}/*"
    ]
  }
}

# Get CloudWatch log group policy
data "aws_iam_policy_document" "cloudwatch_logs_policy" {
  statement {
    effect = "Allow"
    
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/stepfunctions/*"
    ]
  }
}

# Get Textract service policy
data "aws_iam_policy_document" "textract_policy" {
  statement {
    effect = "Allow"
    
    actions = [
      "textract:AnalyzeDocument",
      "textract:DetectDocumentText",
      "textract:StartDocumentAnalysis",
      "textract:GetDocumentAnalysis",
      "textract:StartDocumentTextDetection",
      "textract:GetDocumentTextDetection"
    ]
    
    resources = ["*"]
  }
  
  statement {
    effect = "Allow"
    
    actions = [
      "s3:GetObject"
    ]
    
    resources = [
      "arn:aws:s3:::${local.raw_bucket_name}/*"
    ]
  }
}

# Get DynamoDB policy
data "aws_iam_policy_document" "dynamodb_policy" {
  statement {
    effect = "Allow"
    
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem"
    ]
    
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.lambda_dynamoDB}",
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.lambda_dynamoDB}/*"
    ]
  }
}

# Get SNS policy
data "aws_iam_policy_document" "sns_policy" {
  statement {
    effect = "Allow"
    
    actions = [
      "sns:Publish",
      "sns:GetTopicAttributes"
    ]
    
    resources = [
      "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.sns_topic_name}",
      "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:invoice-processing-alerts"
    ]
  }
}

# Get Lambda invoke policy
data "aws_iam_policy_document" "lambda_invoke_policy" {
  statement {
    effect = "Allow"
    
    actions = [
      "lambda:InvokeFunction"
    ]
    
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${local.lambda_functions.store_extracted_data}",
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${local.lambda_functions.send_notification}"
    ]
  }
}

# Output data source information for reference
output "aws_account_info" {
  description = "AWS account and region information"
  value = {
    account_id        = data.aws_caller_identity.current.account_id
    region           = data.aws_region.current.name
    partition        = data.aws_partition.current.partition
    availability_zones = data.aws_availability_zones.available.names
    default_vpc_id   = data.aws_vpc.default.id
  }
}
