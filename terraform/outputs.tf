output "public_ip" {
  description = "Public IP of the Minecraft server"
  value       = aws_instance.minecraft_server.public_ip
}

output "backup_bucket" {
  description = "S3 bucket for world backups"
  value       = aws_s3_bucket.minecraft_backups.id
} 