#!/usr/bin/env bash
set -euo pipefail
 
requested_profile="${1:-}"
if [[ -n "$requested_profile" ]]; then
  case "$requested_profile" in
    baseline|user-isolation|capabilities|seccomp|hardened) profiles=("$requested_profile") ;;
    *) echo "usage: $0 [baseline|user-isolation|capabilities|seccomp|hardened]" >&2; exit 2 ;;
  esac
else
  profiles=(baseline user-isolation capabilities seccomp hardened)
fi
command -v kubectl >/dev/null || { echo "kubectl is required" >&2; exit 1; }
 
KUBE_CONTEXT_ARGS=()
if [[ -n "${KUBE_CONTEXT:-}" ]]; then
  KUBE_CONTEXT_ARGS=(--context "$KUBE_CONTEXT")
fi
k() { kubectl ${KUBE_CONTEXT_ARGS[@]+"${KUBE_CONTEXT_ARGS[@]}"} "$@"; }
 
exit_status=0
controls_rows=()
exposure_rows=()
notes=()
 
for profile in "${profiles[@]}"; do
  namespace="escape-$profile"
  if ! k get deployment escape-target -n "$namespace" >/dev/null 2>&1; then
    controls_rows+=("$(printf '%-18s %s' "$profile" 'not deployed')")
    exposure_rows+=("$(printf '%-18s %s' "$profile" 'not deployed')")
    [[ -n "$requested_profile" ]] && exit_status=1
    continue
  fi
  get() { k get deployment escape-target -n "$namespace" -o "jsonpath=$1"; }
 
  # Read each field once
  nonroot="$(get '{.spec.template.spec.containers[0].securityContext.runAsNonRoot}')"
  [[ -n "$nonroot" ]] || nonroot="$(get '{.spec.template.spec.securityContext.runAsNonRoot}')"
  allow_pe="$(get '{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}')"
  cap_drop="$(get '{.spec.template.spec.containers[0].securityContext.capabilities.drop}')"
  cap_add="$(get '{.spec.template.spec.containers[0].securityContext.capabilities.add}')"
  seccomp="$(get '{.spec.template.spec.containers[0].securityContext.seccompProfile.type}')"
  [[ -n "$seccomp" ]] || seccomp="$(get '{.spec.template.spec.securityContext.seccompProfile.type}')"
  host_path="$(get '{.spec.template.spec.volumes[*].hostPath}')"
  host_pid="$(get '{.spec.template.spec.hostPID}')"
  host_net="$(get '{.spec.template.spec.hostNetwork}')"
  privileged="$(get '{.spec.template.spec.containers[0].securityContext.privileged}')"
  token="$(get '{.spec.template.spec.automountServiceAccountToken}')"
 
  # Section 1 - controls (ON/OFF)
  [[ "$nonroot" == "true" ]]          && c_root=ON    || c_root=OFF
  [[ "$allow_pe" == "false" ]]        && c_pe=ON      || c_pe=OFF
  [[ "$cap_drop" == *ALL* ]]          && c_caps=ON    || c_caps=OFF
  [[ "$seccomp" == "RuntimeDefault" ]] && c_seccomp=ON || c_seccomp=OFF
  controls_rows+=("$(printf '%-18s %-10s %-14s %-14s %-10s' "$profile" "$c_root" "$c_pe" "$c_caps" "$c_seccomp")")
  if [[ -n "$cap_add" ]]; then
    notes+=("$profile: capabilities added back after the drop: $cap_add")
  fi
 
  # Section 2 - exposures (PASS / REVIEW / FAIL)
  [[ -z "$host_path" ]]                && x_fs=PASS    || x_fs=FAIL
  [[ "$host_pid" != "true" ]]          && x_procs=PASS || x_procs=FAIL
  [[ "$host_net" != "true" ]]          && x_net=PASS   || x_net=FAIL
  [[ "$privileged" != "true" ]]        && x_priv=PASS  || x_priv=FAIL
  [[ "$seccomp" == "RuntimeDefault" ]] && x_sys=PASS   || x_sys=REVIEW
  [[ "$token" == "false" ]]            && x_info=PASS  || x_info=FAIL
  exposure_rows+=("$(printf '%-18s %-10s %-12s %-10s %-12s %-10s %-13s' \
    "$profile" "$x_fs" "$x_procs" "$x_net" "$x_priv" "$x_sys" "$x_info")")
  if [[ "$x_fs$x_procs$x_net$x_priv$x_info" == *FAIL* ]]; then
    exit_status=1
  fi
done
 
echo "CONTROLS (ON = enabled; baseline and comparison profiles intentionally leave some OFF)"
printf '%-18s %-10s %-14s %-14s %-10s\n' PROFILE NON-ROOT NO-PRIV-ESC CAPS-DROPPED SECCOMP
if [[ ${#controls_rows[@]} -gt 0 ]]; then printf '%s\n' "${controls_rows[@]}"; fi
echo
echo "EXPOSURES (PASS = risky setting absent; REVIEW = needs a human; FAIL = exposure present)"
printf '%-18s %-10s %-12s %-10s %-12s %-10s %-13s\n' PROFILE HOST-FS HOST-PROCS HOST-NET PRIVILEGED SYSCALLS RUNTIME-INFO
if [[ ${#exposure_rows[@]} -gt 0 ]]; then printf '%s\n' "${exposure_rows[@]}"; fi
 
if [[ ${#notes[@]} -gt 0 ]]; then
  echo
  printf 'note: %s\n' "${notes[@]}"
fi
 
echo
echo "Configuration-only checks; no breakout payloads or host probes are executed."
echo "SYSCALLS and the SECCOMP control read the same field; RUNTIME-INFO is the service-account token automount."
exit "$exit_status"