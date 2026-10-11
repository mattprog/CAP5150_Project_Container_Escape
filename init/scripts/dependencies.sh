#!/bin/bash

set -e

# Install basic dependencies
echo "Installing basic dependencies..." >&2
apt-get update
apt-get upgrade -y
apt-get install -y curl wget gnupg lsb-release apt-transport-https ca-certificates software-properties-common

echo "Adding upgraded fs watcher entries..." >&2
cat <<EOF >> /etc/sysctl.conf
fs.inotify.max_user_watches=1048576
fs.inotify.max_user_instances=8192
EOF

sysctl -p