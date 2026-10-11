# Generated evaluation reports

Run the following command from the root of this repo to create a timestamped report artifact in this directory:

```bash
./tests/run-report.sh <PROFILE>
```

The command creates:

- `evaluation-<PROFILE>-<UTC timestamp>.log`: full stdout/stderr from every evaluation script ran.
- `evaluation-summary-<PROFILE>-<UTC timestamp>.txt`: each scripts summary results.
- `trivy-<PROFILE>-<UTC timestamp>.log`: full Trivy configuration scans and image scans output.
- `trivy-summary-<PROFILE>-<UTC timestamp>.txt`: Trivy configuration scans and image scans summary.
- `trivy-config-<PROFILE>-<UTC timestamp>.html`: HTML Kubernetes configuration scan.
- `trivy-image-<PROFILE>-<UTC timestamp>.html`: HTML image scan.
