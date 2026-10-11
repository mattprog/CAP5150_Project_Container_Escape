#!/usr/bin/env bash
set -euo pipefail

# This is a set of helper functions for the container escape sections

# Ensures a profile was used as argument input
PROFILE="${1:-}"
case "$PROFILE" in
  baseline|user-isolation|capabilities|seccomp|hardened) ;;
  *) echo "usage: $0 PROFILE" >&2; exit 2 ;;
esac

# Ensures correct cluster and namespace are selectedfor that profile
NAMESPACE="escape-$PROFILE"
KUBE_CONTEXT_ARGS=()
if [[ -n "${KUBE_CONTEXT:-}" ]]; then
  KUBE_CONTEXT_ARGS=(--context "$KUBE_CONTEXT")
fi

# Helper function to reduce having to write shared kubectl syntax
k() { kubectl "${KUBE_CONTEXT_ARGS[@]}" "$@"; }

# Finds pod for the selected profile
POD="$(k get pod -n "$NAMESPACE" -l app.kubernetes.io/name=escape-target \
  -o jsonpath='{.items[0].metadata.name}')"
[[ -n "$POD" ]] || { echo "No escape-target pod found in $NAMESPACE" >&2; exit 1; }

# Helper functions for running specific actions within the container
# Shell command
exec_sh() { k exec -n "$NAMESPACE" "$POD" -- sh -c "$1"; }
# Get field from deployment configuration
deployment_value() { k get deployment escape-target -n "$NAMESPACE" -o "jsonpath=$1"; }
# Get field from running pod
pod_value() { k get pod "$POD" -n "$NAMESPACE" -o "jsonpath=$1"; }
# Get field from service
service_value() { k get service escape-target -n "$NAMESPACE" -o "jsonpath=$1"; }

# Returns formattted output message
pass() { echo "PASS [$PROFILE] $1"; }
fail() { echo "FAIL [$PROFILE] $1"; return 1; }
review() { echo "REVIEW [$PROFILE] $1"; }