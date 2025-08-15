terraform {
  backend "s3" {
    bucket = "secrete-startup-aws"
    key    = "invoice"
    region = "ca-central-1"
  }
}
