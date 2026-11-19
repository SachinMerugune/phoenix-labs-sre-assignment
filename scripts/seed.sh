#!/usr/bin/env bash
set -e

COUNT=${1:-10}
echo "==> Generating $COUNT payments via API (http://localhost:3000/payments)..."

for i in $(seq 1 $COUNT); do
  AMOUNT=$(awk -v min=10 -v max=500 'BEGIN{srand(); printf "%.2f", min+rand()*(max-min)}')
  RES=$(curl -s -X POST http://localhost:3000/payments \
    -H "Content-Type: application/json" \
    -d "{\"amount\": $AMOUNT, \"currency\": \"EUR\"}")
  
  ID=$(echo $RES | grep -o '"id":[^,]*' | cut -d':' -f2 | tr -d ' ')
  echo "[$i/$COUNT] Created payment ID: $ID (Amount: €$AMOUNT)"
  sleep 0.2
done

echo ""
echo "==> All $COUNT payments submitted. Waiting 5s for worker to complete them..."
sleep 5

echo "==> Summary of payments in database:"
kubectl exec deployment/postgres -- psql -U postgres -d payments_db -c "SELECT status, COUNT(*) FROM payments GROUP BY status;"
