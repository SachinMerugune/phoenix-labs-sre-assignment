#!/usr/bin/env bash
SCENARIO=${1:-worker-stall}

case "$SCENARIO" in
  worker-stall)
    echo "==> [RECOVERY 1] Resuming worker processing..."
    curl -s -X POST http://localhost:3001/fault/resume
    echo ""
    echo "==> Waiting 5s for worker to drain stuck pending queue..."
    sleep 5
    echo "==> Verifying zero pending payments remain:"
    kubectl exec deployment/postgres -- psql -U postgres -d payments_db -c "SELECT status, count(*) FROM payments GROUP BY status;"
    ;;
  api-down)
    echo "==> [RECOVERY 2] Scaling payment-api back to 1 replica..."
    kubectl scale deployment payment-api --replicas=1
    kubectl rollout status deployment payment-api
    echo "==> API restored!"
    ;;
  telemetry-stop)
    echo "==> [RECOVERY 3] Unpausing Prometheus container..."
    docker unpause phoenix-prometheus
    echo "==> Telemetry collection resumed!"
    ;;
  *)
    echo "Usage: $0 {worker-stall|api-down|telemetry-stop}"
    exit 1
    ;;
esac
