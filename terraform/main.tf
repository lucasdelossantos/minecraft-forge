terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "minecraft-forge-state-bucket"
    key            = "minecraft/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "minecraft-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# Get current IP address
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

locals {
  my_ip = "${data.http.my_ip.response_body}/32"
  # Generate a unique name for the backup bucket
  backup_bucket_name = "minecraft-forge-backup-${random_id.bucket_suffix.hex}"
}

# Generate random suffix for bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Generate SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair
resource "aws_key_pair" "minecraft_key" {
  key_name   = "minecraft-key-${random_id.bucket_suffix.hex}"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Save private key to local file
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "minecraft-key.pem"
  file_permission = "0600"
}

# S3 bucket for world backups
resource "aws_s3_bucket" "minecraft_backups" {
  bucket = local.backup_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "minecraft_backups" {
  bucket = aws_s3_bucket.minecraft_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

# IAM role for EC2 instance
resource "aws_iam_role" "minecraft_server" {
  name = "minecraft-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for S3 access
resource "aws_iam_role_policy" "minecraft_s3_access" {
  name = "minecraft-s3-access"
  role = aws_iam_role.minecraft_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.minecraft_backups.arn,
          "${aws_s3_bucket.minecraft_backups.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "minecraft_profile" {
  name = "minecraft-server-profile"
  role = aws_iam_role.minecraft_server.name
}

# Security group
resource "aws_security_group" "minecraft" {
  name        = "minecraft-forge-server"
  description = "Security group for Minecraft Forge server"

  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = [local.my_ip]  # Use current IP
    description = "Minecraft server port"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip]  # Use current IP
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Minecraft-Forge-Server"
  }
}

# EC2 Instance
resource "aws_instance" "minecraft_server" {
  ami           = var.ami_id
  instance_type = var.instance_type

  security_groups        = [aws_security_group.minecraft.name]
  key_name              = aws_key_pair.minecraft_key.key_name
  iam_instance_profile  = aws_iam_instance_profile.minecraft_profile.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    forge_version    = var.forge_version
    minecraft_memory = var.server_memory
    backup_bucket    = aws_s3_bucket.minecraft_backups.id
    aws_region       = "us-east-1"
  })

  tags = {
    Name = "Minecraft-Forge-Server"
  }
}

# Output the server IP and key file location
output "server_ip" {
  value = aws_instance.minecraft_server.public_ip
}

output "private_key_path" {
  value = local_file.private_key.filename
} 