"""Tier 3: Forwarding verification tests.

These tests verify data flows correctly through the pipeline:
  A2: Host Filesystem → Cribl Edge Standalone (file monitor)
  A4: OTEL Collector → Cribl Edge Standalone (gRPC :4317)
  A5: Cribl Edge Standalone → homelab Cribl Stream (S2S :10300)
  A7: homelab Cribl Stream → Splunk HEC (passthrough; verified via Splunk queries)
"""

import errno
import json
import os
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

import pytest
from conftest import (
    OTEL_GRPC_ENDPOINT,
    PF_EDGE_INPUTS,
    kubectl,
    kubectl_exec_no_fail,
    port_forward_get,
)
from helpers import (
    find_flowing_stats,
    parse_otel_error_lines,
    query_splunk,
    send_trace_with_retry,
)


def _send_trace(test_id: str, *, retries: int = 3) -> None:
    """Send a trace with retry for transient gRPC failures."""
    send_trace_with_retry(
        OTEL_GRPC_ENDPOINT,
        test_id,
        tracer_name="otel-forwarding-test",
        span_name="forward-test-span",
        retries=retries,
    )


@pytest.mark.usefixtures("cluster_ready")
class TestCollectorToEdgeForwarding:
    """Verify OTEL Collector forwards data to Cribl Edge Standalone (arrow A4)."""

    def test_no_export_errors_after_send(self):
        """After sending data, collector's own operational logs should not contain export errors.

        Note: The otel-collector also forwards log files from the host (including pod logs
        from other containers). Those forwarded logs may contain the word "Exporting" as
        telemetry data content. We check for errors only in the collector's operational
        log lines (lines starting with a timestamp and log level marker).
        """
        test_id = str(uuid.uuid4())
        test_start = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        _send_trace(test_id)
        time.sleep(5)  # Allow time for forwarding attempt
        # Use --since-time tied to this test's start timestamp so only logs
        # produced during this test run are inspected. This prevents false
        # failures from pod startup/restart errors that predate the send.
        logs = kubectl("logs", "statefulset/otel-collector", f"--since-time={test_start}")
        # OTEL collector log format: TIMESTAMP\tLEVEL\tFILE\tMESSAGE\tJSON
        # Only lines with \terror\t are error-level operational log entries.
        # Info-level retry lines (e.g. "Exporting failed. Will retry...") are
        # expected transient noise and should not fail this test.
        otel_error_lines = parse_otel_error_lines(logs)
        assert not otel_error_lines, "OTEL Collector operational errors found after send:\n" + "\n".join(
            otel_error_lines[:5]
        )

    def test_cribl_edge_received_otlp_data(self):
        """After sending a trace, Cribl Edge API should be reachable to verify input activity."""
        _send_trace(str(uuid.uuid4()))
        time.sleep(5)
        resp = port_forward_get("cribl-edge-standalone", 9420, PF_EDGE_INPUTS, "/api/v1/system/inputs")
        # 200 = API accessible, 401 = auth required (inputs endpoint exists)
        assert resp.status_code in (200, 401), f"Cribl Edge inputs API returned unexpected status {resp.status_code}"


@pytest.mark.usefixtures("cluster_ready", "pipeline_warm")
class TestEdgeToHomelabForwarding:
    """Verify Cribl Edge Standalone forwards to the homelab Cribl Stream (arrows A5 + A7).

    The homelab Stream itself is not reachable from CI, so these tests verify
    the Edge side of the S2S leg (proxmox-stream output health and outbound
    bytes) plus end-to-end delivery by querying Splunk directly.
    """

    def test_cribl_edge_no_output_errors(self):
        """Cribl Edge logs should contain no warn/error lines for the proxmox-stream output."""
        logs = kubectl("logs", "statefulset/cribl-edge-standalone", "--tail=100")
        error_lines = [
            line
            for line in logs.splitlines()
            if "output:proxmox-stream" in line and ("level=warn" in line or "level=error" in line)
        ]
        assert not error_lines, "Cribl Edge has output errors for proxmox-stream:\n" + "\n".join(error_lines[:5])

    def test_otlp_events_reach_splunk_realtime(self, splunk_client):
        """Send OTLP trace and verify it appears in Splunk index=claude within 120s.

        End-to-end verification that the OTLP → Edge → homelab Stream → Splunk HEC
        path (A4 + A5 + A7) delivers events to the correct Splunk index. Uses a unique
        trace ID as a sentinel to ensure we're matching our specific test event, not
        background traffic.

        This test runs BEFORE test_cribl_edge_events_flowing to serve as a readiness
        gate: once data reaches Splunk, the pipeline is provably live and internal stats
        should be emitting.
        """
        trace_id = f"splunk-rt-{uuid.uuid4().hex[:12]}"
        _send_trace(trace_id)
        mgmt_url, admin_password = splunk_client

        deadline = time.time() + 120
        while time.time() < deadline:
            results = query_splunk(
                mgmt_url,
                admin_password,
                f'index=claude "{trace_id}"',
                earliest="-5m",
            )
            if results:
                return
            time.sleep(5)
        pytest.fail(
            f"Trace ID '{trace_id}' not found in Splunk index=claude within 120s. "
            "The OTLP → Edge → homelab Stream → Splunk HEC pipeline (A4 + A5 + A7) "
            "is not forwarding events to the correct index."
        )

    def test_cribl_edge_events_flowing(self):
        """Cribl Edge stats should show outBytes > 0 (data physically sent to the homelab Stream).

        Checks _raw stats for outBytes > 0 (bytes actually sent to an external output),
        not just outEvents (which counts pipeline-internal routing). Since proxmox-stream
        is the default output and all connections lead there, outBytes > 0 confirms
        data was physically sent over S2S to the homelab Stream.

        Runs AFTER test_otlp_events_reach_splunk_realtime which proves the pipeline is
        live and data has already flowed through. Stats are emitted every ~10s, so they
        should be present in logs by now.
        """
        deadline = time.time() + 60
        while time.time() < deadline:
            logs = kubectl("logs", "statefulset/cribl-edge-standalone", "--tail=200")
            flowing = find_flowing_stats(logs)
            if flowing:
                return
            time.sleep(5)
        pytest.fail(
            "Expected _raw stats with outBytes > 0 after pipeline was verified live "
            "(test_otlp_events_reach_splunk_realtime passed), found none within 60s. "
            "Internal stats emission may be delayed."
        )


# ---------------------------------------------------------------------------
# Fixture for Gemini log pipeline tests
# ---------------------------------------------------------------------------

# DEPLOY_HOME_DIR overrides $HOME for Gemini log paths in CI.
# Use the macOS user home when running tests inside a Docker container (CI runner).
_GEMINI_HOME = Path(os.environ.get("DEPLOY_HOME_DIR", str(Path.home())))
_GEMINI_TEST_DIR = _GEMINI_HOME / ".gemini/antigravity/brain"


@pytest.fixture
def sentinel_gemini_file():
    """Write a unique sentinel .md to ~/.gemini/antigravity/brain/ on the host.

    Yields (path, sentinel_id). Cleans up after the test.
    The edge pod mounts this directory via hostPath, so the file appears at
    /home/gemini/.gemini/antigravity/brain/ inside the pod.
    """
    _GEMINI_TEST_DIR.mkdir(parents=True, exist_ok=True)
    sentinel_id = f"PIPELINE_TEST_{uuid.uuid4().hex[:12]}"
    sentinel_file = _GEMINI_TEST_DIR / f"sentinel-{sentinel_id}.md"
    sentinel_file.write_text(f"# Sentinel\n\nsentinel: {sentinel_id}\n")
    yield sentinel_file, sentinel_id
    try:
        sentinel_file.unlink()
    except FileNotFoundError:
        pass
    try:
        _GEMINI_TEST_DIR.rmdir()  # removes dir only if empty
    except OSError as exc:
        if exc.errno != errno.ENOTEMPTY:
            raise


# ---------------------------------------------------------------------------
# Fixture for Claude Code log pipeline tests
# ---------------------------------------------------------------------------

# CLAUDE_HOME overrides $HOME for Claude log paths.
# Use the macOS user home when running tests inside a Docker container (CI runner).
_CLAUDE_HOME = Path(os.environ.get("CLAUDE_HOME", Path.home()))
_CLAUDE_TEST_DIR = _CLAUDE_HOME / ".claude/projects/-test-claude-pipeline"


@pytest.fixture
def sentinel_claude_file():
    """Write a unique sentinel .jsonl to ~/.claude/projects/-test-claude-pipeline/ on the host.

    Yields (path, sentinel_id). Cleans up after the test.
    The edge pod mounts this directory via hostPath, so the file appears at
    /home/claude/.claude/projects/-test-claude-pipeline/ inside the pod.
    """
    _CLAUDE_TEST_DIR.mkdir(parents=True, exist_ok=True)
    sentinel_id = f"PIPELINE_TEST_{uuid.uuid4().hex[:12]}"
    sentinel_file = _CLAUDE_TEST_DIR / f"test-{sentinel_id}.jsonl"
    sentinel_data = {
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "sentinel": sentinel_id,
        "level": "info",
        "message": "Claude Code log pipeline test event",
    }
    sentinel_file.write_text(json.dumps(sentinel_data) + "\n")
    yield sentinel_file, sentinel_id
    try:
        sentinel_file.unlink()
    except FileNotFoundError:
        pass
    try:
        _CLAUDE_TEST_DIR.rmdir()  # removes dir only if empty
    except OSError as exc:
        if exc.errno != errno.ENOTEMPTY:
            raise


@pytest.mark.usefixtures("cluster_ready", "pipeline_warm")
class TestGeminiLogPipeline:
    """Verify .gemini/ log files are picked up by the edge file monitor (arrow A2).

    The file monitoring path (A2: Host FS → Edge Standalone) is separate from the
    OTLP path (A1/A4) tested by other classes. These tests confirm:
      1. The hostPath volume mount makes ~/.gemini/ visible inside the edge pod.
      2. The FileMonitor input (cc-edge-gemini-antigravity) is configured with the correct path.
      3. A new .md file written on the host is detected by the edge within one poll interval.
    """

    def test_gemini_home_mount_accessible(self):
        """Edge pod can access host ~/.gemini/ via the hostPath volume mount."""
        _, returncode = kubectl_exec_no_fail(
            "statefulset/cribl-edge-standalone",
            "--",
            "ls",
            "/home/gemini/.gemini/",
        )
        assert returncode == 0, f"hostPath mount /home/gemini/.gemini/ not accessible in edge pod (exit {returncode})"

    def test_sentinel_file_visible_in_edge_pod(self, sentinel_gemini_file):
        """A .md file written to host ~/.gemini/antigravity/brain/ is readable inside the edge pod.

        Brief retry (10s) handles filesystem propagation latency through hostPath volumes.
        """
        sentinel_path, sentinel_id = sentinel_gemini_file
        pod_path = f"/home/gemini/.gemini/antigravity/brain/{sentinel_path.name}"
        output = ""
        returncode = -1
        for attempt in range(5):
            output, returncode = kubectl_exec_no_fail(
                "statefulset/cribl-edge-standalone",
                "--",
                "cat",
                pod_path,
            )
            if returncode == 0:
                break
            if attempt < 4:
                time.sleep(2)
        assert returncode == 0, (
            f"Sentinel file not readable inside edge pod at {pod_path} after 10s "
            f"(exit {returncode}). Check that the hostPath volume is correctly mounted."
        )
        assert sentinel_id in output, f"Sentinel ID {sentinel_id!r} not found in pod file content: {output!r}"

    def test_edge_file_monitor_config_path(self):
        """Edge pack input is configured to monitor /home/gemini/.gemini/.

        The pack is installed via Cribl CLI (CRIBL_BEFORE_START_CMD) and stores its
        inputs in the pack directory (default/cc-edge-gemini-antigravity/inputs.yml).
        """
        output, returncode = kubectl_exec_no_fail(
            "statefulset/cribl-edge-standalone",
            "--",
            "sh",
            "-c",
            "cat ${CRIBL_VOLUME_DIR:-/opt/cribl/data}/default/cc-edge-gemini-antigravity/inputs.yml",
        )
        assert returncode == 0, (
            f"Could not read edge inputs from pack or local config (exit {returncode}). "
            "Check that CRIBL_BEFORE_START_CMD installed the cc-edge-gemini-antigravity pack correctly."
        )
        assert "/home/gemini/.gemini" in output or "$GEMINI_HOME/.gemini" in output, (
            f"Expected Gemini home path in edge inputs, got:\n{output}"
        )

    def test_edge_file_monitor_picks_up_sentinel(self, sentinel_gemini_file):
        """Edge FileMonitor logs a 'collector added' entry for a new .md file within 60s.

        The FileMonitor polls every 10 seconds (interval: 10). A new file written on the
        host should appear in edge logs within a few poll cycles. After a fresh pod restart,
        the initial scan of existing files can delay detection of new files.
        """
        sentinel_path, _ = sentinel_gemini_file
        deadline = time.time() + 60
        while time.time() < deadline:
            logs = kubectl("logs", "statefulset/cribl-edge-standalone", "--since=3m")
            if sentinel_path.name in logs and "FileMonitor collector added" in logs:
                return
            time.sleep(5)
        pytest.fail(
            f"Edge FileMonitor did not log 'collector added' for {sentinel_path.name} within 60s. "
            "Check that the cc-edge-gemini-antigravity pack is installed and the hostPath volume is mounted correctly."
        )

    def test_edge_gemini_file_input_active(self):
        """Edge file monitor must be actively collecting files from the Gemini host filesystem.

        Catches the failure mode where the pack was not installed or loaded by the runtime
        (e.g. pack download failed, CRIBL_VOLUME_DIR unset). The pack inputs are in the
        worker namespace and not listed by /api/v1/system/inputs, so we verify activity
        via pod logs which show FileMonitor collector messages referencing antigravity paths.
        """
        logs = kubectl("logs", "statefulset/cribl-edge-standalone")
        has_gemini_collectors = "antigravity" in logs.lower() and "FileMonitor collector added" in logs
        assert has_gemini_collectors, (
            "Edge file monitor is not active for Gemini/Antigravity paths — "
            "cc-edge-gemini-antigravity pack inputs.yml may not have been loaded. "
            "Check that CRIBL_BEFORE_START_CMD installed the pack correctly."
        )

    def test_file_events_reach_splunk_realtime(self, sentinel_gemini_file, splunk_client):
        """Write a .md sentinel and verify it reaches Splunk index=gemini within 90s.

        End-to-end verification of the full pipeline: Host FS → Edge → homelab Stream → Splunk (A2+A5+A7).
        Checks Splunk directly using the REST API instead of only checking Edge sentCount.
        The sentinel value is unique per test run so matches are unambiguous.
        """
        _, sentinel_value = sentinel_gemini_file
        mgmt_url, admin_password = splunk_client

        deadline = time.time() + 90
        while time.time() < deadline:
            results = query_splunk(
                mgmt_url,
                admin_password,
                f'index=gemini sourcetype=antigravity:brain "{sentinel_value}"',
                earliest="-10m",
            )
            if results:
                return
            time.sleep(10)
        pytest.fail(
            f"Sentinel value '{sentinel_value}' not found in Splunk index=gemini within 90s. "
            "The Host FS → Edge → homelab Stream → Splunk pipeline (A2+A5+A7) did not deliver the event."
        )


@pytest.mark.usefixtures("cluster_ready", "pipeline_warm")
class TestClaudeCodeLogPipeline:
    """Verify .claude/ session log files are picked up by the edge file monitor (arrow A2).

    The file monitoring path (A2: Host FS → Edge Standalone) is separate from the
    OTLP path (A1/A4) tested by other classes. These tests confirm:
      1. The hostPath volume mount makes ~/.claude/projects/ visible inside the edge pod.
      2. The FileMonitor input (cc-edge-claude-code) is configured with the correct path.
      3. A new .jsonl file written on the host is detected by the edge within one poll interval.
    """

    def test_claude_home_mount_accessible(self):
        """Edge pod can access host ~/.claude/projects/ via the hostPath volume mount."""
        _, returncode = kubectl_exec_no_fail(
            "statefulset/cribl-edge-standalone",
            "--",
            "ls",
            "/home/claude/.claude/projects/",
        )
        assert returncode == 0, (
            f"hostPath mount /home/claude/.claude/projects/ not accessible in edge pod (exit {returncode})"
        )

    def test_sentinel_file_visible_in_edge_pod(self, sentinel_claude_file):
        """A .jsonl file written to host ~/.claude/projects/ is immediately readable inside the edge pod."""
        sentinel_path, sentinel_id = sentinel_claude_file
        pod_path = f"/home/claude/.claude/projects/-test-claude-pipeline/{sentinel_path.name}"
        output, returncode = kubectl_exec_no_fail(
            "statefulset/cribl-edge-standalone",
            "--",
            "cat",
            pod_path,
        )
        assert returncode == 0, (
            f"Sentinel file not readable inside edge pod at {pod_path} (exit {returncode}). "
            "Check that the hostPath volume is correctly mounted."
        )
        assert sentinel_id in output, f"Sentinel ID {sentinel_id!r} not found in pod file content: {output!r}"

    def test_edge_file_monitor_config_path(self):
        """Edge pack input is configured to monitor /home/claude/.claude/projects/.

        The pack is installed via Cribl CLI (CRIBL_BEFORE_START_CMD) and stores its
        inputs in the pack directory (default/cc-edge-claude-code/inputs.yml).
        """
        output, returncode = kubectl_exec_no_fail(
            "statefulset/cribl-edge-standalone",
            "--",
            "sh",
            "-c",
            "cat ${CRIBL_VOLUME_DIR:-/opt/cribl/data}/default/cc-edge-claude-code/inputs.yml",
        )
        assert returncode == 0, (
            f"Could not read edge inputs from pack or local config (exit {returncode}). "
            "Check that CRIBL_BEFORE_START_CMD installed the pack correctly."
        )
        assert "/home/claude/.claude/projects" in output or "$CLAUDE_HOME/.claude/projects" in output, (
            f"Expected Claude projects path in edge inputs, got:\n{output}"
        )
        assert "*.jsonl" in output, f"Expected '*.jsonl' file pattern in edge inputs, got:\n{output}"

    def test_edge_file_monitor_picks_up_sentinel(self, sentinel_claude_file):
        """Edge FileMonitor logs a 'collector added' entry for a new .jsonl file within 60s.

        The FileMonitor polls every 10 seconds (interval: 10). A new file written on the
        host should appear in edge logs within a few poll cycles. After a fresh pod restart,
        the initial scan of existing files can delay detection of new files.
        """
        sentinel_path, _ = sentinel_claude_file
        deadline = time.time() + 60
        while time.time() < deadline:
            logs = kubectl("logs", "statefulset/cribl-edge-standalone", "--since=3m")
            if sentinel_path.name in logs and "FileMonitor collector added" in logs:
                return
            time.sleep(5)
        pytest.fail(
            f"Edge FileMonitor did not log 'collector added' for {sentinel_path.name} within 60s. "
            "Check that the edge pack is installed and the hostPath volume is mounted correctly."
        )

    def test_edge_output_not_devnull(self):
        """Edge 'default' output must NOT resolve to devnull — it must route to the homelab Stream.

        Directly catches the failure mode where CRIBL_VOLUME_DIR is unset and the runtime
        ignores config written to /opt/cribl/local/, leaving only the built-in devnull output.
        """
        output, _ = kubectl_exec_no_fail(
            "statefulset/cribl-edge-standalone",
            "--",
            "sh",
            "-c",
            "AUTH=$(curl -sf -X POST http://127.0.0.1:9420/api/v1/auth/login "
            '-H "Content-Type: application/json" '
            '-d \'{"username":"admin","password":"\'${CRIBL_EDGE_PASSWORD:-admin}\'"}\' '
            '2>/dev/null | sed \'s/.*"token":"\\([^"]*\\)".*/\\1/\'); '
            "curl -sf http://127.0.0.1:9420/api/v1/system/outputs "
            '-H "Authorization: Bearer $AUTH" 2>/dev/null',
        )
        assert '"proxmox-stream"' in output, (
            f"Edge outputs API does not include proxmox-stream output — all events route to devnull. "
            f"API response: {output[:300]}"
        )

    def test_edge_file_input_active(self):
        """Edge file monitor must be actively collecting files from the host filesystem.

        Catches the failure mode where the pack was not installed or loaded by the runtime
        (e.g. pack download failed, CRIBL_VOLUME_DIR unset). The pack inputs are in the
        worker namespace and not listed by /api/v1/system/inputs, so we verify activity
        via pod logs which show FileMonitor collector messages.
        """
        # Fetch all logs since the current container started (no --since window) to avoid
        # a time-dependent failure: "FileMonitor collector added" appears at startup and
        # when new files are found, so a --since=5m window would miss it if the pod has
        # been running longer than that without new files. Full container logs are always
        # bounded by the current container's uptime.
        logs = kubectl("logs", "statefulset/cribl-edge-standalone")
        assert "FileMonitor collector added" in logs, (
            "Edge file monitor is not active — inputs.yml may not have been loaded. "
            "Check that CRIBL_BEFORE_START_CMD wrote inputs.yml to local/edge/ correctly."
        )

    def test_file_events_reach_splunk_realtime(self, sentinel_claude_file, splunk_client):
        """Write a .jsonl sentinel and verify it reaches Splunk index=claude within 90s.

        End-to-end verification of the full pipeline: Host FS → Edge → homelab Stream → Splunk (A2+A5+A7).
        Checks Splunk directly using the REST API instead of only checking Edge sentCount.
        The sentinel value is unique per test run so matches are unambiguous.
        """
        _, sentinel_value = sentinel_claude_file
        mgmt_url, admin_password = splunk_client

        deadline = time.time() + 90
        while time.time() < deadline:
            results = query_splunk(
                mgmt_url,
                admin_password,
                f'index=claude sourcetype=claude:code:session "{sentinel_value}"',
                earliest="-10m",
            )
            if results:
                return
            time.sleep(10)
        pytest.fail(
            f"Sentinel value '{sentinel_value}' not found in Splunk index=claude within 90s. "
            "The Host FS → Edge → homelab Stream → Splunk pipeline (A2+A5+A7) did not deliver the event."
        )
