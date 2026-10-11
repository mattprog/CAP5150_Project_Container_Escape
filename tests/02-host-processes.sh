#!/usr/bin/env bash

# Imports shared functions and variables
source "$(dirname "$0")/lib.sh" "$@"

# TEST 2: Host process namespace isolation

# Configuration check for host PID (if able to see other container's processes)
host_pid="$(deployment_value '{.spec.template.spec.hostPID}')"
if [[ "$host_pid" == "true" ]]; then
  fail "hostPID is enabled"
fi

# Checks the runtime for namespace isolation
if exec_sh 'test -r /proc/1/status && test -r /proc/self/status'; then
  pass "hostPID is disabled and the pod has an isolated process view"
else
  fail "the pod process namespace could not be validated"
fi
