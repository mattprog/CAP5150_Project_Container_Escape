#!/usr/bin/env bash
set -euo pipefail

cluster_name="container-escape-study"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v kind >/dev/null || { echo "kind must be installed first" >&2; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl must be installed first" >&2; exit 1; }

if kind get clusters | grep -Fxq "$cluster_name"; then
  echo "Kind cluster '$cluster_name' already exists"
else
  kind create cluster --name "$cluster_name" --config "$script_dir/cluster.yaml"
fi

kubectl config use-context "kind-$cluster_name" >/dev/null
kubectl cluster-info --context "kind-$cluster_name"
echo "Cluster '$cluster_name' is ready. Deploy a profile with: ./environment/scripts/build.sh <PROFILE>"
