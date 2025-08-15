# Data sources for AWS account information
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}
