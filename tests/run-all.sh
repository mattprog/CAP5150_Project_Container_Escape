#!/usr/bin/env bash
set -uo pipefail

profile="${1:-}"
case "$profile" in
  baseline|user-isolation|capabilities|seccomp|hardened) ;;
  *) echo "usage: $0 {baseline|user-isolation|capabilities|seccomp|hardened}" >&2; exit 2 ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
status=0
for test_script in "$script_dir"/[0-9][0-9]-*.sh; do
  "$test_script" "$profile" || status=1
done

if [[ "$status" -eq 0 ]]; then
  echo "Runtime test suite completed for $profile"
else
  echo "Runtime test suite reported one or more failures for $profile" >&2
fi
exit "$status"
