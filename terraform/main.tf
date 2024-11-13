provider "aws" {
  region = var.availability_zone  
}

resource "aws_vpc" "k8s_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "k8s-vpc"
  }
}
resource "aws_subnet" "k8s_subnet_public_master" {
  vpc_id = aws_vpc.k8s_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "k8s-subnet-public-master"
  }
}
resource "aws_subnet" "k8s_subnet_public_a" {
  vpc_id = aws_vpc.k8s_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "k8s-subnet-public-a"
  }
}

resource "aws_subnet" "k8s_subnet_public_b" {
  vpc_id = aws_vpc.k8s_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1c"
  map_public_ip_on_launch = true
  tags = {
    Name = "k8s-subnet-public-b"
  }
}
resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id
  tags = {
    Name = "k8s-igw"
  }
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
  subnet_id      = aws_subnet.k8s_subnet_public_a.id
  route_table_id = aws_route_table.k8s_public_rt.id
}

resource "aws_route_table_association" "k8s_public_rt_assoc_b" {
  subnet_id      = aws_subnet.k8s_subnet_public_b.id
  route_table_id = aws_route_table.k8s_public_rt.id
}

resource "aws_route_table_association" "k8s_public_rt_assoc_master" {
  subnet_id      = aws_subnet.k8s_subnet_public_master.id
  route_table_id = aws_route_table.k8s_public_rt.id
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
    ingress {
    from_port   = 8080
    to_port     = 8080
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

resource "aws_security_group" "application_security_group" {
  vpc_id = aws_vpc.k8s_vpc.id
  name        = "application-security-group"
  description = "Allow traffic for apis"
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8000
    to_port     = 8000
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
resource "aws_instance" "k8s_master" {
  ami                         = var.ec2_ami_id
  instance_type               = "t3.medium"
  key_name                    = "k8-key"  
  iam_instance_profile        = "LabInstanceProfile"

  vpc_security_group_ids      = [ aws_security_group.application_security_group.id, aws_security_group.ingress_controller_sg.id, aws_security_group.k8s_security_group.id ]
  subnet_id                   =  aws_subnet.k8s_subnet_public_master.id

  tags = {
    Name = "k8s-Master"
  }
  user_data = <<-EOF
      #!/bin/bash
      echo "127.0.0.1 $HOSTNAME" >> /etc/hosts        
      yum install -y iproute-tc containerd        
      containerd config default > /etc/containerd/config.toml        
      sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml        
      systemctl enable containerd
      systemctl start containerd
      tee /etc/sysctl.d/k8s.conf <<EOT
  net.bridge.bridge-nf-call-ip6tables = 1
  net.bridge.bridge-nf-call-iptables = 1
  EOT
      sysctl --system        
      swapoff -a        
      setenforce 0
      sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
      cat <<EOT | sudo tee /etc/yum.repos.d/kubernetes.repo
  [kubernetes]
  name=Kubernetes
  baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
  enabled=1
  gpgcheck=1
  gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
  exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
  EOT
      yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes        
      systemctl enable --now kubelet        
      kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=1.30.1 --ignore-preflight-errors=all  
      kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
      curl https://get.helm.sh/helm-v3.10.0-linux-amd64.tar.gz -o helm-v3.10.0-linux-amd64.tar.gz
      tar -zxvf helm-v3.10.0-linux-amd64.tar.gz
      sudo mv linux-amd64/helm /usr/local/bin/helm

  EOF

}
resource "aws_instance" "k8s_worker" {
  count                       = var.number_ec2
  ami                         = var.ec2_ami_id
  instance_type               = "t3.medium"
  key_name                    = "k8-key"  
  iam_instance_profile        = "LabInstanceProfile"

  vpc_security_group_ids      = [ aws_security_group.application_security_group.id, aws_security_group.ingress_controller_sg.id, aws_security_group.k8s_security_group.id ]
  subnet_id                   = element([aws_subnet.k8s_subnet_public_a.id, aws_subnet.k8s_subnet_public_b.id], count.index) 

  tags = {
    Name = "k8s-worker${count.index + 1}"
  }
    user_data = <<-EOF
      #!/bin/bash
      echo "127.0.0.1 $HOSTNAME" >> /etc/hosts        
      yum install -y iproute-tc containerd        
      containerd config default > /etc/containerd/config.toml        
      sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml        
      systemctl enable containerd
      systemctl start containerd
      tee /etc/sysctl.d/k8s.conf <<EOT
  net.bridge.bridge-nf-call-ip6tables = 1
  net.bridge.bridge-nf-call-iptables = 1
  EOT
      sysctl --system        
      swapoff -a        
      setenforce 0
      sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
      cat <<EOT | sudo tee /etc/yum.repos.d/kubernetes.repo
  [kubernetes]
  name=Kubernetes
  baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
  enabled=1
  gpgcheck=1
  gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
  exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
  EOT
      yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes        
      systemctl enable --now kubelet        
      echo 1 > /proc/sys/net/ipv4/ip_forward               
  EOF
}

