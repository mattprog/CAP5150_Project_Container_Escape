#!/bin/bash

set -e

# Install yq
echo "Installing yq..." >&2
wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq