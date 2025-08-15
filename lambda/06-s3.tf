resource "random_id" "unique_suffix" {
  byte_length = 8
}

# Existing S3 bucket (keeping for backward compatibility)
resource "aws_s3_bucket" "lambda_s3_bucket" {
  bucket = "invoice-bucket-${random_id.unique_suffix.hex}"

  tags = {
    Name        = "lambda_s3_bucket"
    Environment = "production"
    Application = "invoice-automation"
    ManagedBy   = "terraform"
  }
}

# Raw invoice uploads bucket
resource "aws_s3_bucket" "raw_invoice_bucket" {
  bucket = "${var.raw_invoice_bucket_name}-${random_id.unique_suffix.hex}"

  tags = {
    Name        = "Raw Invoice Uploads"
    Environment = "production"
    Purpose     = "invoice-processing"
    Application = "invoice-automation"
    ManagedBy   = "terraform"
  }
}

# Processed invoice data bucket
resource "aws_s3_bucket" "processed_invoice_bucket" {
  bucket = "${var.processed_invoice_bucket_name}-${random_id.unique_suffix.hex}"

  tags = {
    Name        = "Processed Invoice Data"
    Environment = "production"
    Purpose     = "invoice-processing"
    Application = "invoice-automation"
    ManagedBy   = "terraform"
  }
}

# S3 bucket versioning for raw invoices
resource "aws_s3_bucket_versioning" "raw_invoice_versioning" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket versioning for processed invoices
resource "aws_s3_bucket_versioning" "processed_invoice_versioning" {
  bucket = aws_s3_bucket.processed_invoice_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket server-side encryption for raw invoices
resource "aws_s3_bucket_server_side_encryption_configuration" "raw_invoice_encryption" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket server-side encryption for processed invoices
resource "aws_s3_bucket_server_side_encryption_configuration" "processed_invoice_encryption" {
  bucket = aws_s3_bucket.processed_invoice_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket public access block for raw invoices
resource "aws_s3_bucket_public_access_block" "raw_invoice_pab" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket public access block for processed invoices
resource "aws_s3_bucket_public_access_block" "processed_invoice_pab" {
  bucket = aws_s3_bucket.processed_invoice_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket notification for triggering Textract Lambda
resource "aws_s3_bucket_notification" "raw_invoice_notification" {
  bucket = aws_s3_bucket.raw_invoice_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.textract_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ""
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke_textract]
}

# Lambda permission for S3 to invoke Textract processor
resource "aws_lambda_permission" "allow_s3_invoke_textract" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.textract_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_invoice_bucket.arn
}

