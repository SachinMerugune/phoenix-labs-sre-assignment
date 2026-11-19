#!/usr/bin/env bash
set -e

echo "==> Creating kind cluster 'phoenix-sre'..."
kind create cluster --config scripts/kind-config.yaml

echo "==> Loading local Docker images into kind..."
kind load docker-image phoenix-api:v1.0.0 --name phoenix-sre
kind load docker-image phoenix-worker:v1.0.0 --name phoenix-sre

echo "==> Cluster ready and images loaded!"
kubectl cluster-info
