terraform {
  required_version = ">= 1.5"

  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 5.0" }
    tls   = { source = "hashicorp/tls", version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

provider "aws" {
  region = var.region
}

# ---------------------------------------------------------------- variables --

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.micro"
}

variable "ssh_cidr" {
  description = "CIDR allowed to SSH in (Ansible needs this). Narrow it to your own IP, e.g. 203.0.113.7/32"
  type        = string
  default     = "0.0.0.0/0"
}

# ---------------------------------------------------------------- image -------

# Look up the current Ubuntu 24.04 image instead of pinning an AMI ID,
# which is region-specific and eventually deregistered.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------- ssh key -----

# Terraform generates the deploy key, so no key pair has to be created by hand
# in the AWS console. The private key is written for Ansible and gitignored.
resource "tls_private_key" "deploy" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "deploy" {
  key_name_prefix = "real_chat-"
  public_key      = tls_private_key.deploy.public_key_openssh
}

resource "local_sensitive_file" "deploy_key" {
  content         = tls_private_key.deploy.private_key_openssh
  filename        = "${path.module}/../../ansible/deploy_key.pem"
  file_permission = "0600"
}

# ---------------------------------------------------------------- network -----

resource "aws_security_group" "real_chat_sg" {
  name_prefix = "real_chat-"
  description = "UniChat: SSH for Ansible, HTTP for the app"

  ingress {
    description = "SSH (Ansible)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "HTTP (nginx serves the app and proxies the API)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------- instance ----

resource "aws_instance" "real_chat" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.deploy.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.real_chat_sg.id]

  root_block_device {
    volume_size = 12
    volume_type = "gp3"
  }

  tags = {
    Name = "real_chat-Server"
  }
}

# ---------------------------------------------------------------- handoff -----

# The Terraform -> Ansible handoff: the inventory is written from the instance
# Terraform just created, so stage 6 can reach a server that did not exist
# when the build started.
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../ansible/inventory_generated.ini"
  content  = <<-EOT
    [ec2]
    ${aws_instance.real_chat.public_ip} ansible_user=ubuntu app_origin=http://${aws_instance.real_chat.public_ip}
  EOT
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.real_chat.public_ip
}

output "app_url" {
  description = "Where the deployed app is served"
  value       = "http://${aws_instance.real_chat.public_ip}"
}
