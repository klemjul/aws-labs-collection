terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.66"
    }
  }

  backend "s3" {
    key = "terraform.vpc-basic.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.resource_prefix}-myvpc"
  }
}

# Create an Internet Gateway on the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.resource_prefix}-igw"
  }
}

# Create Public and Private Subnets on az a and az b
resource "aws_subnet" "public_subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.az_a

  tags = {
    Name = "${var.resource_prefix}-az-a-public-subnet"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.az_b

  tags = {
    Name = "${var.resource_prefix}-az-b-public-subnet"
  }
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.100.0/24"
  availability_zone = var.az_a

  tags = {
    Name = "${var.resource_prefix}-az-a-private-subnet"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.200.0/24"
  availability_zone = var.az_b

  tags = {
    Name = "${var.resource_prefix}-az-b-private-subnet"
  }
}

# Create NAT Gateway on private subnets and their elastic IPs
resource "aws_eip" "nat_eip_a" {
  tags = {
    Name = "${var.resource_prefix}-nat-eip-a"
  }
}

resource "aws_nat_gateway" "nat_gateway_a" {
  allocation_id = aws_eip.nat_eip_a.id
  subnet_id     = aws_subnet.public_subnet_a.id

  tags = {
    Name = "${var.resource_prefix}-nat-gateway-a"
  }
}

resource "aws_eip" "nat_eip_b" {
   tags = {
    Name = "${var.resource_prefix}-nat-eip-b"
  }
}

resource "aws_nat_gateway" "nat_gateway_b" {
  allocation_id = aws_eip.nat_eip_b.id
  subnet_id     = aws_subnet.public_subnet_b.id

  tags = {
    Name = "${var.resource_prefix}-nat-gateway-b"
  }
}


# Create Public Route Table and associate with subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.resource_prefix}-public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_a_association" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_b_association" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table 
resource "aws_route_table" "private_rt_a" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.resource_prefix}-private-route-table-a"
  }
}

resource "aws_route_table" "private_rt_b" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.resource_prefix}-private-route-table-b"
  }
}

resource "aws_route_table_association" "private_subnet_a_association" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt_a.id
}

resource "aws_route_table_association" "private_subnet_b_association" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt_b.id
}

resource "aws_route" "private_a_nat_route" {
  route_table_id         = aws_route_table.private_rt_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway_a.id
}

resource "aws_route" "private_b_nat_route" {
  route_table_id         = aws_route_table.private_rt_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway_b.id
}

# Security Group for EC2 instances
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH access from anywhere
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP access
  }

  ingress {
    from_port   = 8        # ICMP Echo Request
    to_port     = -1       # -1 allows all ICMP codes (not just Echo Reply)
    protocol    = "icmp"   # ICMP protocol
    cidr_blocks = ["0.0.0.0/0"]  # Allow from anywhere (adjust for more specific CIDR range)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_prefix}-sg"
  }
}

# EC2 instance in Public Subnet A
resource "aws_instance" "public_ec2_a" {
  ami           = var.ec2_ami 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_a.id
  vpc_security_group_ids =  [aws_security_group.public_sg.id]
  associate_public_ip_address = true

  user_data = file("user-data.sh")

  tags = {
    Name = "${var.resource_prefix}-ec2-public-a"
  }
}

# EC2 instance in Private Subnet A
resource "aws_instance" "private_ec2_a" {
  ami           = var.ec2_ami  
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet_a.id
  vpc_security_group_ids =  [aws_security_group.public_sg.id]

  user_data = file("user-data.sh")

  tags = {
    Name = "${var.resource_prefix}-ec2-private-a"
  }
}

# Instance connect endpoint to connect private subnet A instance via SSH
resource "aws_ec2_instance_connect_endpoint" "example" {
  subnet_id = aws_subnet.private_subnet_a.id
  tags = {
    Name = "${var.resource_prefix}-instance-co-endpoint-private-sub-a"
  }
}
