# Testing Guide

## Overview

Tests are organized into five tiers, each building on the previous:

| Tier | Command | What It Verifies |
|------|---------|--------------------|
| 0 — Unit | `make test-unit` | Pure logic unit tests and manifest security checks (no cluster required) |
| 1 — Smoke | `make test-smoke` | Cluster reachable, all 5 pods Running, health endpoints respond |
| 2 — Pipeline | `make test-pipeline` | OTLP gRPC/HTTP send completes without error (A1) |
| 3 — Forwarding | `make test-forwarding` | Data flows through each pipeline leg, including Splunk receipt |
| 4 — Sourcetypes | `make test-sourcetypes` | Per-sourcetype sentinel E2E and config validation |

Run all tiers: `make test-all` (or individually with the commands above).

## Enforcement

CI enforcement is path-based: when the relevant files change, the corresponding tiers run in CI and block PR merges on failure:

| Tier | CI Workflow | Runner |
|------|-------------|--------|
| 0 — Unit + manifest tests | `validate.yml` (`unit-tests` job) | ubuntu-latest |
| 1–4 — Smoke, Pipeline, Forwarding, Sourcetypes | `e2e-tests.yml` | self-hosted Linux/ARM64 (Docker on macOS) |

The `e2e-tests.yml` workflow runs for changes under `k8s/**`, `scripts/**`, `tests/**`, or the `Makefile`; PRs that do not touch those paths will only run Tier 0 in CI.

Manual `make test-*` commands are available for local development and debugging.

## Self-Hosted Runner

The Tier 1–4 jobs execute inside an ephemeral [`myoung34/github-runner:ubuntu-jammy`](https://github.com/myoung34/docker-github-actions-runner) container running on the macOS host that owns the OrbStack k3s cluster. The container reaches the cluster API via `k8s.orb.local` (OrbStack injects DNS resolution for `*.orb.local` inside Docker containers).

**Architecture (zero custom code):**

- **Stock image** with `EPHEMERAL=1` — each registration is single-use: the runner registers, runs ONE job, deregisters cleanly, and exits with code 0 (removing its `.runner` config file on exit). `restart: unless-stopped` in `docker/actions-runner/docker-compose.yml` then restarts the runner container/service so it can register again for the next job. The container is NOT brand-new each time — bind-mounted state persists across jobs, and the container's writable layer is reused. The ephemeral runner's own cleanup is what ensures fresh-looking registration; the restart policy just brings the service back. This eliminates the "Cannot configure: already configured" crash loop that affected the previous setup.
- **Tools** (kubectl, kustomize, sops, age, yq, doppler, python) come from the workflow's `setup-e2e-tools` composite action, NOT from a custom image.
- **Boot persistence** is provided by a macOS LaunchAgent at `~/Library/LaunchAgents/com.<owner>.orbstack-runner.plist` installed by `make runner-install-launchagent`. The `<owner>` is the lowercase owner of `GITHUB_REPO` — run `make runner-print-label` to see the resolved Label. Under normal operation compose stays up and Docker handles the per-job restart cycle; `KeepAlive=true` on the LaunchAgent only respawns `make runner-foreground` if compose itself crashes.

**Operations:**

```sh
make runner-pull                   # pull the pinned myoung34/github-runner:ubuntu-jammy image
make runner-start                  # boot in background (one-shot, manual)
make runner-foreground             # boot in foreground (used by LaunchAgent)
make runner-stop                   # stop and remove the runner
make runner-status                 # container + GitHub registration status
make runner-logs                   # tail container logs
make runner-doctor                 # deep health check (container, registration, mounts, k8s reach, LaunchAgent)
make runner-install-launchagent    # install LaunchAgent (re-run from main worktree after merge)
make runner-uninstall-launchagent  # remove LaunchAgent
```

**Recovery:**

- **Container failed?** `launchctl kickstart -k gui/$(id -u)/$(make -s runner-print-label)` forces the LaunchAgent to respawn the runner.
- **Registration stuck?** Delete the orphan via `GH_TOKEN=$(doppler secrets get GH_PAT_RUNNER_TOKEN --plain -p gh-workflow-tokens -c prd) gh api -X DELETE "repos/${GITHUB_REPO}/actions/runners/<id>"`, then `launchctl kickstart -k ...`. Export `GITHUB_REPO` first or substitute your repo slug directly (e.g., from `make -n runner-status`).
- **LaunchAgent not loaded?** Run `make runner-install-launchagent` from the worktree you want it to point at (typically `~/git/orbstack-kubernetes/main`).
- **Logs:** `~/Library/Logs/orbstack-runner/{stdout,stderr}.log`.

The runner requires the macOS host to be powered on and OrbStack to be running. Sleep/wake and reboot are handled automatically by the LaunchAgent.

## Prerequisites

- Test venv installed: `make test-setup`
- For Tiers 1–4 (local only): OrbStack running with monitoring namespace deployed: `make deploy-doppler`
- Splunk HEC token configured: `SPLUNK_HEC_TOKEN` must be set in Doppler `iac-conf-mgmt/prd`
- Splunk management credentials in secret: `splunk-hec-config` must have `mgmt-url` and `admin-password` keys (populated automatically by `make deploy-doppler` when `SPLUNK_PASSWORD` is set)

## Test Files

### `tests/test_smoke.py`

Verifies infrastructure health — all pods running, all StatefulSets ready, service endpoints respond.
Does not verify data flow, only that components are alive.

### `tests/test_pipeline.py`

Verifies OTLP data can be ingested (A1: Client → OTEL Collector).
Sends a trace via gRPC and HTTP, asserts no transport errors.

### `tests/test_forwarding.py`

The main integration test suite. Three test classes:

**`TestCollectorToStreamForwarding`** — OTEL Collector → Cribl Stream (A4)

- Verifies no OTEL exporter errors after sending a trace
- Verifies Stream's OTLP input metrics show received events

**`TestStreamToSplunkForwarding`** — Cribl Stream → Splunk HEC (A7)

- `test_splunk_hec_output_healthy`: Cribl's output health API shows Green
- `test_splunk_hec_health_endpoint`: Splunk HEC health URL returns 200
- `test_splunk_hec_token_accepted`: POST to Splunk HEC with real token returns 200
- `test_splunk_hec_url_matches_secret`: Runtime config matches the Kubernetes secret
- `test_cribl_stream_no_output_errors`: Stream logs show no non-retryable output errors
- `test_cribl_stream_events_flowing`: Stream shows `outBytes > 0` in stats logs
- `test_otlp_events_reach_splunk_realtime` ✓Splunk: Sends OTLP trace with unique ID, **queries Splunk** for `index=claude` within 60s

**`TestClaudeCodeLogPipeline`** — Host FS → Edge → Stream → Splunk (A2+A5+A7)

- `test_claude_home_mount_accessible`: Edge pod can read `~/.claude/projects/`
- `test_sentinel_file_visible_in_edge_pod`: Host file appears in pod immediately
- `test_edge_file_monitor_config_path`: Pack input config has correct monitoring path
- `test_edge_file_monitor_picks_up_sentinel`: Edge FileMonitor logs "collector added" within 35s
- `test_edge_output_not_devnull`: Edge's default output routes to stream-hec (not devnull)
- `test_edge_file_input_active`: Edge FileMonitor is actively collecting files
- `test_file_events_reach_splunk_realtime` ✓Splunk: Writes sentinel `.jsonl`, **queries Splunk** for `index=claude sourcetype=claude:code:session` within 90s

Tests marked ✓Splunk verify data arrived in Splunk — not just that it was sent.

### `tests/test_unit.py`

Pure logic tests (no cluster needed):

- `test_parse_otel_error_lines`: Validates OTEL log parser
- `test_find_flowing_stats`: Validates Cribl stats parser
- `test_url_present_in_outputs_yaml`: Validates YAML URL matcher

### `tests/helpers.py`

Shared utility functions:

- `parse_otel_error_lines(log_text)`: Filters OTEL collector logs for error-level operational entries
- `find_flowing_stats(log_text)`: Finds Cribl Stream logs where `outBytes > 0`
- `url_present_in_outputs_yaml(url, yaml_text)`: Checks Splunk URL in Cribl output YAML
- `query_splunk(mgmt_url, admin_password, search, earliest)`: Queries Splunk REST API, returns list of result dicts

### `tests/conftest.py`

Shared fixtures and helpers:

- `cluster_ready`: Session fixture, skips all tests if OrbStack unreachable
- `splunk_client`: Returns `(mgmt_url, admin_password)` from `splunk-hec-config` secret; skips if keys absent
- `kubectl_exec_no_fail(*args)`: Run `kubectl exec` returning `(stdout, return_code)` without raising on failure

## Running Specific Tests

```bash
# Run a single test
make test-setup
.venv/bin/pytest tests/test_forwarding.py::TestClaudeCodeLogPipeline::test_file_events_reach_splunk_realtime -v

# Run all forwarding tests
make test-forwarding

# Run with extra verbosity for debugging
.venv/bin/pytest tests/test_forwarding.py -v -s
```

## Troubleshooting

### `splunk_client` fixture skipped

The `splunk-hec-config` secret is missing `mgmt-url` or `admin-password` keys. Run:

```bash
make deploy-doppler
```

Requires `SPLUNK_PASSWORD` and `SPLUNK_NETWORK` set in Doppler `iac-conf-mgmt/prd`.

### `test_file_events_reach_splunk_realtime` fails (sentinel not in Splunk)

Check each pipeline leg:

1. **Edge mount**: `kubectl exec -n monitoring cribl-edge-standalone-0 -- ls /home/claude/.claude/projects/`
2. **Edge FileMonitor**: `kubectl logs -n monitoring cribl-edge-standalone-0 --since=5m | grep FileMonitor`
3. **Edge→Stream sent**: Check Edge outputs API `sentCount` for `stream-hec`
4. **Stream→Splunk errors**: `kubectl logs -n monitoring cribl-stream-standalone-0 --since=5m | grep "400\|error"`
5. **Splunk HEC config**: `kubectl exec -n monitoring cribl-stream-standalone-0 -- cat /opt/cribl/data/local/cribl/outputs.yml`

### Tests pass but data goes to wrong Splunk index

The `force-splunk-meta` pipeline must set `index` (no underscore) — NOT `_index`. If events appear with `sourcetype=httpevent` or `index=default`, the pipeline is not running or has wrong field names. Check:

```bash
kubectl exec -n monitoring cribl-stream-standalone-0 -- \
  cat /opt/cribl/data/local/cribl/pipelines/force-splunk-meta/conf.yml
```

## Known Limitations

- **A3 (Host FS → Edge Managed)**: Not verified by forwarding tests; only pod health is checked
- **A6 (Edge Managed → Cribl Cloud)**: Not locally testable (cloud-managed)
- **A9 (MCP Server → Cribl Cloud)**: Not locally testable
- **A10 (Stream → GitHub REST API)**: Copilot REST metrics require a valid PAT + org; not locally testable
- **VS Code sourcetypes**: Covered by pack install validation (unit tests check cc-edge-vscode-io forbidden patterns); E2E sourcetype sentinels planned for future PR
- **Copilot sourcetypes** (`copilot:chat:otel`, `github:copilot:usage`): Routing rules validated by Stream pipeline config; E2E tests require active Copilot data sources

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full test coverage map.
