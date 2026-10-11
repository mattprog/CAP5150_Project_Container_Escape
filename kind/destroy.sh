#!/usr/bin/env bash
set -euo pipefail

cluster_name="container-escape-study"
command -v kind >/dev/null || { echo "kind must be installed first" >&2; exit 1; }

if kind get clusters | grep -Fxq "$cluster_name"; then
  kind delete cluster --name "$cluster_name"
  echo "Deleted Kind cluster '$cluster_name'"
else
  echo "Kind cluster '$cluster_name' does not exist"
fi
