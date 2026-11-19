#!/usr/bin/env bash
set -e

echo "=============================================="
echo " Phoenix Labs SRE System Verification "
echo "=============================================="

echo -n "1. Checking Payment API /health... "
API_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)
if [ "$API_HEALTH" -eq 200 ]; then
  echo "✅ OK (200)"
else
  echo "❌ FAIL ($API_HEALTH)"
fi

echo -n "2. Checking Worker /health... "
WORKER_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health)
if [ "$WORKER_HEALTH" -eq 200 ]; then
  echo "✅ OK (200)"
else
  echo "❌ FAIL ($WORKER_HEALTH)"
fi

echo -n "3. Checking Prometheus targets... "
PROM_UP=$(curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"up"' | wc -l)
echo "✅ Active healthy targets: $PROM_UP"

echo "4. Checking Kubernetes Pods status:"
kubectl get pods

echo "5. Current Database Payment Counts:"
kubectl exec deployment/postgres -- psql -U postgres -d payments_db -c "SELECT status, count(*) FROM payments GROUP BY status;"
