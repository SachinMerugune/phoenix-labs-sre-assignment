#!/usr/bin/env bash
kubectl exec deployment/postgres -- psql -U postgres -d payments_db -c "SELECT status, count(*) FROM payments GROUP BY status;"
