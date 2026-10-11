#!/usr/bin/env bash

# Imports shared functions and variables
source "$(dirname "$0")/lib.sh" "$@"

# TEST 3: Host network namespace isolation

# Configuration check for host network (interact with other things on same network as host)
host_network="$(deployment_value '{.spec.template.spec.hostNetwork}')"
if [[ "$host_network" == "true" ]]; then
  fail "hostNetwork is enabled"
fi

# Checks the runtime for network isolation
if exec_sh 'test -r /proc/net/route && test -r /etc/hostname'; then
  pass "hostNetwork is disabled and pod network files are available"
else
  fail "the pod network namespace could not be validated"
fi
