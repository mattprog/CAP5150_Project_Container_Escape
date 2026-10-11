#!/usr/bin/env bash
set -euo pipefail
for profile in baseline user-isolation capabilities seccomp hardened; do
  "$(dirname "$0")/build.sh" "$profile"
done
