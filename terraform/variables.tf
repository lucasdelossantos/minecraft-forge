variable "ami_id" {
  description = "AMI ID for Amazon Linux 2"
  type        = string
  default     = "ami-05c13eab67c5d8861"  # Amazon Linux 2 in us-east-1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "forge_version" {
  description = "Minecraft Forge version"
  type        = string
  default     = "1.20.1-47.2.0"
}

variable "server_memory" {
  description = "Amount of memory to allocate to the server"
  type        = string
  default     = "4G"
} 