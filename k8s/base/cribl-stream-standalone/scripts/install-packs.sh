#!/bin/sh
# Install Stream packs via Cribl REST API. Modeled on the Edge install-packs.sh
# pattern — waits for API readiness, authenticates, installs packs (idempotent).
set -eu

API="http://127.0.0.1:9000/api/v1"

# Wait up to 10 minutes for Cribl Stream to accept API requests.
i=0
until curl -sf "${API}/health" >/dev/null 2>&1; do
  i=$((i+1)); [ "$i" -gt 120 ] && echo "Cribl Stream not ready after 10min" && exit 0
  sleep 5
done

TOKEN=$(curl -sf -X POST "${API}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"admin\",\"password\":\"${CRIBL_ADMIN_PASSWORD:-admin}\"}" \
  | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
[ -z "$TOKEN" ] && echo "WARNING: Auth failed, skipping pack install" && exit 0

# wait_and_reauth: called after each pack install triggers a worker reload.
# Health-check runs FIRST (API may be down during reload), then re-acquires
# the JWT (reload invalidates sessions), then guards against empty token.
wait_and_reauth() {
  j=0; until curl -sf "${API}/health" >/dev/null 2>&1; do
    j=$((j+1)); [ "$j" -gt 12 ] && echo "WARNING: API did not recover after reload, proceeding anyway" && break; sleep 5
  done
  TOKEN=$(curl -sf -X POST "${API}/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"admin\",\"password\":\"${CRIBL_ADMIN_PASSWORD:-admin}\"}" \
    | grep -o '"token":"[^"]*"' | cut -d'"' -f4) || TOKEN=""
  [ -z "$TOKEN" ] && echo "WARNING: Re-auth failed after reload, skipping remaining steps" && exit 0
}

CHANGED=0

PACK_COPILOT_REST_VERSION="v1.0.0"
PACK_COPILOT_REST="https://github.com/JacobPEvans/cc-stream-github-copilot-rest-io/releases/download/${PACK_COPILOT_REST_VERSION}/cc-stream-github-copilot-rest-io.crbl"

# Install GitHub Copilot REST collector pack (idempotent across pod restarts).
if ! curl -sf -H "Authorization: Bearer ${TOKEN}" "${API}/packs/cc-stream-github-copilot-rest-io" >/dev/null 2>&1; then
  curl -sf -X POST "${API}/packs" -H "Authorization: Bearer ${TOKEN}" \
    --retry 3 --retry-delay 10 --retry-all-errors --connect-timeout 30 --max-time 120 \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"cc-stream-github-copilot-rest-io\",\"source\":\"${PACK_COPILOT_REST}\"}" \
    || echo "WARNING: Copilot REST pack install failed"
  CHANGED=1
  sleep 10
  wait_and_reauth
fi

# Configure pack variables if GitHub Copilot credentials are available.
if [ -n "${GITHUB_COPILOT_PAT:-}" ]; then
  VARS="{\"github_pat\":\"${GITHUB_COPILOT_PAT}\""
  [ -n "${GITHUB_COPILOT_ORG:-}" ] && VARS="${VARS},\"github_org\":\"${GITHUB_COPILOT_ORG}\""
  VARS="${VARS}}"
  curl -sf -X PATCH "${API}/packs/cc-stream-github-copilot-rest-io" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"vars\":${VARS}}" \
    || echo "WARNING: Failed to configure Copilot REST pack variables"
  CHANGED=1
fi

# Commit config changes and reload only if something was installed or configured.
if [ "$CHANGED" -eq 1 ]; then
  curl -sf -X POST "${API}/version/commit" -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"message":"Pack installation"}' \
    || echo "WARNING: version/commit failed, worker may not have loaded config changes"
  curl -sf -X POST "${API}/system/settings/reload" \
    -H "Authorization: Bearer ${TOKEN}" \
    || echo "WARNING: settings reload failed, worker may not have loaded new packs"
fi

echo "Stream pack installation complete"
