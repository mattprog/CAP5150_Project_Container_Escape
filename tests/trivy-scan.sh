#!/usr/bin/env bash
set -uo pipefail

profile="${1:-}"
case "$profile" in
  baseline|user-isolation|capabilities|seccomp|hardened) ;;
  *) echo "usage: $0 {baseline|user-isolation|capabilities|seccomp|hardened}" >&2; exit 2 ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
reports_dir="$repo_dir/reports"
overlay="$repo_dir/environment/overlays/$profile"
timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
report="$reports_dir/trivy-${profile}-${timestamp}.log"
summary="$reports_dir/trivy-summary-${profile}-${timestamp}.txt"
config_html="$reports_dir/trivy-config-${profile}-${timestamp}.html"
image_html="$reports_dir/trivy-image-${profile}-${timestamp}.html"
html_template="${TRIVY_HTML_TEMPLATE:-/usr/local/share/trivy/templates/html.tpl}"
temp_dir="$(mktemp -d)"
manifest="$temp_dir/${profile}-kustomize.yaml"
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "$reports_dir"

overall_status=0
config_status=NOT_RUN
image_status=NOT_RUN
config_html_status=NOT_RUN
image_html_status=NOT_RUN

{
  echo "Trivy evaluation report"
  echo "Profile: $profile"
  echo "Created (UTC): $timestamp"
  echo "Scope: Kubernetes configuration plus workload image vulnerabilities"
  echo "HTML configuration report: $config_html"
  echo "HTML image report: $image_html"
  echo ""

  if ! command -v trivy >/dev/null 2>&1; then
    echo "ERROR: trivy is required but was not found on PATH"
    overall_status=127
  elif ! command -v kubectl >/dev/null 2>&1; then
    echo "ERROR: kubectl is required but was not found on PATH"
    overall_status=127
  else
    echo "===== CONFIGURATION SCAN: $overlay ====="
    if kubectl kustomize "$overlay" > "$manifest"; then
      trivy config --misconfig-scanners kubernetes --skip-check-update --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL --exit-code 0 "$manifest"
      config_status=$?
      if [[ -f "$html_template" ]]; then
        trivy config --misconfig-scanners kubernetes --skip-check-update --format template --template "@$html_template" --output "$config_html" "$manifest" >/dev/null 2>&1
        config_html_status=$?
      else
        echo "WARNING: HTML template not found at $html_template"
        config_html_status=REVIEW
      fi
    else
      echo "ERROR: unable to render $overlay with Kustomize"
      config_status=1
    fi
    [[ "$config_status" -eq 0 ]] || overall_status=1
    [[ "$config_html_status" == "0" || "$config_html_status" == "REVIEW" ]] || overall_status=1
    echo "Configuration scanner exit status: $config_status"
    echo ""

    echo "===== IMAGE SCAN ====="
    if [[ -s "$manifest" ]]; then
      image="$(awk '/^[[:space:]]+image:[[:space:]]/ {print $2; exit}' "$manifest")"
    else
      image=""
    fi
    if [[ -z "$image" ]]; then
      echo "ERROR: could not determine a container image from the rendered manifest"
      image_status=1
    else
      echo "Image: $image"
      image_output="$temp_dir/image-scan.log"
      trivy image --image-src remote --scanners vuln --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL --exit-code 0 "$image" > "$image_output" 2>&1
      image_status=$?
      cat "$image_output"
      if grep -q 'Supported files for scanner(s) not found' "$image_output"; then
        image_status=REVIEW
        echo "Image scan result: REVIEW (the image has no supported package files for Trivy's vulnerability scanner)"
      fi
      if [[ -f "$html_template" ]]; then
        trivy image --image-src remote --scanners vuln --format template --template "@$html_template" --output "$image_html" "$image" >/dev/null 2>&1
        image_html_status=$?
      else
        echo "WARNING: HTML template not found at $html_template"
        image_html_status=REVIEW
      fi
    fi
    [[ "$image_status" == "0" || "$image_status" == "REVIEW" ]] || overall_status=1
    [[ "$image_html_status" == "0" || "$image_html_status" == "REVIEW" ]] || overall_status=1
    echo "Image scanner exit status: $image_status"
    echo ""
    echo "Trivy findings are reported for review; --exit-code 0 prevents findings from being confused with scanner errors."
    echo "This scan supplements, but does not replace, the Kubernetes escape-control tests."
  fi
} > "$report" 2>&1
cat "$report"

{
  echo "Trivy evaluation summary"
  echo "Profile: $profile"
  echo "Created (UTC): $timestamp"
  echo "Full Trivy report: $report"
  echo ""
  printf '%-24s %s\n' CHECK RESULT
  printf '%-24s %s\n' '------------------------' '------'
  printf '%-24s %s\n' configuration "$config_status"
  printf '%-24s %s\n' image "$image_status"
  printf '%-24s %s\n' configuration-html "$config_html_status"
  printf '%-24s %s\n' image-html "$image_html_status"
  if [[ "$overall_status" -eq 0 ]]; then
    echo "Overall scanner result: PASS"
  else
    echo "Overall scanner result: FAIL"
  fi
  echo "Note: vulnerability findings do not change scanner exit status; scanner or rendering errors do. REVIEW means the scanner completed without producing a vulnerability result."
} > "$summary"

echo "Trivy report: $report"
echo "Trivy summary: $summary"
echo "Trivy configuration HTML: $config_html"
echo "Trivy image HTML: $image_html"
exit "$overall_status"
