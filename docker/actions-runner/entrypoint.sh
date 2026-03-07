#!/bin/bash
set -e

# Configure runner if not already configured
if [ ! -f .runner ]; then
  ./config.sh \
    --url "https://github.com/${GITHUB_REPOSITORY}" \
    --token "${RUNNER_TOKEN}" \
    --labels "${RUNNER_LABELS:-self-hosted,Linux}" \
    --name "${RUNNER_NAME:-orbstack-runner}" \
    --unattended \
    --replace
fi

# Run cleanup on exit
cleanup() {
  ./config.sh remove --token "${RUNNER_TOKEN}" 2>/dev/null || true
}
trap cleanup EXIT

exec ./run.sh
