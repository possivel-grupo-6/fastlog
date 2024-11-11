provider "aws" {
  region = "us-east-1"  # Defina a região que você está utilizando
}

resource "aws_vpc" "k8s_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "k8s-vpc"
  }
}

resource "aws_subnet" "k8s_subnet_public_a" {
  vpc_id = aws_vpc.k8s_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "k8s-subnet-public-a"
  }
}

resource "aws_subnet" "k8s_subnet_public_b" {
  vpc_id = aws_vpc.k8s_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "k8s-subnet-public-b"
  }
}

resource "aws_subnet" "k8s_subnet_private_a" {
  vpc_id = aws_vpc.k8s_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "k8s-subnet-private-a"
  }
}

resource "aws_subnet" "k8s_subnet_private_b" {
  vpc_id = aws_vpc.k8s_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "k8s-subnet-private-b"
  }
}
resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id
  tags = {
    Name = "k8s-igw"
  }
}

resource "aws_nat_gateway" "k8s_nat" {
  allocation_id = aws_eip.k8s_nat.id
  subnet_id = aws_subnet.k8s_subnet_public_a.id
  tags = {
    Name = "k8s-nat-gateway"
  }
}

resource "aws_eip" "k8s_nat" {
  vpc = true
}

resource "aws_route_table" "k8s_public_rt" {
  vpc_id = aws_vpc.k8s_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_igw.id
  }
  tags = {
    Name = "k8s-public-rt"
  }
}

resource "aws_route_table_association" "k8s_public_rt_assoc_a" {
  subnet_id = aws_subnet.k8s_subnet_public_a.id
  route_table_id = aws_route_table.k8s_public_rt.id
}

resource "aws_route_table_association" "k8s_public_rt_assoc_b" {
  subnet_id = aws_subnet.k8s_subnet_public_b.id
  route_table_id = aws_route_table.k8s_public_rt.id
}

resource "aws_route_table" "k8s_private_rt" {
  vpc_id = aws_vpc.k8s_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.k8s_nat.id
  }
  tags = {
    Name = "k8s-private-rt"
  }
}

resource "aws_route_table_association" "k8s_private_rt_assoc_a" {
  subnet_id = aws_subnet.k8s_subnet_private_a.id
  route_table_id = aws_route_table.k8s_private_rt.id
}

resource "aws_route_table_association" "k8s_private_rt_assoc_b" {
  subnet_id = aws_subnet.k8s_subnet_private_b.id
  route_table_id = aws_route_table.k8s_private_rt.id
}

resource "aws_security_group" "k8s_security_group" {
  vpc_id = aws_vpc.k8s_vpc.id
  name        = "k8s-security-group"
  description = "Allow traffic for Kubernetes cluster"
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress_controller_sg" {
  vpc_id = aws_vpc.k8s_vpc.id
  name        = "ingress-controller-sg"
  description = "Allow traffic for Ingress Controller"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "k8s_worker_a" {
  ami           = "ami-0c55b159cbfafe1f0"  # Substitua pela AMI desejada
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.k8s_subnet_private_a.id
  key_name      = "your-key-name"  # Substitua com o nome da sua chave SSH
  associate_public_ip_address = false  # As instâncias não terão IP público
  
  network_interface {
    network_interface_id = aws_network_interface.k8s_worker_a_nic.id
    device_index         = 0
  }

  tags = {
    Name = "k8s-worker-a"
  }
}

resource "aws_network_interface" "k8s_worker_a_nic" {
  subnet_id            = aws_subnet.k8s_subnet_private_a.id
  security_groups      = [aws_security_group.k8s_security_group.id]
  private_ips          = ["10.0.0.10"]  # Exemplo, altere conforme sua necessidade
}

resource "aws_instance" "k8s_worker_b" {
  ami           = "ami-0c55b159cbfafe1f0"  # Substitua pela AMI desejada
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.k8s_subnet_private_b.id
  key_name      = "your-key-name"  # Substitua com o nome da sua chave SSH
  associate_public_ip_address = false  # As instâncias não terão IP público
  
  network_interface {
    network_interface_id = aws_network_interface.k8s_worker_b_nic.id
    device_index         = 0
  }

  tags = {
    Name = "k8s-worker-b"
  }
}

resource "aws_network_interface" "k8s_worker_b_nic" {
  subnet_id            = aws_subnet.k8s_subnet_private_b.id
  security_groups      = [aws_security_group.k8s_security_group.id]
  private_ips          = ["10.0.0.11"]  # Exemplo, altere conforme sua necessidade
}
