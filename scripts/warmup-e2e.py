"""End-to-end warmup: send a trace and verify it reaches Splunk.

Proves the full pipeline (OTEL Collector -> Cribl Stream -> Splunk HEC)
is delivering events before tests start.  Exits 0 only when Splunk has
the sentinel trace, exits 1 after 180s timeout.
"""

import os
import subprocess
import sys
import time
import uuid

# Allow importing from tests/
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tests"))
from conftest import CONTEXT, NAMESPACE, OTEL_GRPC_ENDPOINT, kubectl_secret_values
from helpers import query_splunk, send_trace_with_retry

SEND_RETRIES = 5
POLL_INTERVAL = 5
POLL_TIMEOUT = 180


def dump_diagnostics() -> None:
    """Print pod logs to help diagnose pipeline failures."""
    print("\n--- Diagnostic pod logs ---")
    for sts in ["otel-collector", "cribl-stream-standalone"]:
        print(f"\n[{sts}] (last 30 lines):")
        try:
            result = subprocess.run(
                ["kubectl", "--context", CONTEXT, "-n", NAMESPACE, "logs", f"statefulset/{sts}", "--tail=30"],
                capture_output=True,
                text=True,
                timeout=30,
            )
            print(result.stdout or "(no output)")
        except Exception as exc:
            print(f"(failed to fetch logs: {exc})")


def main() -> int:
    sentinel = f"e2e-warmup-{uuid.uuid4().hex[:12]}"
    print("E2E warmup: verifying full pipeline delivers to Splunk...")
    print(f"Sentinel: {sentinel}")

    # Read Splunk credentials from K8s secret
    try:
        secrets = kubectl_secret_values("splunk-hec-config", ["mgmt-url", "admin-password"])
    except RuntimeError as exc:
        print(f"FATAL: Cannot read Splunk credentials: {exc}")
        return 1

    mgmt_url = secrets["mgmt-url"]
    admin_password = secrets["admin-password"]

    # Send warmup trace with retry
    try:
        send_trace_with_retry(
            OTEL_GRPC_ENDPOINT,
            sentinel,
            tracer_name="e2e-warmup",
            span_name="e2e-warmup",
            retries=SEND_RETRIES,
        )
        print(f"Warmup trace sent: {sentinel}")
    except Exception as exc:
        print(f"FATAL: Failed to send warmup trace after {SEND_RETRIES} attempts: {exc}")
        return 1

    # Poll Splunk for the sentinel — check immediately, then every POLL_INTERVAL
    deadline = time.time() + POLL_TIMEOUT
    attempts = 0
    while True:
        attempts += 1
        results = query_splunk(mgmt_url, admin_password, f'index=claude "{sentinel}"', earliest="-5m")
        if results:
            elapsed = POLL_TIMEOUT - (deadline - time.time())
            print(f"Pipeline verified: trace found in Splunk after {elapsed:.0f}s ({attempts} polls)")
            return 0
        if time.time() >= deadline:
            break
        remaining = int(deadline - time.time())
        print(f"  Polling Splunk... ({remaining}s remaining)")
        time.sleep(POLL_INTERVAL)

    print(f"FATAL: Sentinel '{sentinel}' not found in Splunk after {POLL_TIMEOUT}s")
    dump_diagnostics()
    return 1


if __name__ == "__main__":
    sys.exit(main())
