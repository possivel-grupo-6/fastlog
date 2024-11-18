terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region = var.region
}


locals {
  retry_join = "provider=aws tag_key=NomadJoinTag tag_value=auto-join"
}

resource "aws_vpc" "nomad_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "nomad-vpc"
  }
}

resource "aws_internet_gateway" "nomad_igw" {
  vpc_id = aws_vpc.nomad_vpc.id
  tags = {
    Name = "nomad-igw"
  }
}

resource "aws_subnet" "nomad_subnet_1" {
  vpc_id            = aws_vpc.nomad_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "nomad-subnet-1"
  }
}

resource "aws_subnet" "nomad_subnet_2" {
  vpc_id            = aws_vpc.nomad_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "nomad-subnet-2"
  }
}

resource "aws_subnet" "nomad_subnet_3" {
  vpc_id            = aws_vpc.nomad_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1c"
  tags = {
    Name = "nomad-subnet-3"
  }
}
resource "aws_security_group" "nomad_ui_ingress" {
  name   = "${var.name}-ui-ingress"
  vpc_id = aws_vpc.nomad_vpc.id

  # Nomad
  ingress {
    from_port       = 4646
    to_port         = 4646
    protocol        = "tcp"
    cidr_blocks     = [var.allowlist_ip]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssh_ingress" {
  name   = "${var.name}-ssh-ingress"
  vpc_id = aws_vpc.nomad_vpc.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowlist_ip]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_all_internal" {
  name   = "${var.name}-allow-all-internal"
  vpc_id =  aws_vpc.nomad_vpc.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
}

resource "aws_security_group" "clients_ingress" {
  name   = "${var.name}-clients-ingress"
  vpc_id = aws_vpc.nomad_vpc.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


data "aws_ami" "ubuntu" {
  most_recent      = true
  owners           = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "tf-key"
  public_key = tls_private_key.private_key.public_key_openssh
}

# Uncomment the private key resource below if you want to SSH to any of the instances
# Run init and apply again after uncommenting:
# terraform init && terraform apply
# Then SSH with the tf-key.pem file:
# ssh -i tf-key.pem ubuntu@INSTANCE_PUBLIC_IP

resource "local_file" "tf_pem" {
  filename = "${path.module}/tf-key.pem"
  content = tls_private_key.private_key.private_key_pem
  file_permission = "0400"
}

resource "aws_instance" "server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.server_instance_type
  key_name               = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.nomad_ui_ingress.id, aws_security_group.ssh_ingress.id, aws_security_group.allow_all_internal.id]
  count                  = var.server_count
  iam_instance_profile   = "LabInstanceProfile"
  subnet_id = element(
    [aws_subnet.nomad_subnet_1.id, aws_subnet.nomad_subnet_2.id, aws_subnet.nomad_subnet_3.id],
    count.index
  )

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.private_key.private_key_pem
    host        = self.public_ip
  }

  # NomadJoinTag is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name}-server-${count.index}"
    },
    {
      "NomadJoinTag" = "auto-join"
    },
    {
      "NomadType" = "server"
    }
  )

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  provisioner "remote-exec" {
    inline = ["sudo mkdir -p /ops", "sudo chmod 777 -R /ops"]
  }

  provisioner "file" {
    source      = "../shared"
    destination = "/ops"
  }

  user_data = templatefile("../shared/data-scripts/user-data-server.sh", {
    server_count              = var.server_count
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = local.retry_join
    nomad_version             = var.nomad_version
  })

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

resource "aws_instance" "client" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.client_instance_type
  key_name               = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.nomad_ui_ingress.id, aws_security_group.ssh_ingress.id, aws_security_group.clients_ingress.id, aws_security_group.allow_all_internal.id]
  count                  = var.client_count
  iam_instance_profile   = "LabInstanceProfile"
  subnet_id = element(
    [aws_subnet.nomad_subnet_1.id, aws_subnet.nomad_subnet_2.id, aws_subnet.nomad_subnet_3.id],
    count.index
  )

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.private_key.private_key_pem
    host        = self.public_ip
  }

  # NomadJoinTag is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name}-client-${count.index}"
    },
    {
      "NomadJoinTag" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  ebs_block_device {
    device_name           = "/dev/xvdd"
    volume_type           = "gp2"
    volume_size           = "50"
    delete_on_termination = "true"
  }

  provisioner "remote-exec" {
    inline = ["sudo mkdir -p /ops", "sudo chmod 777 -R /ops"]
  }

  provisioner "file" {
    source      = "../shared"
    destination = "/ops"
  }

  user_data = templatefile("../shared/data-scripts/user-data-client.sh", {
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = local.retry_join
    nomad_version             = var.nomad_version
  })

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

####################################################################
# LB
####################################################################

# resource "aws_lb" "nomad_lb" {
#   name               = "nomad-lb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.nomad_ui_ingress.id, aws_security_group.ssh_ingress.id, aws_security_group.clients_ingress.id, aws_security_group.allow_all_internal.id]
#   subnets = [
#     aws_subnet.nomad_subnet_1.id,
#     aws_subnet.nomad_subnet_2.id,
#     aws_subnet.nomad_subnet_3.id,
#   ]
# }

# resource "aws_lb_listener" "nomad_https" {
#   load_balancer_arn = aws_lb.nomad_lb.arn
#   port              = "443"
#   protocol          = "HTTPS"

#   ssl_policy      = "ELBSecurityPolicy-2016-08"
#   certificate_arn = var.certificate

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.nomad.arn
#   }
# }

# resource "aws_lb_listener" "http_listener" {
#   load_balancer_arn = aws_lb.nomad_lb.arn
#   port              = "80"
#   protocol          = "HTTP"
#   default_action {
#     type = "redirect"
#     redirect {
#       protocol    = "HTTPS"
#       port        = "443"
#       status_code = "HTTP_301"
#     }
#   }
# }

# resource "aws_lb_target_group" "nomad" {
#   name        = "nomad-tg"
#   port        = 8200
#   protocol    = "HTTP"
#   vpc_id      = aws_vpc.nomad_vpc.id
#   target_type = "instance"

#   health_check {
#     interval            = 30
#     path                = "/v1/sys/health"
#     protocol            = "HTTP"
#     timeout             = 5
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#     matcher             = "200-399"
#   }
# }

# resource "aws_lb_target_group_attachment" "nomad_attachment" {
#   count            = var.server_count
#   target_group_arn = aws_lb_target_group.nomad.arn
#   target_id        = aws_instance.server[count.index].id
#   port             = 4646
# }
# resource "aws_route53_record" "lb_dns_record" {
#   zone_id = var.zone
#   name    = "miziara.xyz"
#   type    = "A"

#   alias {
#     name                   = aws_lb.nomad_lb.dns_name
#     zone_id                = aws_lb.nomad_lb.zone_id
#     evaluate_target_health = true
#   }
# }
