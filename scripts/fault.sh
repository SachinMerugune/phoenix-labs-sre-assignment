#!/usr/bin/env bash
SCENARIO=${1:-worker-stall}

case "$SCENARIO" in
  worker-stall)
    echo "==> [FAULT 1] Injecting Worker Stall..."
    echo "    Calling POST http://localhost:3001/fault/stall"
    curl -s -X POST http://localhost:3001/fault/stall
    echo ""
    echo "==> Generating 5 new payments that will now get stuck in 'pending'..."
    for i in {1..5}; do
      curl -s -X POST http://localhost:3000/payments \
        -H "Content-Type: application/json" \
        -d '{"amount": 99.99, "currency": "EUR"}' > /dev/null
    done
    echo "==> 5 pending payments created. Watch Prometheus alert 'WorkerStalled' fire at http://localhost:9090/alerts"
    ;;
  api-down)
    echo "==> [FAULT 2] Scaling down payment-api to 0 replicas..."
    kubectl scale deployment payment-api --replicas=0
    echo "==> API is now down. Requests will fail."
    ;;
  telemetry-stop)
    echo "==> [FAULT 3] Pausing Prometheus telemetry container..."
    docker pause phoenix-prometheus
    echo "==> Prometheus paused. Metrics collection stopped."
    ;;
  *)
    echo "Usage: $0 {worker-stall|api-down|telemetry-stop}"
    exit 1
    ;;
esac
