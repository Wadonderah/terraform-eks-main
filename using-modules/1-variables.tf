variable "tf_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Region"
}


# AWS credentials should not be hardcoded
# Use AWS CLI configuration or environment variables instead
# variable "tf_access_key" - REMOVED for security
# variable "tf_secrete_key" - REMOVED for security

variable "tf_profile" {
  type    = string
  default = "terraform-test"
}

variable "tf_vpc_cidr_block" {
  type    = string
  default = "11.0.0.0/16"
}

variable "eks_cluster_name" {
  type = string
  default = "test_eks"
  description = "EKS version"
}

variable "eks_version" {
  type = string
  default = "1.33"
  description = "EKS version"
}