#!/usr/bin/env bash

# Imports shared functions and variables
source "$(dirname "$0")/lib.sh" "$@"

# TEST 1: Host filesystem

# Check for host path
host_paths="$(deployment_value '{.spec.template.spec.volumes[*].hostPath}')"
if [[ -n "$host_paths" ]]; then
  fail "hostPath volume is configured"
fi

# Log information for volume/container mounts
echo "INFO [$PROFILE] volume sources:"
pod_value '{range .spec.volumes[*]}{.name}{" hostPath="}{.hostPath.path}{" configMap="}{.configMap.name}{" secret="}{.secret.secretName}{" emptyDir="}{.emptyDir.medium}{"\n"}{end}'
echo "INFO [$PROFILE] container mounts (name path readOnly):"
pod_value '{range .spec.containers[*].volumeMounts[*]}{.name}{" "}{.mountPath}{" readOnly="}{.readOnly}{"\n"}{end}'

pass "no hostPath volume is configured; scoped application mounts are recorded and allowed"
