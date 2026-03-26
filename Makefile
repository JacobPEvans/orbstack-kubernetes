.PHONY: help validate validate-schemas generate-overlay deploy deploy-doppler status logs build-images test test-e2e test-smoke test-pipeline test-forwarding test-sourcetypes test-unit test-all test-setup warmup warmup-e2e full-power power-save power-status monitoring-up monitoring-down clean runner-start runner-stop runner-status runner-logs runner-check

CONTEXT ?= orbstack
NAMESPACE := monitoring
GITHUB_REPO ?= JacobPEvans/orbstack-kubernetes
KUSTOMIZE_DIRS := k8s/monitoring k8s/sandbox
MONITORING_STATEFULSETS := otel-collector cribl-edge-managed cribl-edge-standalone cribl-stream-standalone cribl-mcp-server
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

runner-start: runner-stop ## Start the self-hosted GitHub Actions runner (community Docker image)
	@mkdir -p ~/.config
	@kubectl config view --context $(CONTEXT) --minify --raw | sed 's|127.0.0.1|k8s.orb.local|g' > ~/.config/runner-kubeconfig
	@chmod 600 ~/.config/runner-kubeconfig
	docker run -d \
	  --name actions-runner \
	  --restart=always \
	  -e REPO_URL=https://github.com/$(GITHUB_REPO) \
	  -e ACCESS_TOKEN=$$(gh auth token) \
	  -e RUNNER_NAME=orbstack-runner \
	  -e LABELS=self-hosted,Linux,ARM64 \
	  -e DEPLOY_HOME_DIR=$(HOME) \
	  -e K8S_NODEPORT_HOST=host.internal \
	  -e CLAUDE_HOME=$(HOME) \
	  -e SOPS_AGE_KEY_FILE=/home/runner/.config/sops/age/keys.txt \
	  -e KUBECONFIG=/home/runner/.kube/config \
	  -v $(HOME)/.config/sops/age:/home/runner/.config/sops/age:ro \
	  -v $(HOME)/.config/runner-kubeconfig:/home/runner/.kube/config:ro \
	  -v $(HOME)/.claude/projects:$(HOME)/.claude/projects:rw \
	  -v $(HOME)/.claude/logs:$(HOME)/.claude/logs:rw \
	  -v $(HOME)/.claude/plans:$(HOME)/.claude/plans:rw \
	  -v $(HOME)/.claude/tasks:$(HOME)/.claude/tasks:rw \
	  -v $(HOME)/.claude/teams:$(HOME)/.claude/teams:rw \
	  -v $(HOME)/.gemini:$(HOME)/.gemini:rw \
	  myoung34/github-runner:ubuntu-jammy

runner-stop: ## Stop and remove the self-hosted runner
	docker stop actions-runner 2>/dev/null || true
	docker rm actions-runner 2>/dev/null || true

runner-status: ## Show runner container and GitHub registration status
	@docker ps --filter name=actions-runner --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
	@gh api repos/$(GITHUB_REPO)/actions/runners --jq '.runners[] | {name, status, labels: [.labels[].name]}' 2>/dev/null || true

runner-logs: ## Tail runner container logs
	docker logs -f actions-runner

runner-check: ## Verify runner container has required tools and mounts
	@echo "Checking runner container tools..."
	@docker exec actions-runner python3 --version
	@docker exec actions-runner git --version
	@docker exec actions-runner make --version
	@docker exec actions-runner curl --version
	@docker exec actions-runner jq --version
	@echo "Checking mounted files..."
	@docker exec actions-runner test -f /home/runner/.kube/config && echo "  kubeconfig: OK" || { echo "  kubeconfig: MISSING"; exit 1; }
	@docker exec actions-runner test -f /home/runner/.config/sops/age/keys.txt && echo "  SOPS age key: OK" || { echo "  SOPS age key: MISSING"; exit 1; }
	@echo "All checks passed."
