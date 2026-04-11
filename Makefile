.PHONY: help validate validate-schemas generate-overlay deploy deploy-doppler status logs build-images test test-e2e test-smoke test-pipeline test-forwarding test-sourcetypes test-unit test-all test-setup warmup warmup-e2e full-power power-save power-status monitoring-up monitoring-down clean runner-build runner-kubeconfig runner-start runner-stop runner-status runner-logs runner-doctor runner-install-launchagent runner-uninstall-launchagent

CONTEXT ?= orbstack
NAMESPACE := monitoring
GITHUB_REPO ?= JacobPEvans/orbstack-kubernetes
KUSTOMIZE_DIRS := k8s/monitoring k8s/sandbox
MONITORING_STATEFULSETS := otel-collector cribl-edge-managed cribl-edge-standalone cribl-stream-standalone cribl-mcp-server bifrost
PYTEST_CHECK := test -x .venv/bin/pytest || { echo "Run 'make test-setup' first to install test dependencies"; exit 1; }
UNIT_TEST_FILES := tests/test_unit.py tests/test_manifests.py tests/test_conftest_utils.py

help: ## Show all targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

validate: ## Validate kustomize builds (syntax + references)
	@for dir in $(KUSTOMIZE_DIRS); do \
		kubectl kustomize $$dir/ > /dev/null; \
	done

validate-schemas: ## Validate rendered manifests against K8s schemas
	@for dir in $(KUSTOMIZE_DIRS); do \
		bash -c 'set -o pipefail; kubectl kustomize "$$1" | kubeconform -strict -summary -output text' -- $$dir || exit 1; \
	done

generate-overlay: ## Generate local overlay with real volume paths
	./scripts/generate-overlay.sh

deploy: ## Full deploy: generate overlay + create secrets + apply
	./scripts/deploy.sh

deploy-doppler: ## Deploy with Cribl secrets from Doppler (project/config in SOPS)
	@if [ -n "$$DOPPLER_TOKEN" ]; then ./scripts/deploy-doppler.sh; else sops exec-env secrets.enc.yaml './scripts/deploy-doppler.sh'; fi

status: ## Show monitoring namespace status
	kubectl --context $(CONTEXT) get all -n $(NAMESPACE)

logs: ## Tail all pod logs in monitoring namespace
	kubectl --context $(CONTEXT) -n $(NAMESPACE) logs -l app.kubernetes.io/part-of=claude-monitoring --all-containers --tail=50 -f

build-images: ## Build Claude Code and Gemini CLI Docker images
	docker build -t orbstack-kubernetes/claude-code:latest docker/claude-code/
	docker build -t orbstack-kubernetes/gemini-cli:latest docker/gemini-cli/


test: ## Run all pipeline tests (requires deployed stack)
	@$(PYTEST_CHECK)
	.venv/bin/pytest tests/ -v

test-smoke: ## Run smoke tests only (pod health + services)
	@$(PYTEST_CHECK)
	.venv/bin/pytest tests/test_smoke.py -v

test-pipeline: ## Run OTLP pipeline tests (sends test traces)
	@$(PYTEST_CHECK)
	.venv/bin/pytest tests/test_pipeline.py -v

test-forwarding: ## Run forwarding tests (Cribl pipeline)
	@$(PYTEST_CHECK)
	.venv/bin/pytest tests/test_forwarding.py -v

test-sourcetypes: ## Run per-sourcetype E2E tests
	@$(PYTEST_CHECK)
	.venv/bin/pytest tests/test_sourcetypes.py -v

test-unit: ## Run unit tests (no cluster required)
	@$(PYTEST_CHECK)
	.venv/bin/pytest $(UNIT_TEST_FILES) -v

test-e2e: ## Run full test suite in order (smoke → pipeline → forwarding → sourcetypes)
	@$(PYTEST_CHECK)
	.venv/bin/pytest tests/test_smoke.py tests/test_pipeline.py tests/test_forwarding.py tests/test_sourcetypes.py -v --tb=short -x

test-all: ## Run all tests in order: unit → smoke → pipeline → forwarding → sourcetypes
	@$(PYTEST_CHECK)
	.venv/bin/pytest $(UNIT_TEST_FILES) tests/test_smoke.py tests/test_pipeline.py tests/test_forwarding.py tests/test_sourcetypes.py -v --tb=short

test-setup: ## Install test dependencies in virtual environment
	python3 -m venv .venv
	.venv/bin/pip install -r tests/requirements.txt

warmup-e2e: ## Verify full pipeline delivers traces to Splunk (blocking gate)
	@$(PYTEST_CHECK)
	.venv/bin/python3 scripts/warmup-e2e.py

warmup: ## Send warmup trace to prime OTEL gRPC connection (retries 3x)
	@$(PYTEST_CHECK)
	@for attempt in 1 2 3; do \
		if .venv/bin/python3 scripts/otel-warmup.py; then \
			echo "Warmup succeeded on attempt $$attempt"; \
			break; \
		elif [ "$$attempt" -lt 3 ]; then \
			echo "Warmup attempt $$attempt failed, retrying in 5s..."; \
			sleep 5; \
		else \
			echo "ERROR: OTEL warmup failed after 3 attempts"; \
			exit 1; \
		fi; \
	done

power-save: ## Scale all monitoring pods to 0 replicas (battery saver)
	@echo "Scaling down monitoring stack..."
	kubectl --context $(CONTEXT) -n $(NAMESPACE) scale statefulset $(MONITORING_STATEFULSETS) --replicas=0
	@echo "All monitoring pods scaled to 0. Run 'make full-power' to restore."

full-power: ## Scale all monitoring pods to 1 replica (full power)
	@echo "Scaling up monitoring stack..."
	kubectl --context $(CONTEXT) -n $(NAMESPACE) scale statefulset $(MONITORING_STATEFULSETS) --replicas=1
	@echo "Waiting for rollouts..."
	@for sts in $(MONITORING_STATEFULSETS); do \
		kubectl --context $(CONTEXT) -n $(NAMESPACE) rollout status statefulset/$$sts --timeout=120s; \
	done
	@echo "All monitoring pods restored."

monitoring-up: full-power ## Alias for full-power

monitoring-down: power-save ## Alias for power-save

power-status: ## Show monitoring pod replica counts and macOS power source
	@kubectl --context $(CONTEXT) -n $(NAMESPACE) get statefulsets --no-headers 2>/dev/null | awk '{printf "  %-35s %s\n", $$1, $$2}'
	@echo ""
	@pmset -g batt 2>/dev/null | head -1 || true

clean: ## Delete monitoring and sandbox namespaces (destructive!)
	kubectl --context $(CONTEXT) delete namespace $(NAMESPACE) --ignore-not-found
	kubectl --context $(CONTEXT) delete namespace ai-sandbox --ignore-not-found

# ─── Self-Hosted GitHub Actions Runner ────────────────────────────────────────
# Stock myoung34/github-runner image (multi-arch, EPHEMERAL=1) managed by
# docker compose, with boot persistence provided by a macOS LaunchAgent.
# Tools (kubectl/sops/age/yq/doppler/python) are installed PER-JOB by
# .github/actions/setup-e2e-tools — no custom image needed.
#
# Lifecycle:
#   make runner-pull                   → pull the latest stock image
#   make runner-foreground             → boot in foreground (LaunchAgent uses this)
#   make runner-start                  → boot in background (manual one-shot)
#   make runner-stop                   → stop the runner container
#   make runner-doctor                 → deep health check
#   make runner-install-launchagent    → install LaunchAgent for boot persistence
#   make runner-uninstall-launchagent  → remove LaunchAgent
#
# After installing the LaunchAgent, the runner is fully self-healing:
#   - per-job: EPHEMERAL=1 → exits cleanly → `restart: unless-stopped` respawns
#   - host-level (reboot/OrbStack restart): LaunchAgent KeepAlive=true respawns
# ──────────────────────────────────────────────────────────────────────────────

RUNNER_COMPOSE := docker/actions-runner/docker-compose.yml
RUNNER_PROJECT := orbstack-runner
RUNNER_PLIST_TEMPLATE := docker/actions-runner/com.jacobpevans.orbstack-runner.plist.template
RUNNER_PLIST_LABEL := com.jacobpevans.orbstack-runner
RUNNER_PLIST_DEST := $(HOME)/Library/LaunchAgents/$(RUNNER_PLIST_LABEL).plist
RUNNER_LOG_DIR := $(HOME)/Library/Logs/orbstack-runner
# RUNNER_REPO_ROOT = absolute path the LaunchAgent uses to invoke `make
# runner-foreground`. Defaults to the current Makefile's worktree, so the
# LaunchAgent always points at whichever worktree installed it. After merging
# to main, re-run `make runner-install-launchagent` from the main worktree to
# repoint persistence at the canonical location.
RUNNER_REPO_ROOT ?= $(realpath $(CURDIR))
DOPPLER_RUNNER_PROJ := gh-workflow-tokens
DOPPLER_RUNNER_CONFIG := prd

runner-pull: ## Pull the pinned stock myoung34/github-runner image
	docker pull myoung34/github-runner:ubuntu-jammy

runner-kubeconfig: ## Refresh the runner's kubeconfig (rewrites 127.0.0.1 → k8s.orb.local)
	@mkdir -p $(HOME)/.config
	kubectl config view --context $(CONTEXT) --minify --raw | sed 's|127.0.0.1|k8s.orb.local|g' > $(HOME)/.config/runner-kubeconfig
	chmod 600 $(HOME)/.config/runner-kubeconfig

runner-foreground: runner-kubeconfig ## Run runner in foreground (used by LaunchAgent)
	doppler run -p $(DOPPLER_RUNNER_PROJ) -c $(DOPPLER_RUNNER_CONFIG) -- \
	  docker compose -f $(RUNNER_COMPOSE) -p $(RUNNER_PROJECT) up --abort-on-container-exit

runner-start: runner-kubeconfig ## Start runner in background (manual one-shot)
	doppler run -p $(DOPPLER_RUNNER_PROJ) -c $(DOPPLER_RUNNER_CONFIG) -- \
	  docker compose -f $(RUNNER_COMPOSE) -p $(RUNNER_PROJECT) up -d

runner-stop: ## Stop and remove the runner container
	doppler run -p $(DOPPLER_RUNNER_PROJ) -c $(DOPPLER_RUNNER_CONFIG) -- \
	  docker compose -f $(RUNNER_COMPOSE) -p $(RUNNER_PROJECT) down --remove-orphans

runner-status: ## Show runner container + GitHub registration status
	@echo "─── Container ───"
	docker ps -a --filter name=$(RUNNER_PROJECT) --format 'table {{.Names}}\t{{.Status}}\t{{.RunningFor}}'
	@echo ""
	@echo "─── GitHub Registration ───"
	gh api repos/$(GITHUB_REPO)/actions/runners --jq '.runners[] | {name, status, labels: [.labels[].name]}'

runner-logs: ## Tail runner container logs
	docker logs -f orbstack-runner

# Doctor splits into atomic sub-targets so each step uses native commands and
# Make's built-in error propagation. No embedded bash blob.
runner-doctor: runner-doctor-container runner-doctor-github runner-doctor-mounts runner-doctor-cluster runner-doctor-launchagent ## Deep health check
	@echo ""
	@echo "✓ runner-doctor: ALL CHECKS PASSED"

runner-doctor-container:
	@echo "─── Container state ───"
	docker inspect orbstack-runner --format 'state: {{.State.Status}}  restartCount: {{.RestartCount}}  exitCode: {{.State.ExitCode}}'
	docker inspect orbstack-runner --format '{{eq .State.Status "running"}}' | grep -q '^true$$'

runner-doctor-github:
	@echo "─── GitHub registration ───"
	gh api repos/$(GITHUB_REPO)/actions/runners --jq '.runners[] | [.name, .status, ([.labels[].name] | join(","))] | @tsv'
	gh api repos/$(GITHUB_REPO)/actions/runners --jq '[.runners[] | select(.status=="online")] | length' | grep -q -E '^[1-9]'

runner-doctor-mounts:
	@echo "─── Mounts inside container ───"
	docker exec orbstack-runner test -f /home/runner/.kube/config
	@echo "  kubeconfig: OK"
	docker exec orbstack-runner test -f /home/runner/.config/sops/age/keys.txt
	@echo "  SOPS age key: OK"

runner-doctor-cluster:
	@echo "─── Cluster reachability from container ───"
	docker exec orbstack-runner getent hosts k8s.orb.local
	docker exec orbstack-runner grep -q k8s.orb.local /home/runner/.kube/config
	@echo "  k8s.orb.local: resolvable + present in kubeconfig"

runner-doctor-launchagent:
	@echo "─── LaunchAgent ───"
	@launchctl print gui/$$(id -u)/$(RUNNER_PLIST_LABEL) >/dev/null 2>&1 && echo "  LaunchAgent: loaded" || echo "  WARN: LaunchAgent not installed (run: make runner-install-launchagent)"

runner-install-launchagent: ## Install macOS LaunchAgent for boot persistence (idempotent)
	@mkdir -p $(HOME)/Library/LaunchAgents $(RUNNER_LOG_DIR)
	sed -e 's|__HOME__|$(HOME)|g' -e 's|__USER__|'"$$(id -un)"'|g' -e 's|__REPO_ROOT__|$(RUNNER_REPO_ROOT)|g' $(RUNNER_PLIST_TEMPLATE) > $(RUNNER_PLIST_DEST)
	chmod 644 $(RUNNER_PLIST_DEST)
	-launchctl bootout gui/$$(id -u)/$(RUNNER_PLIST_LABEL) 2>/dev/null
	launchctl bootstrap gui/$$(id -u) $(RUNNER_PLIST_DEST)
	launchctl print gui/$$(id -u)/$(RUNNER_PLIST_LABEL) | grep -E '^\s*(state|pid|path)' || true
	@echo ""
	@echo "✓ LaunchAgent installed: $(RUNNER_PLIST_DEST)"
	@echo "  Repo root: $(RUNNER_REPO_ROOT)"
	@echo "  Logs:      $(RUNNER_LOG_DIR)/{stdout,stderr}.log"
	@echo "  Restart:   launchctl kickstart -k gui/$$(id -u)/$(RUNNER_PLIST_LABEL)"

runner-uninstall-launchagent: ## Uninstall macOS LaunchAgent
	-launchctl bootout gui/$$(id -u)/$(RUNNER_PLIST_LABEL) 2>/dev/null
	rm -f $(RUNNER_PLIST_DEST)
	@echo "✓ LaunchAgent uninstalled"
