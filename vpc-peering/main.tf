terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.66"
    }
  }

  backend "s3" {
    key = "terraform.vpc-peering.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}



####### VPC A
# VPC Configuration for VPC A
resource "aws_vpc" "vpc_a" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "${var.resource_prefix}-vpc-a"
  }
}

# Create an Internet Gateway on the VPC
resource "aws_internet_gateway" "igw_a" {
  vpc_id = aws_vpc.vpc_a.id

  tags = {
    Name = "${var.resource_prefix}-igw-a"
  }
}

# Public Subnet for VPC A
resource "aws_subnet" "public_subnet_a" {
  vpc_id     = aws_vpc.vpc_a.id
  cidr_block = "10.1.1.0/24"

  tags = {
    Name = "${var.resource_prefix}-public-subnet-a"
  }
}

# Private Subnet for VPC A
resource "aws_subnet" "private_subnet_a" {
  vpc_id     = aws_vpc.vpc_a.id
  cidr_block = "10.1.2.0/24"

  tags = {
    Name = "${var.resource_prefix}-private-subnet-a"
  }
}

# NAT Gateway for VPC A
resource "aws_nat_gateway" "nat_gateway_a" {
  allocation_id = aws_eip.nat_eip_a.id
  subnet_id     = aws_subnet.public_subnet_a.id

  tags = {
    Name = "${var.resource_prefix}-nat-gateway-a"
  }
}

resource "aws_eip" "nat_eip_a" {
  tags = {
    Name = "${var.resource_prefix}-nat-eip-a"
  }
}

resource "aws_security_group" "public_sg_a" {
  vpc_id = aws_vpc.vpc_a.id

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
    Name = "${var.resource_prefix}-sg-a"
  }
}



####### VPC B
# VPC Configuration for VPC B
resource "aws_vpc" "vpc_b" {
  cidr_block = "10.2.0.0/16"

  tags = {
    Name = "${var.resource_prefix}-vpc-b"
  }
}

# Create an Internet Gateway on the VPC
resource "aws_internet_gateway" "igw_b" {
  vpc_id = aws_vpc.vpc_b.id

  tags = {
    Name = "${var.resource_prefix}-igw-b"
  }
}

# Public Subnet for VPC B
resource "aws_subnet" "public_subnet_b" {
  vpc_id     = aws_vpc.vpc_b.id
  cidr_block = "10.2.1.0/24"

  tags = {
    Name = "${var.resource_prefix}-public-subnet-b"
  }
}

# Private Subnet for VPC B
resource "aws_subnet" "private_subnet_b" {
  vpc_id     = aws_vpc.vpc_b.id
  cidr_block = "10.2.2.0/24"

  tags = {
    Name = "${var.resource_prefix}-private-subnet-b"
  }
}

# NAT Gateway for VPC B
resource "aws_nat_gateway" "nat_gateway_b" {
  allocation_id = aws_eip.nat_eip_b.id
  subnet_id     = aws_subnet.public_subnet_b.id

  tags = {
    Name = "${var.resource_prefix}-nat-gateway-b"
  }
}

resource "aws_eip" "nat_eip_b" {
  tags = {
    Name = "${var.resource_prefix}-nat-eip-b"
  }
}

resource "aws_security_group" "public_sg_b" {
  vpc_id = aws_vpc.vpc_b.id

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
    Name = "${var.resource_prefix}-sg-b"
  }
}



####### Peering and Routes
# VPC A routes
resource "aws_route_table" "public_rt_a" {
  vpc_id = aws_vpc.vpc_a.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_a.id
  }

  tags = {
    Name = "${var.resource_prefix}-public-route-table-a"
  }
}

resource "aws_route_table" "private_rt_a" {
  vpc_id = aws_vpc.vpc_a.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_a.id
  }

  tags = {
    Name = "${var.resource_prefix}-private-route-table-a"
  }
}

resource "aws_route_table_association" "public_subnet_a_association" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt_a.id
}

resource "aws_route_table_association" "private_subnet_a_association" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt_a.id
}

# # VPC B routes
resource "aws_route_table" "public_rt_b" {
  vpc_id = aws_vpc.vpc_b.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_b.id
  }

  tags = {
    Name = "${var.resource_prefix}-public-route-table-b"
  }
}

resource "aws_route_table" "private_rt_b" {
  vpc_id = aws_vpc.vpc_b.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_b.id
  }

  tags = {
    Name = "${var.resource_prefix}-private-route-table-b"
  }
}

resource "aws_route_table_association" "public_subnet_b_association" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt_b.id
}

resource "aws_route_table_association" "private_subnet_b_association" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt_b.id
}

# # Routes between VPC
resource "aws_vpc_peering_connection" "peer" {
  peer_vpc_id = aws_vpc.vpc_b.id
  vpc_id      = aws_vpc.vpc_a.id
  auto_accept = true
}
# Route table associations
resource "aws_route" "route_a_to_b" {
  route_table_id         = aws_route_table.private_rt_a.id
  destination_cidr_block = aws_vpc.vpc_b.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_route" "route_b_to_a" {
  route_table_id         = aws_route_table.private_rt_b.id
  destination_cidr_block = aws_vpc.vpc_a.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}



# ####### EC2 INSTANCES
# # Instance in Private Subnet B
resource "aws_instance" "private_ec2_a" {
  ami           = var.ec2_ami  
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet_a.id
  vpc_security_group_ids =  [aws_security_group.public_sg_a.id]

  user_data = file("user-data.sh")

  tags = {
    Name = "${var.resource_prefix}-ec2-private-a"
  }
}

# # Instance in Private Subnet A
resource "aws_instance" "private_ec2_b" {
  ami           = var.ec2_ami  
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet_b.id
  vpc_security_group_ids =  [aws_security_group.public_sg_b.id]

  user_data = file("user-data.sh")

  tags = {
    Name = "${var.resource_prefix}-ec2-private-b"
  }
}


# Instance connect endpoint to connect private subnet A instance via SSH
resource "aws_ec2_instance_connect_endpoint" "instance_connect_endpoint_a" {
  subnet_id = aws_subnet.private_subnet_a.id
  tags = {
    Name = "${var.resource_prefix}-instance-co-endpoint-private-sub-a"
  }
}

# Instance connect endpoint to connect private subnet B instance via SSH
resource "aws_ec2_instance_connect_endpoint" "instance_connect_endpoint_b" {
  subnet_id = aws_subnet.private_subnet_b.id
  tags = {
    Name = "${var.resource_prefix}-instance-co-endpoint-private-sub-b"
  }
}