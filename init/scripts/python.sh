#!/bin/bash

set -e

# Install python
echo "Installing python..." >&2

apt-get install -y python3 python3-pip
apt-get -y install python3-dev libpcap-dev libffi-dev libssl-dev python3-scapy python3-requests
apt-get -y install tcpdump wireshark