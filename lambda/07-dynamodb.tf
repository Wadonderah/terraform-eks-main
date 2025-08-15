data "aws_region" "current" {}

resource "aws_dynamodb_table" "lambda_dynamoDB" {
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "customerId"
  name             = var.lambda_dynamoDB
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  range_key        = "invoiceNumber"

  attribute {
    name = "customerId"
    type = "S"
  }

  attribute {
    name = "invoiceNumber"
    type = "N"
  }

  attribute {
    name = "customerName"
    type = "S"
  }

  replica {
    region_name = "us-east-1"
  }
  replica {
    region_name    = "eu-west-1"
    propagate_tags = true
  }

  global_secondary_index {
    name               = "InvoiceTitleIndex"
    hash_key           = "invoiceNumber"
    range_key          = "customerName"
    write_capacity     = 10
    read_capacity      = 10
    projection_type    = "INCLUDE"
    non_key_attributes = ["customerId"]
  }

  tags = {
    Architect   = "lambda_dynamoDB"
    Environment = "production"
  }

}

