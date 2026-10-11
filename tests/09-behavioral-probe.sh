#!/usr/bin/env bash

# Imports shared functions and variables
source "$(dirname "$0")/lib.sh" "$@"

# TEST 9: Behavioral probes (what the process can actually do)

status=0
PROC_THRESHOLD="${PROC_THRESHOLD:-25}"   # more visible PIDs than this => host PID namespace
DEV_THRESHOLD="${DEV_THRESHOLD:-30}"     # more /dev entries than this => host devices exposed

# What each profile is expected to allow, keyed by "<probe>:<profile>".
expected_for() {
  case "$1:$PROFILE" in
    # 07 - capabilities
    raw-socket:baseline|raw-socket:seccomp) echo ALLOWED ;;=
    raw-socket:*) echo DENIED ;;
    # 04/07 user ID and capabilities
    chown:baseline|chown:seccomp) echo ALLOWED ;;
    chown:*) echo DENIED ;;
    mount-tmpfs:*) echo DENIED ;;
    mknod:baseline|mknod:seccomp) echo ALLOWED ;;
    mknod:*) echo DENIED ;;
    dac-override:baseline|dac-override:seccomp) echo ALLOWED ;;
    dac-override:*) echo DENIED ;;
    # 05/07 seccomp and capabilities
    userns:seccomp|userns:hardened) echo DENIED ;;
    userns:*) echo ALLOWED ;;
    # 04 user ID
    rootfs-write:user-isolation|rootfs-write:hardened) echo DENIED ;;
    rootfs-write:*) echo ALLOWED ;;
    # app functionality
    www-write:*) echo ALLOWED ;;
    # 01 - host access
    runtime-socket:*) echo DENIED ;;
    # 06 - token
    sa-token-read:*) echo DENIED ;;
  esac
}

# probe <name> <description> <command run inside the pod>
# ALLOWED = exited 0; DENIED = ran and failed; ERROR - else.
probe() {
  local name="$1" desc="$2" cmd="$3" out rc observed expected
  expected="$(expected_for "$name")"
  out="$(exec_sh "$cmd" 2>&1)" && rc=0 || rc=$?

  if grep -qiE 'Error from server|unable to upgrade|container not found' <<<"$out"; then
    fail "$name: could not run probe: $out" || status=1; return
  elif [[ "$rc" -eq 127 ]]; then
    fail "$name: tool missing in image: $out" || status=1; return
  elif [[ "$rc" -eq 99 ]]; then
    fail "$name: prerequisite failed (is /www writable?): $out" || status=1; return
  elif [[ "$rc" -eq 0 ]]; then
    observed=ALLOWED
  else
    observed=DENIED
  fi

  echo "INFO [$PROFILE] $name ($desc): $observed ${out:+- ${out//$'\n'/ }}"
  if [[ "$observed" == "$expected" ]]; then
    pass "$name $observed as expected for this profile"
  elif [[ "$name" == "userns" && "$expected" == "ALLOWED" ]]; then
    review "userns denied although this profile does not filter it; check kernel.unprivileged_userns settings"
  else
    fail "$name expected $expected, observed $observed" || status=1
  fi
}

# 04 - privileged operations
probe raw-socket "needs CAP_NET_RAW" 'ping -c 1 -W 1 127.0.0.1'
probe chown "needs CAP_CHOWN" \
  'f=/www/.chown-probe; touch "$f" || exit 99; chown 12345:12345 "$f"; rc=$?; rm -f "$f"; exit $rc'
probe mount-tmpfs "needs CAP_SYS_ADMIN" \
  'd=/www/.mnt-probe; mkdir -p "$d" || exit 99; mount -t tmpfs tmpfs "$d"; rc=$?; [ $rc -eq 0 ] && umount "$d"; rmdir "$d" 2>/dev/null; exit $rc'
# CAP_MKNOD: create (then remove) a device node for /dev/null.
probe mknod "needs CAP_MKNOD" \
  'f=/www/.mknod-probe; rm -f "$f"; touch "$f.chk" || exit 99; rm -f "$f.chk"; mknod "$f" c 1 3; rc=$?; rm -f "$f"; exit $rc'
# CAP_DAC_OVERRIDE: read a file we own after removing every permission bit from it.
probe dac-override "needs CAP_DAC_OVERRIDE" \
  'f=/www/.dac-probe; touch "$f" || exit 99; chmod 000 "$f"; cat "$f" >/dev/null; rc=$?; rm -f "$f"; exit $rc'

# 05 - restricted syscalls
probe userns "user namespace creation" 'unshare -U true'

# 08 - application functionality
probe rootfs-write "write to the container root filesystem" 'touch /.rootfs-probe && rm -f /.rootfs-probe'
probe www-write "write to the /www emptyDir" 'touch /www/.w-probe && rm -f /www/.w-probe'

# 01 - host filesystem
probe runtime-socket "container runtime socket visible" \
  'for s in /var/run/docker.sock /run/docker.sock /run/containerd/containerd.sock /var/run/containerd/containerd.sock /run/crio/crio.sock /var/run/crio/crio.sock; do [ -e "$s" ] && { echo "found $s"; exit 0; }; done; exit 1'

# check if anything didn't come from Kubernetes/container runtime
read -r -d '' MOUNT_AWK <<'AWK' || true
{
  for (i = 7; i <= NF; i++) if ($i == "-") break
  fs = $(i + 1); root = $4; mp = $5
  if (mp == "/") next
  if (fs ~ /^(proc|sysfs|tmpfs|devtmpfs|devpts|mqueue|cgroup2?|shm)$/) next
  if (root ~ "^/var/lib/(kubelet/pods|containerd/io[.]containerd[.]grpc[.]v1[.]cri/sandboxes|docker/containers)/") next
  print mp " <- " root " (" fs ")"
}
AWK
host_mounts="$(exec_sh "awk '$MOUNT_AWK' /proc/self/mountinfo" 2>&1)" && mounts_rc=0 || mounts_rc=$?
if [[ "$mounts_rc" -ne 0 ]]; then
  fail "host-mounts: could not read /proc/self/mountinfo: $host_mounts" || status=1
elif [[ -z "$host_mounts" ]]; then
  pass "no host-backed mounts beyond runtime-managed ones"
else
  echo "INFO [$PROFILE] unexpected mounts: ${host_mounts//$'\n'/ ; }"
  review "host-backed mounts present; confirm each is intended (see INFO line)"
fi

# 02 - host processes
pids="$(exec_sh "ls /proc | grep -c '^[0-9][0-9]*\$'" 2>&1)" || pids=""
if [[ "$pids" =~ ^[0-9]+$ ]]; then
  echo "INFO [$PROFILE] visible PIDs: $pids (threshold $PROC_THRESHOLD)"
  if [[ "$pids" -le "$PROC_THRESHOLD" ]]; then
    pass "pod sees only its own processes ($pids PIDs)"
  else
    fail "pod sees $pids PIDs; the host PID namespace may be shared" || status=1
  fi
else
  fail "could not count visible PIDs: $pids" || status=1
fi

# 03 - host network
pod_ip="$(pod_value '{.status.podIP}')"
host_ip="$(pod_value '{.status.hostIP}')"
echo "INFO [$PROFILE] podIP=$pod_ip hostIP=$host_ip"
if [[ -z "$pod_ip" || -z "$host_ip" ]]; then
  fail "could not read podIP/hostIP" || status=1
elif [[ "$pod_ip" == "$host_ip" ]]; then
  fail "podIP equals hostIP; the pod is on the host network" || status=1
else
  pass "pod IP differs from the node IP"
fi

# 04 - privileged operations
devs="$(exec_sh 'ls /dev | wc -l' 2>&1)" || devs=""
devs="${devs//[[:space:]]/}"
if [[ "$devs" =~ ^[0-9]+$ ]]; then
  echo "INFO [$PROFILE] /dev entries: $devs (threshold $DEV_THRESHOLD)"
  if [[ "$devs" -le "$DEV_THRESHOLD" ]]; then
    pass "only the minimal container /dev is present ($devs entries)"
  else
    fail "$devs /dev entries; host devices may be exposed (privileged container?)" || status=1
  fi
else
  fail "could not count /dev entries: $devs" || status=1
fi

# 06 - service account token
probe sa-token-read "service-account token readable" \
  'cat /var/run/secrets/kubernetes.io/serviceaccount/token >/dev/null'

exit "$status"