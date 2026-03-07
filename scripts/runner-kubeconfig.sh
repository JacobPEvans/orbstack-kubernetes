#!/bin/bash
# Generate a kubeconfig that works from inside an OrbStack Docker container.
# Rewrites the server URL and disables TLS verification (the cert's SANs don't cover host.internal).
set -e
sed \
  -e 's|https://127.0.0.1:26443|https://host.internal:26443|g' \
  -e 's|certificate-authority-data:.*|insecure-skip-tls-verify: true|g' \
  ~/.kube/config
