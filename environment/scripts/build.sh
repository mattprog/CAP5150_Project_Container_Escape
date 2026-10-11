#!/usr/bin/env bash
set -euo pipefail

profile="${1:-}"
case "$profile" in
  baseline|user-isolation|capabilities|seccomp|hardened) ;;
  *) echo "usage: $0 {baseline|user-isolation|capabilities|seccomp|hardened}" >&2; exit 2 ;;
esac

command -v kubectl >/dev/null || { echo "kubectl is required" >&2; exit 1; }
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
overlay="$repo_dir/overlays/$profile"
echo "Rendering $profile with Kustomize..."
kubectl kustomize "$overlay" >/dev/null
echo "Applying $profile to namespace escape-$profile..."
kubectl apply -k "$overlay"
kubectl -n "escape-$profile" rollout status deployment/escape-target --timeout=120s
