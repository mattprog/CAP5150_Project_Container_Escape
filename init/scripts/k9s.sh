#!/bin/bash

set -e

# Install K9s
echo "Installing K9s..." >&2
wget -q -P ~/ https://github.com/derailed/k9s/releases/download/v0.51.0/k9s_linux_amd64.deb
dpkg -i ~/k9s_linux_amd64.deb