#!/bin/bash

set -e

# Install ssh
echo "Installing ssh..." >&2

apt-get update -y
apt-get install openssh-server -y
systemctl enable --now ssh -q

echo "IMPORTANT: Creating user sshuser with password sshreguser" >&2
useradd -d "/home/sshuser" -m -k /etc/skel -s "/bin/bash" "sshuser"
chown sshuser:sshuser -R /home/sshuser
echo "sshuser:sshreguser" | chpasswd
usermod -aG sudo "sshuser"