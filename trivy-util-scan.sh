# Util script to create configuration/image scan baselines and place them in profile directories

html_template=/usr/local/share/trivy/templates/html.tpl

for profile in baseline user-isolation capabilities seccomp hardened; do
  overlay="environment/overlays/$profile"
  temp_dir="$(mktemp -d)"
  manifest="$temp_dir/${profile}-kustomize.yaml"

  kubectl kustomize "$overlay" > "$manifest"

  trivy config \
    --misconfig-scanners kubernetes \
    --skip-check-update \
    --format template \
    --template "@$html_template" \
    --output "$overlay/trivy-config.html" \
    "$manifest" > "$overlay/trivy-config.log" 2>&1

  image="$(kubectl kustomize "environment/overlays/$profile" | awk '/^[[:space:]]+image:[[:space:]]/ {print $2; exit}')"

  trivy image \
    --image-src remote \
    --scanners vuln \
    --format template \
    --template "@$html_template" \
    --output "$overlay/trivy-image.html" \
    "$image" > "$overlay/trivy-image.log" 2>&1

  rm -rf "$temp_dir"
  echo "$profile: Trivy snapshots saved under $overlay"
done