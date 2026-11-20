# Phoenix Labs — Site Reliability Engineer Assignment

A production-ready, local Kubernetes deployment of a high-integrity Payment & CRM processing system with full observability, SLO monitoring, automated fault injection, and zero-duplicate recovery guarantees.

> 🎥 **Video Walkthrough (Loom):** [Watch the Full Demonstration on Loom](https://www.loom.com/share/3b7bce175d8c409e875203cf97dae55c)

---

## 🏛️ Architecture Overview

```text
               +-------------------------------------------------------+
               |                  Local Kind Cluster                   |
               |                                                       |
[Client/Curl] ---> [ payment-api-service ] (:30000 -> :3000)           |
               |             |                                         |
               |      (Insert payment)                                 |
               |             v                                         |
               |      [ PostgreSQL ] (:5432) <---+                     |
               |      (status: pending)          |                     |
               |                                 | (Poll & Update)     |
               |                        [ payment-worker ]             |
               |                        (CRM hand-off simulation)      |
               |                                 |                     |
               +---------------------------------|---------------------+
                                                 |
                       Telemetry & Metrics       |
                                                 v
                       +-----------------------------------+
                       |         Monitoring Stack          |
                       |  Prometheus (:9090)               |
                       |  Grafana    (:3002)               |
                       +-----------------------------------+
```

### Components
1. **Payment API (`app/api/`)**: TypeScript / Express REST API handling payment ingestion (`POST /payments`), status lookup (`GET /payments/:id`), health checks (`GET /health`), and Prometheus metrics (`GET /metrics`).
2. **Background Worker (`app/worker/`)**: TypeScript daemon that polls for `pending` payments using `FOR UPDATE SKIP LOCKED` for strict idempotency, simulates external CRM integration, updates payment state to `completed`, and exposes metrics on port `3001`.
3. **Database (`app/db/`)**: PostgreSQL 16 Alpine with indexed payment schema (`id`, `amount`, `currency`, `status`, `created_at`, `updated_at`).
4. **Helm Chart (`helm/payment-system/`)**: Production-style Helm package with decoupled secrets, non-root security contexts, and liveness/readiness probes.
5. **Monitoring (`monitoring/`)**: Prometheus and Grafana pre-provisioned to monitor service golden signals, calculate SLOs, and fire alerts on anomalous behavior.

---

## ⚡ Quickstart

### Prerequisites
- Docker Desktop (with WSL2 backend enabled)
- `kind`
- `kubectl`
- `helm`

### Single-Command Workflow
All operations are fully codified in the root `Makefile`:

```bash
# 1. Verify environment and prerequisites
make preflight

# 2. Spin up kind cluster, deploy Helm release, and launch monitoring
make up

# 3. Generate test traffic (creates 10 payments)
make seed

# 4. Validate system health and component connectivity
make verify

# 5. Inject Worker Stall failure test
make fault

# 6. Recover worker and drain stuck queue with zero data loss
make recover

# 7. Clean teardown of all resources
make down
```

---

## 📊 Service Level Objectives (SLOs) & Prometheus Rules

| SLO Objective | Target | PromQL Query | Alert Name |
| :--- | :--- | :--- | :--- |
| **API Availability** | ≥ 99.0% over 5m | `sum(rate(http_requests_total{status_code=~"2.."}[5m])) / sum(rate(http_requests_total[5m]))` | `HighErrorRate` |
| **API Latency (P95)** | ≤ 500ms | `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))` | `HighLatency` |
| **Business SLO** | 100% payments processed in < 120s | Tracked via pending queue gauge and `payment_processing_duration_seconds` | `WorkerStalled` |
| **Telemetry Health** | Scrape target active | `up == 0` | `TelemetryMissing` |

Access Dashboards:
- **Prometheus**: `http://localhost:9090` (Alerts at `http://localhost:9090/alerts`)
- **Grafana**: `http://localhost:3002` (User: `admin`, Password: `admin`)

---

## 🧪 Failure Scenario Demonstrations

### Scenario 1: Worker Stalled (Silent Failure)
- **Failure Mode**: The worker process remains alive and its HTTP `/health` probe returns `200 OK`, but background loop execution is stalled.
- **Trigger**: Run `./scripts/fault.sh worker-stall` (or `make fault`).
- **Symptom**: New payments accumulate in `pending` status.
- **Alert**: `WorkerStalled` fires in Prometheus after 30 seconds (`payments_pending_count > 0 and rate(payments_processed_total[1m]) == 0`).
- **Recovery**: Run `./scripts/recover.sh worker-stall` (or `make recover`). Worker resumes, drains the backlog, and marks all records `completed`. Row locking prevents duplicate processing.

### Scenario 2: API Pod Failure
- **Trigger**: `./scripts/fault.sh api-down` (Scales deployment to 0).
- **Recovery**: `./scripts/recover.sh api-down` (Restores deployment to 1).

### Scenario 3: Telemetry Pipeline Outage
- **Trigger**: `./scripts/fault.sh telemetry-stop` (Pauses Prometheus container).
- **Recovery**: `./scripts/recover.sh telemetry-stop`.

---

## 🔒 Security & Hardening Guardrails

1. **Non-Root Containers**: Containers run under dedicated non-privileged user `appuser` (UID `1000`) and enforce `securityContext.runAsNonRoot: true`.
2. **Runtime Secrets Management**: Database passwords and credentials are separated into Kubernetes `Secret` resources rather than plaintext environment variables.
3. **Scoped Resource Quotas**: Both API and Worker specify CPU/Memory `requests` (100m / 128Mi) and `limits` (250m / 256Mi) to prevent noisy neighbor and OOM cascades.
4. **PII Sanitization**: Logs exclude card details or sensitive payload bodies; only masked IDs and business metadata are output.

---

## ☁️ AWS Production Migration Architecture

To scale this local architecture to an enterprise AWS environment:

1. **Compute (Amazon EKS)**:
   - Deploy API and Worker workloads onto managed node groups (with Karpenter for autoscaling).
   - Ingress via AWS Load Balancer Controller (ALB) terminating TLS with ACM certificates.
2. **Database (Amazon RDS for PostgreSQL Multi-AZ)**:
   - Replace in-cluster container with Amazon RDS PostgreSQL Multi-AZ for automatic failover, read replicas, and automated point-in-time recovery.
3. **Decoupled Messaging (Amazon SQS)**:
   - Replace polling mechanism with an Amazon SQS FIFO queue to guarantee ordered, exactly-once delivery and scale worker pods dynamically based on queue depth metrics.
4. **Secrets & Security**:
   - AWS Secrets Manager with External Secrets Operator (ESO) syncing credentials directly into EKS pods.
   - IAM Roles for Service Accounts (IRSA) for least-privilege pod access.
5. **Infrastructure as Code (IaC)**:
   - Modular Terraform using Terraform Cloud or S3/DynamoDB remote state backend.
6. **Managed Observability**:
   - Amazon Managed Service for Prometheus (AMP) and Amazon Managed Grafana (AMG) with AWS OpenTelemetry Distro (ADOT).

---

## 🤖 AI Tooling Disclosure & Verification Methodology

In alignment with Phoenix Labs' transparency guidelines:
- **AI Tools Used**: Antigravity AI assistant for scaffolding templates, syntax generation, and documentation drafting.
- **Verification Methodology**:
  - Every command, script, and container build was executed and verified live on a Windows WSL2/Docker engine.
  - End-to-end tests were performed via curl and PostgreSQL queries confirming record transition from `pending` to `completed`.
  - The worker stall failure test was physically executed, validated in PostgreSQL, and confirmed recovered with zero record duplication.

---

## 🎥 Loom Video Walkthrough
- **Loom URL**: [https://www.loom.com/share/3b7bce175d8c409e875203cf97dae55c](https://www.loom.com/share/3b7bce175d8c409e875203cf97dae55c)
- **Contents**:
  1. Repository architecture walkthrough
  2. Live `make up` and cluster inspection
  3. Real-time payment creation and worker hand-off
  4. Fault injection demonstration (`make fault`) & Prometheus alert firing
  5. Recovery demonstration (`make recover`) & database integrity verification
  6. Live code change & graceful reload
