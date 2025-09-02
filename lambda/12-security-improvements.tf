# KMS Key for encryption
resource "aws_kms_key" "invoice_processing_key" {
  description             = "KMS key for invoice processing system encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda service"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "invoice-processing-kms-key"
    Environment = "production"
    Application = "invoice-automation"
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "invoice_processing_key_alias" {
  name          = "alias/invoice-processing"
  target_key_id = aws_kms_key.invoice_processing_key.key_id
}

# VPC for Lambda functions (optional but recommended for production)
resource "aws_vpc" "lambda_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "invoice-processing-vpc"
    Environment = "production"
    Application = "invoice-automation"
  }
}

resource "aws_subnet" "lambda_subnet_1" {
  vpc_id            = aws_vpc.lambda_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "invoice-processing-subnet-1"
  }
}

resource "aws_subnet" "lambda_subnet_2" {
  vpc_id            = aws_vpc.lambda_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "invoice-processing-subnet-2"
  }
}

# Security Group for Lambda functions
resource "aws_security_group" "lambda_sg" {
  name_prefix = "invoice-lambda-sg"
  vpc_id      = aws_vpc.lambda_vpc.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound"
  }

  tags = {
    Name        = "invoice-lambda-security-group"
    Environment = "production"
    Application = "invoice-automation"
  }
}

# VPC Endpoints for AWS services (cost optimization and security)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.lambda_vpc.id
  service_name = "com.amazonaws.${var.tf_region}.s3"
  
  tags = {
    Name = "invoice-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.lambda_vpc.id
  service_name = "com.amazonaws.${var.tf_region}.dynamodb"
  
  tags = {
    Name = "invoice-dynamodb-endpoint"
  }
}

# Enhanced IAM policy for least privilege
resource "aws_iam_role_policy" "lambda_enhanced_security_policy" {
  name = "lambda_enhanced_security_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.invoice_processing_key.arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "s3.${var.tf_region}.amazonaws.com",
              "dynamodb.${var.tf_region}.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

# WAF for API Gateway (if you add API Gateway later)
resource "aws_wafv2_web_acl" "invoice_api_waf" {
  name  = "invoice-api-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name        = "invoice-api-waf"
    Environment = "production"
    Application = "invoice-automation"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "invoiceAPIWAF"
    sampled_requests_enabled   = true
  }
}
