# Phoenix Labs SRE Assignment — 20-Minute Loom Walkthrough Script

This script gives you an exact, minute-by-minute speaking guide and screen action plan. You can keep this open on one side of your screen while recording.

---

## ⏱️ Video Outline (Target: 20–22 Minutes)

| Timeline | Topic | Screen To Show | What You Are Demonstrating |
| :--- | :--- | :--- | :--- |
| **0:00 – 3:30** | Introduction & Architecture | VS Code / GitHub `README.md` | Problem statement, decoupling, repo structure |
| **3:30 – 7:30** | Cluster & Deployment | Terminal & Helm Templates | `make preflight`, `make up`, K8s pods, non-root security |
| **7:30 – 12:00** | Traffic & Observability | Terminal & Browser (Prometheus/Grafana) | `make seed`, live metrics, 3 SLOs explained |
| **12:00 – 17:30** | **Chaos Test: Silent Worker Stall** | Terminal & Prometheus Alerts | `make fault`, `WorkerStalled` alert firing, `make recover` |
| **17:30 – 20:00** | Live Code Change | VS Code & Terminal | Modifying worker config and live reload |
| **20:00 – 22:00** | AWS Production Plan & Conclusion | `README.md` (AWS section) | EKS, RDS Multi-AZ, SQS, Terraform, Wrap-up |

---

## 🎬 Section-by-Section Script & Actions

### Part 1: Introduction & Architecture (0:00 – 3:30)
**On Screen:** Show `README.md` in VS Code or GitHub with the Architecture diagram visible.

**What to Say:**
> *"Hi Rohan and the Phoenix Labs team. My name is Sachin Kumar, and in this video, I will walk you through my complete implementation of the Site Reliability Engineer take-home assignment.*
>
> *Before jumping into the commands, let's look at the core architecture and why it's designed this way.*
>
> *In any high-scale e-commerce or health-tech payment pipeline, decoupling is critical. If your customer-facing API attempts to synchronize with an external CRM or accounting service within the same synchronous HTTP request, any third-party latency or downtime immediately degrades the customer checkout experience.*
>
> *To solve this, I designed a decoupled, asynchronous pipeline with three core components:*
> 1. *First, the **Payment API** in `app/api/`: It accepts payment requests (`POST /payments`), validates them, stores them in PostgreSQL with a `pending` state, and returns immediately in under 50 milliseconds.*
> 2. *Second, a dedicated **Background Worker** in `app/worker/`: It polls the database, consumes pending transactions using row-level locking (`FOR UPDATE SKIP LOCKED`) for strict idempotency, simulates the CRM hand-off, and transitions the state to `completed`.*
> 3. *Third, an **Observability Stack** running Prometheus and Grafana, monitoring RED metrics, service health, and three defined SLOs.*
>
> *Everything is containerized, packaged with a custom Helm chart, and managed via a unified `Makefile` for one-click reproducibility."*

---

### Part 2: Deployment & Security Hardening (3:30 – 7:30)
**On Screen:** Switch to your Git Bash / Terminal.

**Actions to Do:**
1. Show the root files: `ls -la`
2. Run: `make preflight`
3. Run: `kubectl get pods`

**What to Say:**
> *"Let's look at the deployment. The entire lifecycle is codified in the root `Makefile`.*
>
> *Running `make preflight` verifies that all required tools—Docker, kind, kubectl, and Helm—are present on the system.*
>
> *To deploy the system, we run `make up`. This provisions a local `kind` Kubernetes cluster with pre-configured port mappings (`hostPort 3000` for the API and `3001` for the worker), builds the multi-stage Docker images, and deploys the `payment-system` Helm chart.*
>
> *As you can see with `kubectl get pods`, we have three healthy pods running: `payment-api`, `payment-worker`, and `postgres`.*
>
> *From a security standpoint, we adhered strictly to production hardening:*
> - *First, neither container runs as root. Both Dockerfiles and the Helm deployment enforce `runAsNonRoot: true` with a dedicated unprivileged user (`appuser`, UID 1000).*
> - *Second, database credentials and the connection string are injected dynamically from a Kubernetes `Secret` rather than being hardcoded in plaintext.*
> - *Third, all pods specify explicit CPU and memory resource requests and limits to prevent noisy neighbor starvation."*

---

### Part 3: Live Traffic, Metrics & SLOs (7:30 – 12:00)
**On Screen:** Open your browser with:
- Prometheus: `http://localhost:9090` (show **Status -> Targets**)
- Grafana: `http://localhost:3002`

**Actions to Do:**
1. Show both `payment-api` and `payment-worker` targets are **UP** in Prometheus.
2. In terminal, run: `make seed`
3. Show the database summary showing payments created and completed.

**What to Say:**
> *"Now let's examine observability and telemetry.*
>
> *In Prometheus at `localhost:9090`, we can see our scrape targets are actively collecting metrics from both the API on port 3000 and the Worker on port 3001.*
>
> *Let's generate live traffic using `make seed`.*
>
> [Run `make seed` in terminal]
>
> *This script submits a batch of payments to `POST /payments`. As they are submitted, you can see the API immediately acknowledges them, and within a few seconds, the worker picks them up and marks them completed in Postgres.*
>
> *Based on the assignment requirements, we track three Service Level Objectives (SLOs):*
> 1. ***API Availability SLO (≥ 99%)**: Measured via `sum(rate(http_requests_total{status_code=~"2.."}[5m])) / sum(rate(http_requests_total[5m]))`. If 5xx errors exceed 1%, an alert fires.*
> 2. ***API Latency SLO (P95 ≤ 500ms)**: Tracked via histogram quantiles of `http_request_duration_seconds_bucket`.*
> 3. ***Business SLO (100% payments processed in < 120s)**: We export a gauge `payments_pending_count` and monitor processing duration. If payments remain in pending status without active processing, it indicates a breach of our business agreement."*

---

### Part 4: Chaos Engineering — Silent Worker Stall (12:00 – 17:30)
**On Screen:** Split screen or switch between Terminal and Prometheus Alerts (`http://localhost:9090/alerts`).

**Actions to Do:**
1. Show Prometheus alert `WorkerStalled` is green/inactive.
2. In terminal, run: `make fault`
3. Check Postgres: `kubectl exec deployment/postgres -- psql -U postgres -d payments_db -c "SELECT status, count(*) FROM payments GROUP BY status;"`
   *(Show that pending payments are stuck).*
4. In Prometheus (`http://localhost:9090/alerts`), refresh and show `WorkerStalled` transition from Pending to **Firing**!
5. In terminal, run: `make recover`
6. Check Postgres again: all pending payments are drained and completed!

**What to Say:**
> *"Now let's demonstrate the most critical test in this assignment: **Failure Scenario 1 — The Silent Worker Stall**.*
>
> *In production, the hardest failures to detect are not outright pod crashes, but silent stalls—where the container is still running, its HTTP `/health` probe returns 200 OK, but internal processing has deadlocked or frozen.*
>
> *Let's inject this fault by running `make fault`.*
>
> [Run `make fault`]
>
> *What happened here? The script triggered our internal fault hook on the worker. The worker process is still up, but it has stopped draining payments. The script generated 5 new payments.*
>
> *If we query PostgreSQL, you can see these 5 payments are stuck in `pending` status.*
>
> *Now let's switch to Prometheus at `http://localhost:9090/alerts`. Notice our custom alert `WorkerStalled`.*
> *The alert expression detects that `payments_pending_count > 0` while the processing rate equals 0. Within 30 seconds, it transitions to **FIRING**.*
>
> *Now let's demonstrate recovery by running `make recover`.*
>
> [Run `make recover`]
>
> *The worker resumes processing. It immediately drains the accumulated backlog. Checking the database again, all records have cleanly transitioned to `completed`.*
>
> *Crucially, because the worker uses `SELECT ... FOR UPDATE SKIP LOCKED` inside a database transaction, zero payments were processed twice or corrupted. This proves strict idempotency."*

---

### Part 5: Live Code Change & AWS Production Plan (17:30 – 22:00)
**On Screen:** VS Code showing `app/worker/index.ts`, then switch to `README.md` (AWS section).

**Actions to Do:**
1. Open `app/worker/index.ts`.
2. Briefly highlight line 10 (`pollIntervalMs`) or the log message, make a quick tweak (e.g., change log message or poll interval from 2000 to 1500), save.
3. Switch to `README.md` and scroll to **AWS Production Migration Architecture**.

**What to Say:**
> *"As requested in the assignment, here is a quick live code change.*
> *In `app/worker/index.ts`, we have our configurable polling interval and batch parameters. We can tune `pollIntervalMs` or adjust batch sizes dynamically, and redeploy seamlessly via Helm with `helm upgrade`.*
>
> *Finally, let's discuss how this local design scales to **Production AWS Architecture**:*
> 1. ***Compute**: In production, we migrate from local `kind` to **Amazon EKS**, utilizing managed node groups with Karpenter for just-in-time autoscaling, fronted by an AWS Application Load Balancer (ALB) with AWS Certificate Manager for TLS.*
> 2. ***Database**: We replace the in-cluster PostgreSQL container with **Amazon RDS for PostgreSQL Multi-AZ**, giving us automated failover, automated snapshots, and read replicas.*
> 3. ***Asynchronous Decoupling**: Rather than database polling, we introduce **Amazon SQS (FIFO)** between the API and Worker. The API publishes payment events to SQS, and workers scale dynamically based on CloudWatch `ApproximateNumberOfMessagesVisible`.*
> 4. ***Security & IaC**: All infrastructure is provisioned using modular **Terraform** with remote state locking in S3 and DynamoDB. Secrets are managed via **AWS Secrets Manager** and synced to pods via the External Secrets Operator.*
> 5. ***Observability**: In AWS, metrics feed into **Amazon Managed Service for Prometheus (AMP)** and **Amazon Managed Grafana (AMG)** using AWS Distro for OpenTelemetry (ADOT).*
>
> *Thank you for reviewing my assignment. All code, configuration, scripts, and documentation are available in the GitHub repository. I look forward to discussing this in detail with the Tech Lead in the next round."*

---

## 🏁 Post-Recording Submission Steps
1. Upload video to Loom and copy the shareable link.
2. Edit `README.md` line 149 and paste your Loom URL.
3. Push to GitHub:
   ```bash
   git add README.md
   git commit -m "docs: add Loom video walkthrough link"
   git push origin main
   ```
4. Email `rohan@phoenixlabs.cloud`:
   - Subject: `Site Reliability Engineer Assignment Submission — Sachin Kumar`
   - Include: GitHub repository link + Loom video link.
