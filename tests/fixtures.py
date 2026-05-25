"""Sample fixture constants for tests, docs, and example commands.

All sample IPs, hostnames, and URLs used in committed code MUST come from
this module. Never paste values observed in `kubectl exec`, `cribl` config
dumps, or other running-system tool output into source files — those values
reflect live network state and leak into the public repository.

The only sanctioned example IP range for this repository is 192.168.0.0/24.
This is enforced by `scripts/check-no-real-ips.py` via the no-real-ips
pre-commit hook.
"""

SAMPLE_SPLUNK_HOST = "192.168.0.200"
SAMPLE_HEC_URL = f"https://{SAMPLE_SPLUNK_HOST}:8088/services/collector"
SAMPLE_SPLUNK_MGMT_URL = f"https://{SAMPLE_SPLUNK_HOST}:8089"
