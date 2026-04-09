# orbstack-kubernetes

Kubernetes manifests for local OrbStack cluster.

## Architecture Invariant

**Edge → Stream → Splunk is the ONLY allowed data path.**

- `cribl-edge-standalone` sends ONLY to `cribl-stream-standalone` (HEC port 8088). It MUST NOT talk directly to Splunk.
- `cribl-stream-standalone` is the ONLY component with Splunk egress.
- Network policies enforce this: edge egress is locked to stream:8088 only.

## Key Rules

- **PLACEHOLDER_HOME_DIR**: Base manifests use literal `PLACEHOLDER_HOME_DIR` for hostPath volumes. NEVER replace with real paths in `k8s/monitoring/`.
- **Overlays are gitignored**: `k8s/overlays/local/` is generated at deploy time by `scripts/generate-overlay.sh` and must not be committed.
- **Deploy workflow**: `make deploy` generates overlay + creates secrets + applies kustomize.
- **Secrets**: All secrets in SOPS (`secrets.enc.yaml`). Doppler project/config stored in SOPS, never hardcoded. Never commit plaintext secrets.
- **Image tags**: Use `latest` for upstream images (Cribl, OTEL, etc.). Do NOT pin specific versions — Renovate and upstream release tracking handle updates.
- **Worktrees**: Use `/init-worktree` before starting work. Work in feature branches.

## Deployment Verification

CI enforces deployment verification via the `e2e-tests.yml` workflow on a self-hosted runner.
Every PR touching `k8s/**`, `scripts/**`, `Makefile`, or `tests/**` automatically triggers
a full deploy + E2E test run that blocks merge on failure.

**Manual verification** (for local troubleshooting only):

1. `make deploy-doppler` (or `kubectl apply -k k8s/overlays/local/` if SOPS key unavailable)
2. Wait for rollouts: `kubectl --context orbstack -n monitoring rollout status statefulset/<name>`
3. Verify pods are Running and Ready: `make status`
4. Check logs for errors: `kubectl --context orbstack -n monitoring logs statefulset/<name> --tail=20`

## Architecture

See [Architecture Diagram](docs/ARCHITECTURE.md) for the full data flow and test coverage map.

Four CronJobs ping [healthchecks.io](https://healthchecks.io) every 5 minutes as dead-man's switches:
`pipeline-heartbeat` (Stream), `heartbeat-splunk`, `heartbeat-edge`, `heartbeat-otel`.
Ping URLs stored in SOPS (`HEALTHCHECKS_*_URL` keys), injected as `heartbeat-config` secret by `deploy.sh`.

Six StatefulSets in the monitoring namespace:

| StatefulSet | Role | UI |
|------------|------|-----|
| `otel-collector` | OTLP receiver, forwards to Cribl Stream Standalone | None |
| `cribl-edge-managed` | Cloud-managed edge, forwards to Cribl Cloud | None |
| `cribl-edge-standalone` | Local edge with 3 packs ([claude-code-otel](https://github.com/JacobPEvans/cc-edge-claude-code-otel), [gemini-antigravity-io](https://github.com/JacobPEvans/cc-edge-gemini-antigravity-io), [vscode-io](https://github.com/JacobPEvans/cc-edge-vscode-io)), forwards to Cribl Stream Standalone | :30910 |
| `cribl-stream-standalone` | Local Stream leader with UI, [Copilot REST collector](https://github.com/JacobPEvans/cc-stream-github-copilot-rest-io) pack, outputs to Splunk HEC | :30900 |
| `cribl-mcp-server` | Cribl Cloud MCP API server for Claude Code | :30030 |
| `bifrost` | [Bifrost](https://github.com/maximhq/bifrost) AI gateway — multi-provider routing (OpenAI, Gemini, OpenRouter, local MLX) via OpenAI-compatible API. Secrets from Doppler K8s Operator. | :30080 |

Directory layout:

- `k8s/monitoring/` - Kustomize base manifests for the monitoring stack (portable, no real paths)
- `k8s/overlays/local/` - Generated overlay with real volume paths (gitignored)
- `k8s/sandbox/` - AI sandbox container manifests (populated in a follow-up PR)
- `scripts/` - Deployment and overlay generation scripts
- `docker/` - Dockerfiles for ephemeral AI containers
- `packs/` - (removed — packs now installed via `cribl pack install` from GitHub releases at pod startup). Edge: cc-edge-claude-code-otel, cc-edge-gemini-antigravity-io, cc-edge-vscode-io. Stream: cc-stream-github-copilot-rest-io. Note: `.crbl` downloads have no checksum/signature verification — acceptable for local OrbStack dev stack.
- `docs/` - Extended documentation

## Dev Environment

Uses [Nix flakes](https://wiki.nixos.org/wiki/Flakes) + [direnv](https://direnv.net/) for a reproducible dev environment.

```sh
direnv allow    # one-time per worktree, then automatic on cd
nix develop     # manual activation
```

**Tools**: kubectl, kubectx, helm, helmfile, helm-docs, kustomize, kubeconform, kube-linter, conftest, pluto, k9s, stern, kind, jq, yq

## CI

GitHub Actions run on every push and PR:

- **validate.yml** (ubuntu-latest, blocking) — kustomize + kubeconform + yamllint + pre-commit + unit/manifest tests + Dockerfile scan
- **e2e-tests.yml** (self-hosted macOS, blocking) — deploy + full E2E test suite (smoke → pipeline → forwarding → sourcetypes)
- **validate-merged.yml** (ubuntu-latest) — post-merge schema validation of last 3 commits

## Testing

See [Testing Guide](docs/TESTING.md) for full documentation on test tiers, prerequisites, and troubleshooting.

All tiers are enforced in CI. For local debugging:

```bash
make test-unit         # Unit + manifest tests (no cluster required)
make test-smoke        # Smoke tests (pod health)
make test-pipeline     # Pipeline tests (OTLP flow)
make test-forwarding   # Forwarding tests (Cribl routing)
make test-sourcetypes  # Per-sourcetype E2E tests
make test-e2e          # Full E2E suite (smoke → pipeline → forwarding → sourcetypes)
make test-all          # All tests in order: unit → e2e
```
