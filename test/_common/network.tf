data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az-a = data.aws_availability_zones.available.names[0]
  az-b = data.aws_availability_zones.available.names[1]
}

resource "aws_vpc" "test" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "test" {
  vpc_id = aws_vpc.test.id
}

resource "aws_subnet" "test-a" {
  vpc_id                  = aws_vpc.test.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = local.az-a
  map_public_ip_on_launch = true
}

resource "aws_subnet" "test-b" {
  vpc_id                  = aws_vpc.test.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.az-b
  map_public_ip_on_launch = true
}

resource "aws_route_table" "test" {
  vpc_id = aws_vpc.test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test.id
  }
}

resource "aws_route_table_association" "test-a" {
  subnet_id      = aws_subnet.test-a.id
  route_table_id = aws_route_table.test.id
}

resource "aws_route_table_association" "test-b" {
  subnet_id      = aws_subnet.test-b.id
  route_table_id = aws_route_table.test.id
}
