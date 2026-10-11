#!/bin/bash

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo or as root." >&2
    exit 1
fi

echo "Running cloud environment setup..."

apt-get update > /dev/null

# Install basic dependencies
bash ./scripts/dependencies.sh > /dev/null

# Install python
bash ./scripts/python.sh > /dev/null

# Install ssh
bash ./scripts/ssh.sh > /dev/null

# Install Trivy
bash ./scripts/trivy.sh > /dev/null

# Install docker
bash ./scripts/docker.sh > /dev/null

# Install kind
bash ./scripts/kind.sh > /dev/null

# Install kubectl
bash ./scripts/kubectl.sh > /dev/null

# Install yq
bash ./scripts/yq.sh > /dev/null

# Install K9s
bash ./scripts/k9s.sh > /dev/null

echo "Cloud environment setup completed successfully"