# CAP5150_Project_Container_Escape
## Evaluating the Effectiveness of Kubernetes Security Controls in Mitigating Container Escape

This repository contains the implementation for the CAP 5150 Project involving container escape in cloud (Kubernetes) evironment.

## Project Overview

The following profiles were created to compare Kubernetes security configuration options and are located in their respective subdirectories under `environment/`. Each profile contains a Trivy image and configuration scan to illustrate vulnerabilites, that can be reran by running `./tests/trivy-scan.sh <PROFILE>`.

| Profile | Namespace | Main controls | Trivy Configuration Findings |
| --- | --- | --- | --- |
| `baseline` | `escape-baseline` | Root user, privilege escalation allowed, `NET_RAW`, unconfined Seccomp | 14 |
| `user-isolation` | `escape-user-isolation` | UID/GID 1000, non-root, privilege escalation disabled | 9 |
| `capabilities` | `escape-capabilities` | All capabilities dropped; only `NET_BIND_SERVICE` added so the workload can bind to port 80 | 10 |
| `seccomp` | `escape-seccomp` | RuntimeDefault Seccomp profile | 12 |
| `hardened` | `escape-hardened` | Non-root, no escalation, all capabilities dropped, RuntimeDefault Seccomp, read-only root filesystem | 0 |

The Alpine workload serves a fixed HTTP response. Most profiles listen on port 8080; the capabilities profile listens on port 80 and uses `NET_BIND_SERVICE` to bind that privileged port. Content is written to a scoped `emptyDir` mounted at `/www`, so the hardened profile keeps its root filesystem read-only while the application remains functional.

## Environment Setup

Run the following command to install all dependencies utilized for this project (Note: assummes `Ubuntu` distro and must be ran as `root` or `sudo` user):
```bash
./init/init.sh
```

Run the following command to build the Kubernetes cluster `container-escape-study`:
```bash
./kind/create.sh
```

Run one of the following commands to deploy/remove a specific security profile:
```bash
./environment/scripts/build.sh <PROFILE>
./environment/scripts/destroy.sh <PROFILE>
```

Run one of the commands to build/destory all profiles:
```bash
./environment/scripts/build-all.sh
./environment/scripts/destroy-all.sh
```

Run the following command to destroy the cluster when finished:
```bash
./kind/destroy.sh
```

## Environment Testing

Run the following command to generate a timestamped full log and summary for one profile. Static audits and Trivy run once; readiness and runtime checks run three times against the same deployed pod by default. Reports are written to `reports/`.
```bash
./tests/run-report.sh <PROFILE>
```

Render a profile without applying it:

```bash
kubectl kustomize environment/overlays/hardened
```

| Script group | Classification | Purpose |
| --- | --- | --- |
| `run-all.sh` | Test support/evaluation | Runs all nine labeled runtime checks for one profile |
| `run-report.sh` | Evaluation/reporting | Runs every evaluation script for one profile and writes timestamped full and summary reports |
| `trivy-scan.sh` | Evaluation | Scans the rendered Kubernetes configuration and workload image for misconfigurations and vulnerabilities |

### Tests that evaluate the configurations

Run the following command to report the status of the tested privileges (Note: this is an audit and does not run any attacks):
```bash
./tests/config-audit.sh
```

| Script group | Classification | Purpose |
| --- | --- | --- |
| `config-audit.sh` | Evaluation | YAML configuration audit |

### Tests that run inside the pod

These scripts 1-8 do not execute container-escape exploits, while script 9 runs benign probes. They check Kubernetes configuration and selected runtime properties inside each pod. The project also scans the shared Alpine image for known vulnerabilities; that scan reports image risk but does not establish that an image vulnerability can escape the container.

Run the following command to run the runtime validation suite against a profile:
```bash
./tests/run-all.sh <PROFILE>
```

The first six numbered scripts check the explicit categories. The seventh checks effective process security settings, the eighth checks application compatibility, and the ninth checks what can actually be performed:

| Script | What it checks | What a pass means |
|---|---|---|
| `01-host-filesystem.sh` | Host filesystem | No `hostPath` volume is configured. Scoped application mounts, such as Grafana dashboard files from a ConfigMap, remain valid. |
| `02-host-processes.sh` | Host processes | `hostPID` is off and the pod can read its own process status. |
| `03-host-network.sh` | Host network | `hostNetwork` is off and pod network files are available. |
| `04-privileged-operations.sh` | Privilege and identity | The container is not privileged; user-isolation and hardened profiles also run with their expected UID/GID. |
| `05-restricted-syscalls.sh` | Seccomp | The configured Seccomp profile matches the mode reported by the running process. |
| `06-runtime-information.sh` | Runtime information | Service-account token automount is off and the token file is absent. |
| `07-effective-security.sh` | Effective privilege controls | Reads UID/GID, Linux capability sets, `NoNewPrivs`, and Seccomp mode from the running process. |
| `08-workload-functionality.sh` | Application compatibility | Confirms the HTTP response and expected scoped writable mount. |
| '09-behavioral-probes.sh` | Behavioral checks | Check actual actions match what is expected by the configuration |
| `lib.sh` | Test support | Shared Kubernetes lookup and pod-exec helpers |


## Full Repo Structure
```
.
├── README.md
├── trivy-util-scan.sh
├── environment
│   ├── README.md
│   ├── base
│   │   ├── deployment.yaml
│   │   ├── kustomization.yaml
│   │   ├── network-policy.yaml
│   │   └── service.yaml
│   ├── overlays
│   │   ├── baseline
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   ├── security-context.yaml
│   │   │   ├── trivy-config.html
│   │   │   ├── trivy-config.log
│   │   │   ├── trivy-image.html
│   │   │   └── trivy-image.log
│   │   ├── capabilities
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   ├── security-context.yaml
│   │   │   ├── trivy-config.html
│   │   │   ├── trivy-config.log
│   │   │   ├── trivy-image.html
│   │   │   ├── trivy-image.log
│   │   │   └── workload-port.yaml
│   │   ├── hardened
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   ├── security-context.yaml
│   │   │   ├── trivy-config.html
│   │   │   ├── trivy-config.log
│   │   │   ├── trivy-image.html
│   │   │   └── trivy-image.log
│   │   ├── seccomp
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   ├── security-context.yaml
│   │   │   ├── trivy-config.html
│   │   │   ├── trivy-config.log
│   │   │   ├── trivy-image.html
│   │   │   └── trivy-image.log
│   │   └── user-isolation
│   │       ├── kustomization.yaml
│   │       ├── namespace.yaml
│   │       ├── security-context.yaml
│   │       ├── trivy-config.html
│   │       ├── trivy-config.log
│   │       ├── trivy-image.html
│   │       └── trivy-image.log
│   └── scripts
│       ├── README.md
│       ├── build-all.sh
│       ├── build.sh
│       ├── destroy-all.sh
│       └── destroy.sh
├── init
│   ├── init.sh
│   └── scripts
│       ├── TEMPLATE.sh
│       ├── dependencies.sh
│       ├── docker.sh
│       ├── k9s.sh
│       ├── kind.sh
│       ├── kubectl.sh
│       ├── python.sh
│       ├── ssh.sh
│       ├── trivy.sh
│       └── yq.sh
├── kind
│   ├── README.md
│   ├── cluster.yaml
│   ├── create.sh
│   └── destroy.sh
├── reports
│   └── README.md
└── tests
    ├── 01-host-filesystem.sh
    ├── 02-host-processes.sh
    ├── 03-host-network.sh
    ├── 04-privileged-operations.sh
    ├── 05-restricted-syscalls.sh
    ├── 06-runtime-information.sh
    ├── 07-effective-security.sh
    ├── 08-workload-functionality.sh
    ├── 09-behavioral-probe.sh
    ├── README.md
    ├── config-audit.sh
    ├── configuration-audit.sh
    ├── lib.sh
    ├── run-all.sh
    ├── run-report.sh
    └── trivy-scan.sh
```