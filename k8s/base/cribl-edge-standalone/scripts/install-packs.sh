#!/bin/sh
# Install Edge packs via Cribl REST API. Using the API instead of manual
# download/extract/merge eliminates the duplicated curl+tar+rm pattern per pack.
set -eu

API="http://127.0.0.1:9420/api/v1"

# Wait up to 10 minutes for Cribl to accept API requests.
i=0
until curl -sf "${API}/health" >/dev/null 2>&1; do
  i=$((i+1)); [ "$i" -gt 120 ] && echo "Cribl not ready after 10min" && exit 0
  sleep 5
done

TOKEN=$(curl -sf -X POST "${API}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"admin\",\"password\":\"${CRIBL_EDGE_PASSWORD:-admin}\"}" \
  | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
[ -z "$TOKEN" ] && echo "WARNING: Auth failed, skipping pack install" && exit 0

PACK_CLAUDE="https://github.com/JacobPEvans/cc-edge-claude-code-otel/releases/download/v2.0.0/cc-edge-claude-code-otel.crbl"
PACK_GEMINI="https://github.com/JacobPEvans/cc-edge-gemini-antigravity-io/releases/download/v0.1.0/cc-edge-gemini-antigravity-io.crbl"

# Install each pack only if not already present (idempotent across pod restarts).
# Each pack install triggers a Cribl worker reload. We must wait for the reload
# to complete before installing the next pack, otherwise the second install
# happens during the first reload and the worker never loads the second pack
# until the next file-change-triggered reload (which can be minutes later).
CHANGED=false

if ! curl -sf -H "Authorization: Bearer ${TOKEN}" "${API}/packs/cc-edge-claude-code" >/dev/null 2>&1; then
  curl -sf -X POST "${API}/packs" -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"cc-edge-claude-code\",\"source\":\"${PACK_CLAUDE}\"}" \
    || echo "WARNING: Claude pack install failed"
  CHANGED=true
  # Wait for Cribl worker to finish reloading after Claude pack install.
  sleep 10
fi

# Cribl auto-disables gemini-cli-otel (port 4317 conflict with claude-code-otel).
if ! curl -sf -H "Authorization: Bearer ${TOKEN}" "${API}/packs/cc-edge-gemini-antigravity" >/dev/null 2>&1; then
  curl -sf -X POST "${API}/packs" -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"cc-edge-gemini\",\"source\":\"${PACK_GEMINI}\"}" \
    || echo "WARNING: Gemini pack install failed"
  CHANGED=true
fi

# Edge 4.16.x bug: FileMonitor ignores filename patterns not starting with '*'.
# Literal filenames (config.json, history.jsonl, etc.) and patterns with '*' in
# the middle (session-*.json) are never discovered. Replace all affected patterns
# with leading-wildcard equivalents so FileMonitor actually picks them up.
# Match both quoted ("config.json") and bare YAML (- config.json) forms.
PACK_DIR="${CRIBL_VOLUME_DIR}/default/cc-edge-claude-code"
sed -i \
  -e 's/"session-\*\.json"/"*.json"/' \
  -e 's/- config\.json$/- "*.json"/' \
  -e 's/- history\.jsonl$/- "*.jsonl"/' \
  -e 's/- stats-cache\.json$/- "*.json"/' \
  -e 's/- installed_plugins\.json$/- "*.json"/' \
  "${PACK_DIR}/inputs.yml" 2>/dev/null || true

# Force Cribl to commit all pending config changes and reload the worker.
# Without this, packs installed via REST API may not be loaded by the worker
# until the next file-change-triggered reload (which can be minutes later).
if [ "$CHANGED" = "true" ]; then
  curl -sf -X POST "${API}/version/commit" -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"message":"Pack installation and FileMonitor patches","effective":true}' \
    || true
fi

echo "Pack installation complete"
