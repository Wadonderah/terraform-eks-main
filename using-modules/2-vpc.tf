data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = "eks-vpc"
  cidr = var.tf_vpc_cidr_block

  azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  private_subnets = [cidrsubnet(var.tf_vpc_cidr_block, 8, 110), cidrsubnet(var.tf_vpc_cidr_block, 8, 120)]
  public_subnets  = [cidrsubnet(var.tf_vpc_cidr_block, 8, 10), cidrsubnet(var.tf_vpc_cidr_block, 8, 20)]

#Nats
  enable_nat_gateway               = true
  single_nat_gateway               = true
  one_nat_gateway_per_az           = false

  create_igw                       = true #deafault = true
  enable_dns_hostnames             = true #deafault = true
  
  create_private_nat_gateway_route = true  #default = true
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}