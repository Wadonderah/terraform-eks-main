data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "tf_vpc" {
  cidr_block           = var.tf_vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "Eks VPC"
  }
}

resource "aws_subnet" "tf_public_subnet-1" {
  vpc_id            = aws_vpc.tf_vpc.id
  cidr_block        = cidrsubnet(var.tf_vpc_cidr_block, 8, 10)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = var.tf_tags
}

resource "aws_subnet" "tf_public_subnet-2" {
  vpc_id            = aws_vpc.tf_vpc.id
  cidr_block        = cidrsubnet(var.tf_vpc_cidr_block, 8, 20)
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = var.tf_tags
}

resource "aws_subnet" "tf_private_subnet-1" {
  vpc_id            = aws_vpc.tf_vpc.id
  cidr_block        = cidrsubnet(var.tf_vpc_cidr_block, 8, 110)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = var.tf_tags
}

resource "aws_subnet" "tf_private_subnet-2" {
  vpc_id            = aws_vpc.tf_vpc.id
  cidr_block        = cidrsubnet(var.tf_vpc_cidr_block, 8, 120)
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = var.tf_tags
}

#internet gateway
resource "aws_internet_gateway" "tf_igw" {
  vpc_id = aws_vpc.tf_vpc.id
  tags = {
    Name = "tf_igw"
  }
}

#Elastic ip address
resource "aws_eip" "tf_eip" {
  domain = "vpc"
  tags = {
    Name = "tf_eip"
  }
  depends_on = [aws_internet_gateway.tf_igw]
}

#nats gateway
resource "aws_nat_gateway" "tf_nat_gateway" {
  allocation_id = aws_eip.tf_eip.id
  subnet_id     = aws_subnet.tf_public_subnet-1.id

  tags = {
    Name = "tf_nat_gateway"
  }
  depends_on = [aws_internet_gateway.tf_igw]
}

#route tables
resource "aws_route_table" "tf_public_rt" {
  vpc_id = aws_vpc.tf_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf_igw.id
  }

  tags = {
    Name = "tf_public_route_table"
  }
}

resource "aws_route_table" "tf_private_rt" {
  vpc_id = aws_vpc.tf_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.tf_nat_gateway.id
  }

  tags = {
    Name = "tf_private_route_table"
  }
}

#route assouciation
resource "aws_route_table_association" "tf_public_rt_assoc_1" {
  subnet_id      = aws_subnet.tf_public_subnet-1.id
  route_table_id = aws_route_table.tf_public_rt.id
}

resource "aws_route_table_association" "tf_public_rt_assoc_2" {
  subnet_id      = aws_subnet.tf_public_subnet-2.id
  route_table_id = aws_route_table.tf_public_rt.id
}

resource "aws_route_table_association" "tf_private_rt_assoc_1" {
  subnet_id      = aws_subnet.tf_private_subnet-1.id
  route_table_id = aws_route_table.tf_private_rt.id
}

resource "aws_route_table_association" "tf_private_rt_assoc_2" {
  subnet_id      = aws_subnet.tf_private_subnet-2.id
  route_table_id = aws_route_table.tf_private_rt.id
}