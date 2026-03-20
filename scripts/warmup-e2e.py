"""End-to-end warmup: send a trace and verify it reaches Splunk.

Proves the full pipeline (OTEL Collector -> Cribl Stream -> Splunk HEC)
is delivering events before tests start.  Exits 0 only when Splunk has
the sentinel trace, exits 1 after 180s timeout.
"""

import os
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

# Allow importing from tests/
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tests"))
from conftest import CONTEXT, NAMESPACE, OTEL_GRPC_ENDPOINT, kubectl_secret_values
from helpers import query_splunk, send_trace_with_retry

SEND_RETRIES = 5
POLL_INTERVAL = 5
POLL_TIMEOUT = 180


def verify_splunk_connectivity(mgmt_url: str, admin_password: str) -> bool:
    """Verify the runner can reach the Splunk management API.

    Returns True if reachable, False otherwise. Prints diagnostic details.
    """
    import base64

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    credentials = f"admin:{admin_password}"
    encoded = base64.b64encode(credentials.encode()).decode()
    req = urllib.request.Request(
        f"{mgmt_url}/services/server/info",
        headers={"Authorization": f"Basic {encoded}"},
    )
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
            print(f"  Splunk reachable at {mgmt_url} (HTTP {resp.status})")
            return True
    except urllib.error.HTTPError as exc:
        # HTTP error means we can reach Splunk (auth/path issues are OK)
        print(f"  Splunk reachable at {mgmt_url} (HTTP {exc.code} — auth/path issue, but network OK)")
        return True
    except (urllib.error.URLError, OSError) as exc:
        print(f"  WARNING: Cannot reach Splunk at {mgmt_url}: {exc}")
        return False


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

    # Verify Splunk is reachable before spending time on warmup
    print("Checking Splunk connectivity...")
    if not verify_splunk_connectivity(mgmt_url, admin_password):
        print("FATAL: Splunk management API unreachable — cannot verify pipeline delivery")
        return 1

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
    conn_failures = 0
    while True:
        attempts += 1
        results = query_splunk(mgmt_url, admin_password, f'index=claude "{sentinel}"', earliest="-5m")
        if results:
            elapsed = POLL_TIMEOUT - (deadline - time.time())
            print(f"Pipeline verified: trace found in Splunk after {elapsed:.0f}s ({attempts} polls)")
            return 0
        if results is not None and len(results) == 0:
            # query_splunk returns [] on both "no results" AND "connection error"
            # Do a connectivity check every 5 failed polls to detect the difference
            conn_failures += 1
            if conn_failures % 5 == 0:
                if not verify_splunk_connectivity(mgmt_url, admin_password):
                    print("WARNING: Splunk became unreachable during polling")
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
