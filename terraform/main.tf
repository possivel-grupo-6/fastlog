provider "aws" {
  region = "us-east-1"
}


resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.client}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.client}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.client}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.client}-public-rt"
  }
}
resource "aws_route_table_association" "rt_assoc_subnet_1" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.client}-sg"
  }
}



resource "aws_instance" "bastion-prod" {
  ami                    = var.ec2_ami_id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  key_name               = "ssh-key"
  iam_instance_profile   = var.ec2_iam_instance_profile
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  tags = {
    Name = "Docker-node"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y docker.io python3 python3-pip git
    sudo pip3 install docker-compose
  EOF
}


resource "aws_s3_bucket" "bucket_logs" {
  bucket = "bucket-${var.client}-raw"
  acl    = "private"

  tags = {
    Name = "bucket-${var.client}-raw"
  }
}
