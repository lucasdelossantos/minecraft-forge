#!/bin/bash
set -e

# Install required packages
sudo yum update -y
sudo yum install -y java-17-amazon-corretto aws-cli jq

# Create minecraft directory
mkdir -p /opt/minecraft
cd /opt/minecraft

# Check for existing world backup
if aws s3 ls s3://${backup_bucket}/world.tar.gz; then
    echo "Found existing world backup, restoring..."
    aws s3 cp s3://${backup_bucket}/world.tar.gz .
    tar xzf world.tar.gz
    rm world.tar.gz
fi

# Download Forge installer
FORGE_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/${forge_version}/forge-${forge_version}-installer.jar"
wget $FORGE_URL

# Install Forge server
java -jar forge-*-installer.jar --installServer

# Create start script
cat << EOF > start.sh
#!/bin/bash
java -Xmx${minecraft_memory} -Xms${minecraft_memory} @libraries/net.minecraftforge/forge/*/unix_args.txt nogui
EOF
chmod +x start.sh

# Accept EULA
echo "eula=true" > eula.txt

# Create backup script
cat << 'EOF' > backup.sh
#!/bin/bash
cd /opt/minecraft
systemctl stop minecraft
tar czf world.tar.gz world
aws s3 cp world.tar.gz s3://${backup_bucket}/world.tar.gz
systemctl start minecraft
EOF
chmod +x backup.sh

# Create systemd service
cat << EOF > /etc/systemd/system/minecraft.service
[Unit]
Description=Minecraft Forge Server
After=network.target

[Service]
WorkingDirectory=/opt/minecraft
User=root
ExecStart=/opt/minecraft/start.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create backup timer service
cat << EOF > /etc/systemd/system/minecraft-backup.service
[Unit]
Description=Minecraft World Backup

[Service]
Type=oneshot
ExecStart=/opt/minecraft/backup.sh
EOF

cat << EOF > /etc/systemd/system/minecraft-backup.timer
[Unit]
Description=Run Minecraft backup every hour

[Timer]
OnBootSec=15min
OnUnitActiveSec=1h

[Install]
WantedBy=timers.target
EOF

# Start services
systemctl daemon-reload
systemctl enable minecraft
systemctl start minecraft
systemctl enable minecraft-backup.timer
systemctl start minecraft-backup.timer 