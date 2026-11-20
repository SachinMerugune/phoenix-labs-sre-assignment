.PHONY: preflight up seed verify fault recover down clean status

SHELL := /usr/bin/env bash

preflight: ## Check required CLI tools (docker, kind, kubectl, helm)
	@echo "==> Running preflight checks..."
	@command -v docker >/dev/null 2>&1 || { echo "❌ docker not found"; exit 1; }
	@command -v kind >/dev/null 2>&1 || { echo "❌ kind not found"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found"; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "❌ helm not found"; exit 1; }
	@echo "✅ All required CLI tools are installed and available!"

up: preflight ## Provision kind cluster, build/load images, deploy Helm chart, and start monitoring
	@echo "==> [UP] Setting up kind cluster and loading images..."
	@kind get clusters | grep -q "phoenix-sre" || ./scripts/kind-create.sh
	@echo "==> [UP] Deploying payment system via Helm..."
	@helm upgrade --install payment-system ./helm/payment-system
	@echo "==> [UP] Starting monitoring stack (Prometheus & Grafana)..."
	@docker compose -f monitoring/docker-compose.yml up -d
	@echo "==> [UP] Waiting for pods to become ready..."
	@kubectl wait --for=condition=ready pod -l app=payment-api --timeout=60s
	@kubectl wait --for=condition=ready pod -l app=payment-worker --timeout=60s
	@kubectl wait --for=condition=ready pod -l app=postgres --timeout=60s
	@echo "==> System successfully launched!"
	@echo "    - API:        http://localhost:3000"
	@echo "    - Worker:     http://localhost:3001"
	@echo "    - Prometheus: http://localhost:9090"
	@echo "    - Grafana:    http://localhost:3002 (admin/admin)"

seed: ## Generate test payments
	@./scripts/seed.sh 10

verify: ## Run health checks and print summary
	@./scripts/verify.sh

fault: ## Inject worker stall failure scenario
	@./scripts/fault.sh worker-stall

recover: ## Recover from worker stall failure scenario
	@./scripts/recover.sh worker-stall

status: ## Query current payment counts in database
	@kubectl exec deployment/postgres -- psql -U postgres -d payments_db -c "SELECT status, count(*) FROM payments GROUP BY status;"

down: ## Teardown all resources (helm, cluster, monitoring)
	@echo "==> [DOWN] Tearing down monitoring stack..."
	@docker compose -f monitoring/docker-compose.yml down -v || true
	@echo "==> [DOWN] Uninstalling Helm chart..."
	@helm uninstall payment-system || true
	@echo "==> [DOWN] Deleting kind cluster..."
	@kind delete cluster --name phoenix-sre || true
	@echo "==> Environment destroyed cleanly."
