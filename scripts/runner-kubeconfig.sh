#!/bin/bash
# Generate a kubeconfig that works from inside an OrbStack Docker container
set -e
sed 's|https://127.0.0.1:26443|https://host.internal:26443|g' ~/.kube/config
