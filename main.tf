provider "aws" {
  region  = "us-east-1"
  profile = "default" # Uses aws configure
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Generate a new SSH key pair
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "terraform_key" {
  key_name   = "terraform_user"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Save private key to a .pem file locally
resource "local_file" "pem_file" {
  content              = tls_private_key.ec2_key.private_key_pem
  filename             = "${path.module}/terraform_user.pem"
  file_permission      = "0400"
}

resource "aws_security_group" "terraform_sg" {
  name        = "terraform_sg"
  description = "Allow SSH inbound and all outbound"

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

resource "aws_instance" "terraform_test" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.terraform_key.key_name
  vpc_security_group_ids = [aws_security_group.terraform_sg.id]

  tags = {
    Name = "tf_server-1"
  }
}

# Output public IP and SSH command
output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.terraform_test.public_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i terraform_user.pem ec2-user@${aws_instance.terraform_test.public_ip}"
}
