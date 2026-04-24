# Contributing

This is a single-maintainer repository for a local OrbStack Kubernetes cluster. External contributions are welcome but the bar is high — changes must not break the live monitoring pipeline.

## Setup

```sh
direnv allow      # one-time per worktree, auto-activates on cd
nix develop       # manual activation if direnv isn't installed
```

Requires: kubectl, kustomize, kubeconform, OrbStack with k3s running.

## Workflow

1. Sync and create a worktree before starting:
   ```sh
   cd ~/git/orbstack-kubernetes/main
   git fetch --prune origin && git pull
   git worktree add ~/git/orbstack-kubernetes/<type>/<name> -b <type>/<name> main
   ```

2. Make changes, then run unit tests (no cluster required):
   ```sh
   make test-unit
   ```

3. Verify the full stack if your change touches `k8s/` or `scripts/`:
   ```sh
   make deploy
   make test-e2e
   ```

4. Open a PR with a [Conventional Commit](https://www.conventionalcommits.org/) title:
   - `fix:` for bug fixes and small adjustments → patch release
   - `feat:` for new capabilities → minor release
   - `chore:`, `docs:`, `ci:` for non-release changes

## Rules

- **No plaintext secrets.** All secrets live in `secrets.enc.yaml` (SOPS-encrypted). See `docs/DEPLOYMENT.md`.
- **No hardcoded local paths.** Base manifests use `PLACEHOLDER_HOME_DIR`; real paths are injected by the generated overlay.
- **Edge → Stream → Splunk** is the only allowed data path. The architecture invariant tests enforce this.
- **Image tags stay `latest`** for upstream images. Renovate and the Trivy scan handle supply-chain hygiene.

## Testing

See [docs/TESTING.md](docs/TESTING.md) for the full test tier breakdown (unit → smoke → pipeline → forwarding → sourcetypes).
