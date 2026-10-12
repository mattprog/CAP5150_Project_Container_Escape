#!/usr/bin/env bash

# Imports shared functions and variables
source "$(dirname "$0")/lib.sh" "$@"

# TEST 8: Application compatibility and basic functionality, check for any issues

# Check the configured port
port="$(deployment_value '{.spec.template.spec.containers[0].env[?(@.name=="HTTP_PORT")].value}')"
expected_port=8080
if [[ "$PROFILE" == "capabilities" ]]; then
  expected_port=80
fi
if [[ "$port" != "$expected_port" ]]; then
  fail "expected workload HTTP_PORT=$expected_port for profile $PROFILE, observed $port"
fi

# HTTP check
response="$(exec_sh "wget -q -O - http://127.0.0.1:$port/")" || fail "HTTP workload did not respond on port $port"
if [[ "$response" == "container-escape-study-ok" ]]; then
  pass "HTTP workload returned the expected response"
else
  fail "unexpected workload response: $response"
fi

# Check for service issue
service_target="$(service_value '{.spec.ports[?(@.name=="http")].targetPort}')"
if [[ "$service_target" == "$expected_port" ]]; then
  pass "Service targets the workload's configured HTTP port $service_target"
else
  fail "Service targetPort=$service_target does not match workload HTTP_PORT=$expected_port"
fi

# Check volume mounts
mount_path="$(deployment_value '{.spec.template.spec.containers[0].volumeMounts[?(@.name=="web-content")].mountPath}')"
mount_read_only="$(deployment_value '{.spec.template.spec.containers[0].volumeMounts[?(@.name=="web-content")].readOnly}')"
mount_read_only="${mount_read_only:-false}"
volume_name="$(deployment_value '{.spec.template.spec.volumes[?(@.name=="web-content")].name}')"
host_path="$(deployment_value '{.spec.template.spec.volumes[?(@.name=="web-content")].hostPath.path}')"
if [[ "$mount_path" == "/www" && "$mount_read_only" == "false" && "$volume_name" == "web-content" && -z "$host_path" ]]; then
  pass "web content uses a writable emptyDir mount at /www, not the container root filesystem"
else
  fail "unexpected web-content mount: path=$mount_path readOnly=$mount_read_only volume=$volume_name hostPath=$host_path"
fi
