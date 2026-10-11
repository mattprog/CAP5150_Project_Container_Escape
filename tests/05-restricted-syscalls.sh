#!/usr/bin/env bash

# Imports shared functions and variables
source "$(dirname "$0")/lib.sh" "$@"

# TEST 5: Seccomp syscall

# Get the profile seccomp profile and kernel state
profile="$(deployment_value '{.spec.template.spec.containers[0].securityContext.seccompProfile.type}')"
seccomp_status="$(exec_sh "awk '/^Seccomp:/ {print \$2}' /proc/self/status")"

# Compare the established seccomp profile with reality
if [[ "$profile" == "RuntimeDefault" && "$seccomp_status" == "2" ]]; then
  pass "RuntimeDefault Seccomp is configured and the process reports filter mode"
elif [[ "$profile" == "Unconfined" && "$seccomp_status" == "0" ]]; then
  review "baseline is intentionally unconfined; no syscall-blocking claim is made"
else
  fail "configured profile ($profile) and process mode ($seccomp_status) disagree"
fi
