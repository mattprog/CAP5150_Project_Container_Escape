#!/usr/bin/env bash

# Imports shared functions and variables
source "$(dirname "$0")/lib.sh" "$@"

# TEST 4: Privileged mode

# Reads configuration to check for privileged permission
privileged="$(deployment_value '{.spec.template.spec.containers[0].securityContext.privileged}')"
if [[ "$privileged" == "true" ]]; then
  fail "privileged mode is enabled"
fi

# Gets user/group that being ran as and checks against expected value
identity="$(exec_sh 'id -u; id -g')"
if [[ "$PROFILE" == "user-isolation" ]]; then
  if [[ "$identity" == $'1000\n1000' ]]; then
    pass "privileged mode is disabled and the workload runs as UID/GID 1000"
  else
    fail "expected UID/GID 1000, observed: $identity"
  fi
elif [[ "$PROFILE" == "hardened" ]]; then
  if [[ "$identity" == $'10001\n10001' ]]; then
    pass "privileged mode is disabled and the hardened workload runs as UID/GID 10001"
  else
    fail "expected UID/GID 10001, observed: $identity"
  fi
else
  pass "privileged mode is disabled; this comparison profile intentionally retains its configured identity"
fi
