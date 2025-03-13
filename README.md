# Minecraft Forge Server on AWS

This repository contains Terraform configurations and GitHub Actions workflows to deploy and manage a Minecraft Forge server on AWS. The server automatically backs up the world to S3 and can be easily destroyed and recreated while preserving the world data.

## Prerequisites

- AWS Account with appropriate permissions
- GitHub Account
- Terraform installed locally (for initial setup)

### AWS Authentication

#### For Local Development (Initial Setup)
You need AWS credentials configured locally for the initial infrastructure setup. You can do this in one of two ways:

1. **Using AWS CLI** (Recommended):
   ```bash
   aws configure
   ```
   You'll be prompted to enter:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region (use `us-east-1`)
   - Default output format (can be left as default)

2. **Using Environment Variables**:
   ```bash
   export AWS_ACCESS_KEY_ID="your_access_key"
   export AWS_SECRET_ACCESS_KEY="your_secret_key"
   export AWS_REGION="us-east-1"
   ```

#### For GitHub Actions Deployment
No AWS credentials are needed in GitHub Actions. The deployment uses OIDC (OpenID Connect) for secure authentication with AWS. This is configured during the initial setup.

## Initial Setup

### 1. Deploy Initial Infrastructure

1. Navigate to the initial setup directory:
   ```bash
   cd terraform/initial-setup
   ```

2. Initialize and apply Terraform:
   ```bash
   terraform init
   # For personal GitHub accounts:
   terraform apply -var="github_org=YOUR_GITHUB_USERNAME" -var="github_repo=YOUR_REPO_NAME"
   # For organization accounts:
   terraform apply -var="github_org=YOUR_ORG_NAME" -var="github_repo=YOUR_REPO_NAME"
   ```

3. Save the outputs:
   - `aws_role_arn`: This will be your `AWS_ROLE_ARN` for GitHub Actions
   - `oidc_provider_arn`: ARN of the OIDC provider (for reference)
   - `state_bucket_name`: Name of the S3 bucket for Terraform state
   - `state_lock_table`: Name of the DynamoDB table for state locking

### 2. Configure GitHub Repository

1. Go to your GitHub repository settings
2. Navigate to Settings > Environments
3. Create a new environment (e.g., "minecraft")
4. Add these secrets:
   - `AWS_ROLE_ARN`: Use the `aws_role_arn` from step 1

## Deployment

### Deploying the Server

1. Go to your GitHub repository
2. Navigate to Actions > Deploy Minecraft Server
3. Click "Run workflow"

The deployment will:
- Create an EC2 instance with Amazon Linux 2
- Install Java 17 and Forge
- Set up automatic world backups every hour
- Configure the server to start automatically on boot
- Automatically configure security group to allow access from your IP address
- Generate a unique SSH key pair for server access
- Create a unique S3 bucket for world backups

### Server Details

- **Instance Type**: t3.medium (configurable in variables.tf)
- **Memory**: 4GB (configurable in variables.tf)
- **Forge Version**: 1.20.1-47.2.0 (configurable in variables.tf)
- **World Backup**: Every hour to S3
- **Server Port**: 25565
- **SSH Port**: 22
- **Access**: Automatically restricted to your IP address

### Accessing the Server

1. Get the server IP and private key path from the GitHub Actions output
2. Connect to the server:
   ```bash
   ssh -i minecraft-key.pem ec2-user@SERVER_IP
   ```
3. Minecraft server address: `SERVER_IP:25565`

Note: The server's security group automatically allows access only from the IP address that deployed it. If your IP changes, you'll need to redeploy the server to update the security group rules.

## Maintenance

### Automatic Backups

The server automatically backs up the world to S3 every hour. These backups are preserved even if the server is destroyed.

### Updating Forge

To update Forge:
1. Destroy the current server
2. Update the `forge_version` variable in `terraform/variables.tf`
3. Deploy a new server

The world will be automatically restored from the latest backup.

### Monitoring

- Server logs: `journalctl -u minecraft`
- Backup logs: `journalctl -u minecraft-backup`

## Destruction

To destroy the server:
1. Go to Actions > Destroy Minecraft Server
2. Click "Run workflow"

Note: The world backups in S3 will be preserved. The `prevent_destroy = true` lifecycle rule on the backup bucket prevents accidental deletion of backups.

## Troubleshooting

### Common Issues

1. **Server won't start**
   - Check logs: `journalctl -u minecraft`
   - Verify Java installation: `java -version`
   - Check Forge installation in `/opt/minecraft`

2. **Backups failing**
   - Check backup logs: `journalctl -u minecraft-backup`
   - Verify S3 permissions
   - Check disk space: `df -h`

3. **Connection issues**
   - Verify security group allows port 25565
   - Check server status: `systemctl status minecraft`
   - Verify server is running: `netstat -tulpn | grep 25565`

### Manual Backup

To manually trigger a backup:
```bash
sudo systemctl start minecraft-backup
```

## Security Notes

- The server is configured with a security group that automatically allows:
  - Minecraft traffic (port 25565) from your IP address only
  - SSH access (port 22) from your IP address only
- World backups are encrypted at rest in S3
- The server uses IAM roles for secure access to AWS services
- GitHub Actions uses OIDC for secure AWS authentication

## Cost Management

- The server runs on a t3.medium instance
- S3 storage for backups is charged per GB
- Consider destroying the server when not in use
- Monitor AWS billing dashboard for costs

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Security Considerations

### Network Security
- The server automatically detects and allows access only from the deploying machine's IP address
- All outbound traffic is allowed for server updates and backups
- Security group rules are automatically updated during deployment

### Access Control
- GitHub Actions uses OIDC for secure AWS authentication
- IAM roles follow the principle of least privilege
- Server backups are encrypted at rest in S3
- SSH access requires a key pair

### Best Practices
1. **IP Management**
   - Server access is automatically restricted to your IP
   - Redeploy the server if your IP changes
   - Consider using a VPN for remote access

2. **Backup Security**
   - Backups are encrypted at rest
   - Backup bucket has versioning enabled
   - Backup bucket cannot be accidentally deleted

3. **Monitoring**
   - Enable AWS CloudTrail for audit logging
   - Monitor server logs for suspicious activity
   - Set up alerts for failed login attempts

4. **Maintenance**
   - Keep Forge and Java updated
   - Regularly rotate SSH keys
   - Monitor AWS billing for unexpected charges 