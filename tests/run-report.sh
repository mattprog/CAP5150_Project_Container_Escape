#!/usr/bin/env bash
set -uo pipefail

profile="${1:-}"
runs="${2:-3}"
case "$profile" in
  baseline|user-isolation|capabilities|seccomp|hardened) ;;
  *) echo "usage: $0 PROFILE [RUNS, default 3]" >&2; exit 2 ;;
esac
if [[ ! "$runs" =~ ^[1-9][0-9]*$ || "$runs" -gt 10 ]]; then
  echo "RUNS must be an integer from 1 to 10" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
reports_dir="$repo_dir/reports"
timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
full_report="$reports_dir/evaluation-${profile}-${timestamp}.log"
summary_report="$reports_dir/evaluation-summary-${profile}-${timestamp}.txt"
namespace="escape-$profile"
mkdir -p "$reports_dir"

static_scripts=(
  "$script_dir/config-audit.sh"
  "$script_dir/trivy-scan.sh"
)
runtime_scripts=(
  "$script_dir/01-host-filesystem.sh"
  "$script_dir/02-host-processes.sh"
  "$script_dir/03-host-network.sh"
  "$script_dir/04-privileged-operations.sh"
  "$script_dir/05-restricted-syscalls.sh"
  "$script_dir/06-runtime-information.sh"
  "$script_dir/07-effective-security.sh"
  "$script_dir/08-workload-functionality.sh"
  "$script_dir/09-behavioral-probes.sh"
)
overall_status=0
declare -A passed_counts
declare -A total_counts

{
  echo "Container-escape evaluation report"
  echo "Profile: $profile"
  echo "Runtime rounds: $runs"
  echo "Created (UTC): $timestamp"
  echo "Static audits and Trivy run once; readiness and in-pod checks run each round."
  echo "Each command's complete stdout and stderr follows without filtering."
  echo ""
} > "$full_report"

{
  echo "Container-escape evaluation summary"
  echo "Profile: $profile"
  echo "Runtime rounds: $runs"
  echo "Created (UTC): $timestamp"
  echo "Full log: $full_report"
  echo ""
  printf '%-42s %s\n' CHECK RESULT
  printf '%-42s %s\n' '------------------------------------------' '------'
} > "$summary_report"

run_logged() {
  local label="$1"
  shift
  local command_status
  {
    echo "===== BEGIN $label ====="
    "$@"
    command_status=$?
    echo "===== END $label (exit $command_status) ====="
    echo ""
  } >> "$full_report" 2>&1
  return "$command_status"
}

for evaluation_script in "${static_scripts[@]}"; do
  script_name="$(basename "$evaluation_script")"
  if run_logged "$script_name ($profile)" "$evaluation_script" "$profile"; then
    printf '%-42s %s\n' "$script_name" PASS >> "$summary_report"
  else
    script_status=$?
    printf '%-42s FAIL (exit %s)\n' "$script_name" "$script_status" >> "$summary_report"
    overall_status=1
  fi
done

KUBE_CONTEXT_ARGS=()
if [[ -n "${KUBE_CONTEXT:-}" ]]; then
  KUBE_CONTEXT_ARGS=(--context "$KUBE_CONTEXT")
fi
for ((round = 1; round <= runs; round++)); do
  readiness_label="round-$round/deployment-readiness"
  if run_logged "$readiness_label" kubectl "${KUBE_CONTEXT_ARGS[@]}" -n "$namespace" rollout status deployment/escape-target --timeout=15s; then
    printf '%-42s %s\n' "$readiness_label" PASS >> "$summary_report"
  else
    readiness_status=$?
    printf '%-42s FAIL (exit %s)\n' "$readiness_label" "$readiness_status" >> "$summary_report"
    overall_status=1
  fi

  for evaluation_script in "${runtime_scripts[@]}"; do
    script_name="$(basename "$evaluation_script")"
    check_key="$script_name"
    total_counts["$check_key"]=$(( ${total_counts["$check_key"]:-0} + 1 ))
    run_label="round-$round/$script_name"
    if run_logged "$run_label ($profile)" "$evaluation_script" "$profile"; then
      passed_counts["$check_key"]=$(( ${passed_counts["$check_key"]:-0} + 1 ))
      printf '%-42s %s\n' "$run_label" PASS >> "$summary_report"
    else
      script_status=$?
      printf '%-42s FAIL (exit %s)\n' "$run_label" "$script_status" >> "$summary_report"
      overall_status=1
    fi
  done
done

{
  echo ""
  echo "Runtime check pass counts:"
  for evaluation_script in "${runtime_scripts[@]}"; do
    script_name="$(basename "$evaluation_script")"
    printf '%-34s %s/%s\n' "$script_name" "${passed_counts["$script_name"]:-0}" "${total_counts["$script_name"]:-0}"
  done
  if [[ "$overall_status" -eq 0 ]]; then
    echo "Overall result: PASS"
  else
    echo "Overall result: FAIL"
  fi
  echo "Compatibility outcome is recorded by 08-workload-functionality.sh in each round."
  echo "REVIEW lines do not fail a script unless it also exits nonzero."
} >> "$summary_report"

echo "Full report: $full_report"
echo "Summary report: $summary_report"
exit "$overall_status"
