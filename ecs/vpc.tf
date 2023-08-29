resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"

  // required to set custom vpc endpoint
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "tfe-workshop-vpc"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "tfe-workshop-igw"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "tfe-workshop-route-table-public"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "sa-east-1a"
  tags = {
    dmz = "true"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "sa-east-1b"
  tags = {
    dmz = "true"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "sa-east-1c"
  tags = {
    app = "true"
  }
}

resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

// required to make ecr accessible to our tasks
// since fargate 1.4.0 we're responsible to this
// so we shall either attach our ecs to a public subnet
// or to a Nat gateway (which is too expensive for this project)
resource "aws_vpc_endpoint" "ecr_endpoint" {
  vpc_id              = aws_vpc.my_vpc.id
  service_name        = "com.amazonaws.sa-east-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private_subnet_1.id]
}
