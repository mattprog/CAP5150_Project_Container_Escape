#!/usr/bin/env bash

# Imports shared functions and variables
source "$(dirname "$0")/lib.sh" "$@"

# TEST 6: Service account

# Configuration check for service account token
automount="$(deployment_value '{.spec.template.spec.automountServiceAccountToken}')"
if [[ "$automount" != "false" ]]; then
  fail "service-account-token automount is not disabled"
fi

# Runtime check for the service account token
if exec_sh 'test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token'; then
  pass "service-account token is not mounted in the workload"
else
  fail "a service-account token is visible inside the workload"
fi
