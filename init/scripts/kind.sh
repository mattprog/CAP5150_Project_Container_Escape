#!/bin/bash

set -e

# Install kind
echo "Installing kind..." >&2
curl -LsSo ~/kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
chmod +x ~/kind
mv ~/kind /usr/local/bin/kind