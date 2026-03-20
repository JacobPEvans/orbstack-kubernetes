"""End-to-end warmup: send a trace and verify it reaches Splunk.

Proves the full pipeline (OTEL Collector -> Cribl Stream -> Splunk HEC)
is delivering events before tests start.  Exits 0 only when Splunk has
the sentinel trace, exits 1 after 180s timeout.
"""

import base64
import json
import os
import subprocess
import sys
import time
import uuid

# Allow importing helpers from tests/
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tests"))
from helpers import query_splunk

CONTEXT = os.environ.get("KUBE_CONTEXT", "orbstack")
NAMESPACE = os.environ.get("KUBE_NAMESPACE", "monitoring")
K8S_HOST = os.environ.get("K8S_NODEPORT_HOST", "localhost")
OTEL_GRPC_ENDPOINT = f"{K8S_HOST}:30317"

SEND_RETRIES = 5
SEND_BACKOFF = 2
POLL_INTERVAL = 5
POLL_TIMEOUT = 180


def kubectl_secret_values(name: str, keys: list[str]) -> dict[str, str]:
    """Read multiple k8s secret values in a single kubectl call."""
    cmd = [
        "kubectl",
        "--context",
        CONTEXT,
        "-n",
        NAMESPACE,
        "get",
        "secret",
        name,
        "-o",
        "json",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        raise RuntimeError(f"kubectl get secret {name} failed: {result.stderr}")
    data = json.loads(result.stdout).get("data", {})
    out = {}
    for key in keys:
        encoded = data.get(key)
        if not encoded:
            raise RuntimeError(f"Secret {name}[{key}] not found or empty")
        out[key] = base64.b64decode(encoded).decode()
    return out


def send_warmup_trace(sentinel: str) -> None:
    """Send a trace with the sentinel ID, retrying on transient gRPC failures."""
    from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import SimpleSpanProcessor

    for attempt in range(SEND_RETRIES):
        provider = None
        try:
            exporter = OTLPSpanExporter(endpoint=OTEL_GRPC_ENDPOINT, insecure=True)
            provider = TracerProvider()
            provider.add_span_processor(SimpleSpanProcessor(exporter))
            tracer = provider.get_tracer("e2e-warmup")
            with tracer.start_as_current_span("e2e-warmup", attributes={"test.id": sentinel}):
                pass
            provider.shutdown()
            print(f"Warmup trace sent (attempt {attempt + 1}): {sentinel}")
            return
        except Exception as exc:
            if provider is not None:
                try:
                    provider.shutdown()
                except Exception:
                    pass
            if attempt == SEND_RETRIES - 1:
                raise
            wait = SEND_BACKOFF**attempt
            print(f"Send attempt {attempt + 1} failed ({exc}), retrying in {wait}s...")
            time.sleep(wait)


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

    # Send warmup trace
    try:
        send_warmup_trace(sentinel)
    except Exception as exc:
        print(f"FATAL: Failed to send warmup trace after {SEND_RETRIES} attempts: {exc}")
        return 1

    # Poll Splunk for the sentinel
    deadline = time.time() + POLL_TIMEOUT
    attempts = 0
    while time.time() < deadline:
        attempts += 1
        results = query_splunk(mgmt_url, admin_password, f'index=claude "{sentinel}"', earliest="-5m")
        if results:
            elapsed = POLL_TIMEOUT - (deadline - time.time())
            print(f"Pipeline verified: trace found in Splunk after {elapsed:.0f}s ({attempts} polls)")
            return 0
        remaining = int(deadline - time.time())
        print(f"  Polling Splunk... ({remaining}s remaining)")
        time.sleep(POLL_INTERVAL)

    print(f"FATAL: Sentinel '{sentinel}' not found in Splunk after {POLL_TIMEOUT}s")
    dump_diagnostics()
    return 1


if __name__ == "__main__":
    sys.exit(main())
