#!/usr/bin/env bash

# Imports shared functions and variables
source "$(dirname "$0")/lib.sh" "$@"

# TEST 7: Effective identity, capabilities, NoNewPrivs, and Seccomp in the process

# Get security configuration and parse it for future checks
security_state="$(exec_sh 'printf "%s\n%s\n" "$(id -u)" "$(id -g)"; awk "/^(CapEff|CapPrm|CapBnd|NoNewPrivs|Seccomp):/ {print \$1, \$2}" /proc/self/status')" || fail "could not read effective process security state"
uid="$(sed -n '1p' <<<"$security_state")"
gid="$(sed -n '2p' <<<"$security_state")"
cap_eff="$(awk '$1 == "CapEff:" {print $2}' <<<"$security_state")"
cap_prm="$(awk '$1 == "CapPrm:" {print $2}' <<<"$security_state")"
cap_bnd="$(awk '$1 == "CapBnd:" {print $2}' <<<"$security_state")"
no_new_privs="$(awk '$1 == "NoNewPrivs:" {print $2}' <<<"$security_state")"
seccomp_mode="$(awk '$1 == "Seccomp:" {print $2}' <<<"$security_state")"

# Check for user/group ID
case "$PROFILE" in
  baseline|capabilities|seccomp) expected_uid=0; expected_gid=0 ;;
  user-isolation) expected_uid=1000; expected_gid=1000 ;;
  hardened) expected_uid=10001; expected_gid=10001 ;;
esac
if [[ "$uid" == "$expected_uid" && "$gid" == "$expected_gid" ]]; then
  pass "effective UID/GID are $uid/$gid"
else
  fail "expected UID/GID $expected_uid/$expected_gid, observed $uid/$gid"
fi

# Check for capabilities
if [[ -z "$cap_eff" ]]; then
  fail "CapEff was not reported by /proc/self/status"
else
  printf 'INFO [%s] Linux capability masks: CapEff=%s CapPrm=%s CapBnd=%s\n' "$PROFILE" "$cap_eff" "$cap_prm" "$cap_bnd"
  case "$PROFILE" in
    capabilities)
      # CAP_NET_BIND_SERVICE is capability bit 10; this profile grants only it.
      cap_value=$((16#$cap_eff))
      prm_value=$((16#$cap_prm))
      expected_cap=$((1 << 10))
      if [[ "$cap_value" -eq "$expected_cap" && "$prm_value" -eq "$expected_cap" ]]; then
        pass "effective and permitted sets contain only CAP_NET_BIND_SERVICE"
      else
        fail "expected only CAP_NET_BIND_SERVICE in CapEff/CapPrm; observed $cap_eff/$cap_prm (CapBnd=$cap_bnd)"
      fi
      ;;
    hardened)
      if [[ "$cap_eff" =~ ^0+$ && "$cap_prm" =~ ^0+$ ]]; then
        pass "effective and permitted capability sets are empty; bounding set recorded for runtime comparison"
      else
        fail "expected empty CapEff/CapPrm, observed $cap_eff/$cap_prm (CapBnd=$cap_bnd)"
      fi
      ;;
    *)
      review "this profile retains the runtime's default capabilities; observed CapEff=$cap_eff"
      ;;
  esac
fi

case "$PROFILE" in
  user-isolation|hardened) expected_nnp=1 ;;
  *) expected_nnp=0 ;;
esac
if [[ "$no_new_privs" == "$expected_nnp" ]]; then
  pass "NoNewPrivs=$no_new_privs matches the profile's privilege-escalation setting"
else
  fail "expected NoNewPrivs=$expected_nnp, observed $no_new_privs"
fi

case "$PROFILE" in
  seccomp|hardened) expected_seccomp=2 ;;
  *) expected_seccomp=0 ;;
esac
if [[ "$seccomp_mode" == "$expected_seccomp" ]]; then
  if [[ "$expected_seccomp" == "2" ]]; then
    pass "Seccomp mode is filter mode (2)"
  else
    review "Seccomp is intentionally unconfined for this comparison profile (mode 0)"
  fi
else
  fail "expected Seccomp mode $expected_seccomp, observed $seccomp_mode"
fi
