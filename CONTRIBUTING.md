# Contributing

This is a single-maintainer repository for a local OrbStack Kubernetes cluster. External contributions are welcome but the bar is high — changes must not break the live monitoring pipeline.

## Setup

Requires: kubectl, kustomize, kubeconform, OrbStack with k3s running.

**With direnv (recommended)** — auto-activates the dev shell whenever you `cd` into the worktree:

```sh
direnv allow      # one-time per worktree
```

**Without direnv** — manually enter the dev shell each time:

```sh
nix develop
```

## Pre-Commit Setup

Install the pre-commit hooks once per fresh clone or new worktree:

```sh
pre-commit install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push
```

On first-time setup (or after pulling new hook revisions), run the full suite once to verify every hook resolves and passes against the current tree:

```sh
pre-commit run --all-files
```

## Workflow

1. From the main worktree, sync and create a new worktree:

   ```sh
   git fetch --prune origin && git pull
   git worktree add ../<type>/<name> -b <type>/<name> main
   ```

   (The `../<type>/<name>` path keeps the worktree alongside `main/` in
   whatever directory layout you use locally.)

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
