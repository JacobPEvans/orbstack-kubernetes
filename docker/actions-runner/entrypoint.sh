#!/bin/bash
set -e

if [ ! -f .runner ]; then
  ./config.sh \
    --url "https://github.com/${GITHUB_REPOSITORY}" \
    --token "${RUNNER_TOKEN}" \
    --labels "${RUNNER_LABELS:-self-hosted,Linux}" \
    --name "${RUNNER_NAME:-orbstack-runner}" \
    --unattended \
    --replace
fi

cleanup() {
  ./config.sh remove --token "${RUNNER_TOKEN}" 2>/dev/null || true
}
trap cleanup EXIT

./run.sh
