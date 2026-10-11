#!/usr/bin/env bash
set -euo pipefail

profile="${1:-}"
case "$profile" in
  baseline|user-isolation|capabilities|seccomp|hardened) ;;
  *) echo "usage: $0 {baseline|user-isolation|capabilities|seccomp|hardened}" >&2; exit 2 ;;
esac

command -v kubectl >/dev/null || { echo "kubectl is required" >&2; exit 1; }
namespace="escape-$profile"
if kubectl get namespace "$namespace" >/dev/null 2>&1; then
  kubectl delete namespace "$namespace" --wait=true
else
  echo "$namespace does not exist"
fi
