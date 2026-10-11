#!/bin/bash

set -e

# Install Trivy
echo "Installing Trivy scanner..." >&2
apt-get install wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | tee -a /etc/apt/sources.list.d/trivy.list
apt-get update
apt-get install trivy

# Get updated database
trivy image --download-db-only -q
trivy image --download-java-db-only -q
trivy config . -q > /dev/null