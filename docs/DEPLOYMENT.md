# Deployment Guide

## Prerequisites

- OrbStack with Kubernetes enabled
- `kubectl` configured with `orbstack` context
- `doppler` CLI authenticated (`doppler login`) for Cribl secrets
- `sops` and `age` installed (for secret management)
- `kustomize` (bundled with kubectl 1.14+)

## Secret Management

All secrets are stored in SOPS-encrypted `secrets.enc.yaml`, including the Doppler project/config used to fetch Cribl secrets at deploy time.

| Secret | Purpose |
|--------|---------|
| `DOPPLER_PROJECT` | Doppler project name (for Cribl secrets) |
| `DOPPLER_CONFIG` | Doppler config name (for Cribl secrets) |
| `CRIBL_CLOUD_MASTER_URL` | Alternative: direct Cribl Edge URL (if not using Doppler) |
| `SPLUNK_HEC_TOKEN` | Splunk HEC token (standalone edge to Splunk) |
| `SPLUNK_NETWORK` | Splunk IP(s) from terraform output (JSON array, e.g. `["192.168.0.200"]`). HEC URL is derived automatically at deploy time. |
| `CLAUDE_API_KEY` | AI container API key |
| `GEMINI_API_KEY` | AI container API key |

### SOPS Setup (one-time)

```bash
# Ensure your age key exists
ls ~/.config/sops/age/keys.txt

# Create and encrypt secrets
cp secrets.enc.yaml.example secrets.enc.yaml
sops secrets.enc.yaml
```

## Deploy

### Quick Deploy (Doppler + SOPS)

```bash
make deploy-doppler
```

This reads Doppler project/config from SOPS, fetches Cribl secrets (including `CRIBL_DIST_MASTER_URL`) via Doppler, and deploys the full stack.

### Deploy Without Doppler

If Cribl secrets are set directly in `secrets.enc.yaml` (via `CRIBL_CLOUD_MASTER_URL`):

```bash
sops exec-env secrets.enc.yaml 'make deploy'
```

### Step-by-Step

```bash
# 1. Generate local overlay (replaces PLACEHOLDER_HOME_DIR with real paths)
make generate-overlay

# 2. Validate kustomize output
make validate

# 3. Deploy with secrets
make deploy-doppler
```

## Cribl Stream (homelab)

The laptop runs no Cribl Stream. All Edge egress is Cribl S2S on port 10300 to the homelab HAProxy-fronted Cribl Stream (host resolved from the `CRIBL_S2S_HOST` env var at container start), which passes events through to Splunk HEC. Index/sourcetype stamping and PII masking happen at the Edge output (`force-splunk-meta` pipeline) before egress.

## OTLP Telemetry

The OTEL Collector forwards telemetry via gRPC to `cribl-edge-standalone:4317`. The standalone Edge instance has an `open_telemetry` source configured on port 4317.

## Verify

```bash
# Check all pods are Running
make status

# Check OTEL Collector health (distroless image — use port-forward, not kubectl exec)
kubectl port-forward -n monitoring statefulset/otel-collector 13133:13133 &
curl -s http://localhost:13133/ && kill %1

# Check Cribl Edge managed logs
kubectl logs -n monitoring statefulset/cribl-edge-managed --tail=10

# Check Cribl Edge standalone UI
open http://localhost:30910

# Verify Cribl Edge standalone health (OTEL target)
kubectl exec -n monitoring statefulset/cribl-edge-standalone -- curl -sf http://localhost:9420/api/v1/health
```

## Update

After modifying base manifests:

```bash
make deploy-doppler
```

## Tear Down

```bash
make clean
```

This deletes the entire monitoring namespace and all resources within it.
