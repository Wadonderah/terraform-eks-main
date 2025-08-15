terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.4.0"
    }
  }
}

provider "aws" {
  region  = var.tf_region
  profile = "default"  # or "Dayster" if you prefer that profile
}