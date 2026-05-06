#!/usr/bin/env bash
# check-bifrost — fast triage diagnostic for the Bifrost gateway.
#
# Mirrors check-pal-mcp (in nix-ai) in style: tabular pass/fail with one-line
# hints, non-zero exit if any required check fails. Read-only — never modifies
# anything.
#
# Run after deploys, when Claude Code reports "Bifrost isn't working", or as
# the first step in any Bifrost-related troubleshooting.
#
# Usage:
#   ./scripts/check-bifrost.sh
#   make check-bifrost
#
# Environment overrides:
#   KUBE_CONTEXT       (default: orbstack)
#   KUBE_NAMESPACE     (default: monitoring)
#   DOPPLER_NAMESPACE  (default: doppler-operator-system)
#   BIFROST_URL        (default: http://localhost:30080)
#   MLX_URL            (default: http://localhost:11434)
#   PAL_CUSTOM_MODELS  (default: ~/.config/pal-mcp/custom_models.json)
set -euo pipefail

CONTEXT="${KUBE_CONTEXT:-orbstack}"
NAMESPACE="${KUBE_NAMESPACE:-monitoring}"
DOPPLER_NAMESPACE="${DOPPLER_NAMESPACE:-doppler-operator-system}"
BIFROST_URL="${BIFROST_URL:-http://localhost:30080}"
MLX_URL="${MLX_URL:-http://localhost:11434}"
PAL_CUSTOM_MODELS="${PAL_CUSTOM_MODELS:-$HOME/.config/pal-mcp/custom_models.json}"

EXPECTED_PROVIDERS=(openai gemini openrouter mlx-local)
EXPECTED_PROVIDER_KEYS=(OPENAI_API_KEY GEMINI_API_KEY OPENROUTER_API_KEY)
EXPECTED_NETWORK_POLICIES=(allow-bifrost-ingress allow-bifrost-egress)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { printf "[PASS] %-40s — %s\n" "$1" "$2"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf "[FAIL] %-40s — %s\n" "$1" "$2"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { printf "[WARN] %-40s — %s\n" "$1" "$2"; WARN_COUNT=$((WARN_COUNT + 1)); }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "FATAL: '$1' is required but not in PATH." >&2
    exit 2
  }
}

require_cmd kubectl
require_cmd curl
require_cmd jq

echo "=== Bifrost Health Diagnostic ==="
echo "Context: $CONTEXT  |  Namespace: $NAMESPACE  |  Bifrost: $BIFROST_URL"
echo ""

# 1. Bifrost pod is Ready ----------------------------------------------------
check_pod() {
  local name="1. bifrost pod ready"
  local json
  if ! json=$(kubectl --context "$CONTEXT" -n "$NAMESPACE" get pod -l app=bifrost -o json 2>/dev/null); then
    fail "$name" "kubectl unable to query pods — is OrbStack/cluster running?"
    return
  fi
  # All matching pods must be Ready. During a StatefulSet rolling update the
  # old pod is Ready while the new one is starting; "any ready" would mask
  # that the current pod is broken. Use a pod-level Ready condition (not
  # per-container ready) so we don't count terminating sidecars.
  local total ready
  total=$(jq '.items | length' <<<"$json")
  ready=$(jq '[.items[] | select((.status.conditions // []) | any(.type=="Ready" and .status=="True"))] | length' <<<"$json")
  if [ "$total" -ge 1 ] && [ "$ready" -eq "$total" ]; then
    pass "$name" "$ready/$total pod(s) Ready"
  else
    fail "$name" "$ready/$total Ready (rollout in progress?) — try: kubectl -n $NAMESPACE describe pod -l app=bifrost"
  fi
}

# 2. /health 200 -------------------------------------------------------------
check_health() {
  local name="2. /health endpoint"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 5 "$BIFROST_URL/health" 2>/dev/null || echo "000")
  if [ "$code" = "200" ]; then
    pass "$name" "$BIFROST_URL/health -> 200"
  else
    fail "$name" "$BIFROST_URL/health -> $code (000 = unreachable; pod may not be ready)"
  fi
}

# 3. /v1/models returns 200 with non-empty data -----------------------------
check_models_response() {
  local name="3. /v1/models payload"
  local body code
  body=$(curl -sS --max-time 5 -w "\n%{http_code}" "$BIFROST_URL/v1/models" 2>/dev/null || true)
  code="${body##*$'\n'}"
  body="${body%$'\n'*}"
  if [ "$code" != "200" ]; then
    fail "$name" "expected 200, got $code — likely bifrost-provider-keys Secret missing"
    return
  fi
  local count
  count=$(jq -r '.data | length' <<<"$body" 2>/dev/null || echo 0)
  if [ "$count" -ge 4 ]; then
    pass "$name" "200 with $count models"
  else
    fail "$name" "200 but only $count models — provider list calls may be failing upstream"
  fi
}

# 4. All 4 expected providers present in the model list ----------------------
check_provider_coverage() {
  local name="4. provider coverage"
  local body
  body=$(curl -sS --max-time 5 "$BIFROST_URL/v1/models" 2>/dev/null || echo "{}")
  local present
  present=$(jq -r '[.data[]?.id // empty | split("/")[0]] | unique | join(",")' <<<"$body" 2>/dev/null || echo "")
  local missing=()
  for p in "${EXPECTED_PROVIDERS[@]}"; do
    if [[ ",$present," != *",$p,"* ]]; then
      missing+=("$p")
    fi
  done
  if [ ${#missing[@]} -eq 0 ]; then
    pass "$name" "all four providers present (${present})"
  else
    fail "$name" "missing: ${missing[*]} (present: ${present:-none}) — check provider-key Secret + vllm-mlx"
  fi
}

# 5. bifrost-provider-keys Secret exists with all 3 keys --------------------
check_provider_secret() {
  local name="5. bifrost-provider-keys Secret"
  local json
  if ! json=$(kubectl --context "$CONTEXT" -n "$NAMESPACE" get secret bifrost-provider-keys -o json 2>/dev/null); then
    fail "$name" "Secret not found — DopplerSecret may not have synced yet"
    return
  fi
  local missing=()
  for k in "${EXPECTED_PROVIDER_KEYS[@]}"; do
    if ! jq -e --arg k "$k" '.data[$k] // empty' <<<"$json" >/dev/null 2>&1; then
      missing+=("$k")
    fi
  done
  if [ ${#missing[@]} -eq 0 ]; then
    pass "$name" "all ${#EXPECTED_PROVIDER_KEYS[@]} expected keys present"
  else
    fail "$name" "missing keys: ${missing[*]} — check DopplerSecret 'secrets:' list"
  fi
}

# 6. DopplerSecret reports SecretSyncReady=True ------------------------------
check_doppler_sync() {
  local name="6. DopplerSecret sync status"
  local json
  if ! json=$(kubectl --context "$CONTEXT" -n "$DOPPLER_NAMESPACE" get dopplersecret bifrost-provider-keys -o json 2>/dev/null); then
    warn "$name" "DopplerSecret CR not found in $DOPPLER_NAMESPACE — operator may not be installed (override DOPPLER_NAMESPACE if elsewhere)"
    return
  fi
  local status reason
  status=$(jq -r '.status.conditions[]? | select(.type=="secrets.doppler.com/SecretSyncReady") | .status' <<<"$json")
  reason=$(jq -r '.status.conditions[]? | select(.type=="secrets.doppler.com/SecretSyncReady") | .reason' <<<"$json")
  if [ "$status" = "True" ]; then
    pass "$name" "SecretSyncReady=True (${reason:-OK})"
  else
    fail "$name" "SecretSyncReady=${status:-unknown} reason=${reason:-unknown} — kubectl logs in doppler-operator-system"
  fi
}

# 7. vllm-mlx LaunchAgent loaded (macOS only) -------------------------------
check_vllm_launchagent() {
  local name="7. vllm-mlx LaunchAgent"
  if [ "$(uname)" != "Darwin" ]; then
    warn "$name" "non-Darwin host — skipping launchctl check"
    return
  fi
  if ! command -v launchctl >/dev/null 2>&1; then
    warn "$name" "launchctl not in PATH — skipping"
    return
  fi
  if launchctl list 2>/dev/null | grep -q "vllm-mlx"; then
    pass "$name" "loaded — Bifrost mlx-local routing has a backend"
  else
    fail "$name" "not loaded — start it via your nix-ai LaunchAgent or 'launchctl bootstrap' the plist"
  fi
}

# 8. vllm-mlx /v1/models direct ---------------------------------------------
check_vllm_models() {
  local name="8. vllm-mlx /v1/models direct"
  local body code
  body=$(curl -sS --max-time 5 -w "\n%{http_code}" "$MLX_URL/v1/models" 2>/dev/null || true)
  code="${body##*$'\n'}"
  body="${body%$'\n'*}"
  if [ "$code" != "200" ]; then
    fail "$name" "$MLX_URL/v1/models -> $code — Bifrost mlx-local will fail through host.docker.internal:11434"
    return
  fi
  local count
  count=$(jq -r '.data | length' <<<"$body" 2>/dev/null || echo 0)
  if [ "$count" -ge 1 ]; then
    pass "$name" "200 with $count model(s) loaded"
  else
    warn "$name" "200 but no models — first request will trigger cold-load (may exceed 60s)"
  fi
}

# 9. Required NetworkPolicies exist ------------------------------------------
check_network_policies() {
  local name="9. Bifrost NetworkPolicies"
  local missing=()
  for np in "${EXPECTED_NETWORK_POLICIES[@]}"; do
    if ! kubectl --context "$CONTEXT" -n "$NAMESPACE" get networkpolicy "$np" >/dev/null 2>&1; then
      missing+=("$np")
    fi
  done
  if [ ${#missing[@]} -eq 0 ]; then
    pass "$name" "${EXPECTED_NETWORK_POLICIES[*]} all present"
  else
    fail "$name" "missing: ${missing[*]} — re-apply k8s/monitoring/network-policies/"
  fi
}

# 10. PAL custom_models.json sanity ------------------------------------------
check_pal_custom_models() {
  local name="10. PAL custom_models.json"
  if [ ! -f "$PAL_CUSTOM_MODELS" ]; then
    warn "$name" "$PAL_CUSTOM_MODELS not found — PAL may not be configured on this host"
    return
  fi
  if ! jq empty "$PAL_CUSTOM_MODELS" >/dev/null 2>&1; then
    fail "$name" "$PAL_CUSTOM_MODELS is not valid JSON"
    return
  fi
  # Each entry's "model_name" (or "id") must be in <provider>/<rest> form, and the
  # provider must be one of the four Bifrost providers. Branch on the top-level
  # type so this works for {models:[...]} (real PAL format), {data:[...]}
  # (OpenAI-style), and bare-array shapes — the previous .[]?//.data[]? form
  # silently skipped object payloads.
  local bad
  bad=$(jq -r '
    (if type == "array" then .
     elif (.models | type) == "array" then .models
     elif (.data | type) == "array" then .data
     else [] end)
    | map(.model_name // .id // empty)
    | map(select(length > 0))
    | map(select((contains("/") | not) or (split("/")[0] | IN("openai","gemini","openrouter","mlx-local") | not)))
    | join(", ")
  ' "$PAL_CUSTOM_MODELS" 2>/dev/null || echo "")
  if [ -z "$bad" ]; then
    pass "$name" "all entries use a known <provider>/<model> prefix"
  else
    fail "$name" "bad slugs: $bad — Bifrost will reject anything outside ${EXPECTED_PROVIDERS[*]}"
  fi
}

# 11. Repo deny-list scan ----------------------------------------------------
check_repo_deny_list() {
  local name="11. repo slug deny-list"
  # Scan the entire repo so we catch slugs in .github/workflows/, tests/, docs,
  # or any future top-level dir. The grep --exclude-dir flags drop generated
  # caches and venvs that would otherwise cause noise.
  # Common args (match the patterns we care about across all candidate paths)
  local grep_common=(
    -rEn
    --include='*.yaml' --include='*.yml' --include='*.json' --include='*.sh'
    --exclude='check-bifrost*'
    --exclude-dir='.git'
    --exclude-dir='.venv'
    --exclude-dir='.direnv'
    --exclude-dir='.pytest_cache'
    --exclude-dir='.ruff_cache'
    --exclude-dir='node_modules'
    --exclude-dir='overlays'
  )
  local found=()
  # 11a. Hard-banned literal slugs
  local banned_literal_hits
  banned_literal_hits=$(grep "${grep_common[@]}" 'openrouter/free' "$REPO_ROOT" 2>/dev/null || true)
  [ -n "$banned_literal_hits" ] && found+=("openrouter/free:" "$banned_literal_hits")
  # 11b. Bare mlx-community/... (must be prefixed with mlx-local/)
  local bare_mlx_hits
  bare_mlx_hits=$(grep "${grep_common[@]}" 'mlx-community/' "$REPO_ROOT" 2>/dev/null \
    | grep -v 'mlx-local/mlx-community/' \
    | grep -v 'config\.schema\.json' \
    || true)
  [ -n "$bare_mlx_hits" ] && found+=("bare mlx-community/...:" "$bare_mlx_hits")
  if [ ${#found[@]} -eq 0 ]; then
    pass "$name" "no openrouter/free or bare mlx-community/ slugs in committed configs"
  else
    fail "$name" "deny-list match — fix and re-run:"
    printf '         %s\n' "${found[@]}"
  fi
}

check_pod
check_health
check_models_response
check_provider_coverage
check_provider_secret
check_doppler_sync
check_vllm_launchagent
check_vllm_models
check_network_policies
check_pal_custom_models
check_repo_deny_list

echo ""
echo "=== Summary: ${PASS_COUNT} pass / ${WARN_COUNT} warn / ${FAIL_COUNT} fail ==="

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
