provider "aws" {
  region = "eu-north-1"
}


resource "aws_instance" "real_chat" {
  ami           = "ami-09a9858973b288bdd" 
  instance_type = "t3.micro"
  key_name      = "real_chat"

  vpc_security_group_ids = [aws_security_group.real_chat_sg.id]

  tags = {
    Name = "real_chat-Server"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker docker-compose
              systemctl start docker
              systemctl enable docker
              EOF
}

resource "aws_security_group" "real_chat_sg" {
  name        = "real_chat-security-group"
  description = "Allow SSH, HTTP, and custom ports"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  ingress {
    from_port   = 5173
    to_port     = 5173
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
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

output "instance_public_ip" {
  value = aws_instance.real_chat_server.public_ip
}