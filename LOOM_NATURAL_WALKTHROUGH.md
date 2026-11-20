# Sachin's Natural Video Walkthrough Guide (Simple & Clear English)

This guide is written in **your own natural voice and speaking style**. 
No complex English, no heavy grammar, and no artificial corporate words. Just simple, clear, and confident technical explanations.

For every single part, you have:
1. **[SCREEN ACTION]**: What window to open and where to point your mouse cursor.
2. **[WHAT TO SAY]**: The exact simple words to say naturally.

---

## 🕒 Video Roadmap (Total: ~20 Minutes)
* **Part 1 (0:00 – 4:00):** Introduction & Why we built it this way (VS Code `README.md`)
* **Part 2 (4:00 – 8:00):** Kubernetes, Helm & Security (Terminal & Helm files)
* **Part 3 (8:00 – 12:00):** Live Traffic, Prometheus & SLOs (Terminal & Browser)
* **Part 4 (12:00 – 17:00):** The Main Test: Silent Worker Stall & Recovery (Terminal & Prometheus)
* **Part 5 (17:00 – 20:00):** Live Change & AWS Cloud Plan (VS Code & Terminal)

---

# PART 1: Introduction & Architecture (0:00 – 4:00)

### 🖥️ [SCREEN ACTION]
1. Open **VS Code**.
2. Open `README.md`.
3. Scroll to the diagram under **Architecture Overview**.
4. **Point your mouse cursor** at the diagram: first point to `payment-api`, then to `PostgreSQL`, then to `payment-worker`.

### 🎙️ [WHAT TO SAY]
> *"Hi Rohan and the Phoenix Labs team. My name is Sachin Kumar. Today, I am going to walk you through my implementation of the Site Reliability Engineer assignment.*
>
> *Before running any commands, let me first explain the architecture and why I designed it this way.*
>
> *(Point mouse at the diagram in README.md)*
>
> *In any real payment system, when a customer pays money, we should never make them wait on the screen while our system talks to external tools like CRM, accounting, or email.*
> *If the CRM is slow or down, the user's screen will freeze, or they might get an error, even though their payment was already done.*
>
> *To solve this, I separated the system into two parts:*
> 1. *First, we have the **Payment API** (point mouse to `payment-api`). When the user pays, the API saves the payment into our PostgreSQL database with status `pending`. And in just a few milliseconds, it sends back a response saying 'Payment received'. The user doesn't have to wait.*
> 2. *Second, we have a **Background Worker** (point mouse to `payment-worker`). This worker runs in the background. It checks the database, picks up the `pending` payments, updates the CRM, and changes the status to `completed`.*
> 3. *Third, we have our **Observability stack** (point mouse to Prometheus/Grafana box) using Prometheus and Grafana to watch everything and alert us if anything gets stuck.*
>
> *(Point mouse to the folder explorer on the left side of VS Code)*
>
> *Here in the project structure, you can see:*
> - *`app/` has our API and Worker code written in TypeScript.*
> - *`helm/` has our Helm chart to deploy everything to Kubernetes.*
> - *`monitoring/` has Prometheus and Grafana configuration.*
> - *`scripts/` has our automation scripts to test traffic and test failures.*
> - *And `Makefile` lets us run everything with simple commands like `make up` and `make fault`."*

---

# PART 2: Kubernetes Deployment & Security (4:00 – 8:00)

### 🖥️ [SCREEN ACTION]
1. Open your **Git Bash terminal**.
2. Type and run: `make preflight`
3. Type and run: `kubectl get pods`
4. Now switch to **VS Code**, open `helm/payment-system/templates/deployment-api.yaml`.
5. **Point your mouse cursor** to lines 17–19 (`securityContext: runAsNonRoot: true`).
6. **Point your mouse cursor** to lines 30–35 (`resources: limits and requests`).

### 🎙️ [WHAT TO SAY]
> *"Now, let's look at how this is deployed on Kubernetes.*
>
> *(Switch to Terminal)*
>
> *I used `kind`, which is Kubernetes in Docker. This allows us to run a real Kubernetes cluster locally on our laptop without spending any cloud money.*
>
> *First, I run `make preflight` (point to terminal output). This checks that Docker, kind, kubectl, and Helm are all installed and ready.*
>
> *Now if I run `kubectl get pods` (point to the 3 pods):*
> *You can see all three pods are running:*
> - *`payment-api`*
> - *`payment-worker`*
> - *and `postgres`*
>
> *(Switch to VS Code, show `deployment-api.yaml`)*
>
> *Instead of writing raw YAML files, I used **Helm**. Helm packages everything cleanly, so we can manage versions and deploy with one command.*
>
> *Also, I applied production security rules here:*
> 1. *(Point mouse to `runAsNonRoot: true`)*: *Our containers do NOT run as root. Both the Dockerfile and Helm templates enforce running as an unprivileged user called `appuser`. This is important because if an attacker hacks the app, they cannot get root control.*
> 2. *Second, database passwords are not hardcoded. They are stored inside Kubernetes Secrets.*
> 3. *(Point mouse to `resources`)*: *We set CPU and memory limits and requests. This ensures no single container can eat all the laptop's memory and crash other pods.*
> 4. *And we have health checks (`/health`) so Kubernetes knows when the pod is healthy and ready to take traffic."*

---

# PART 3: Live Traffic, Prometheus & SLOs (8:00 – 12:00)

### 🖥️ [SCREEN ACTION]
1. Open your **Browser**.
2. Open tab: `http://localhost:9090` (Prometheus).
3. Click on top menu: **Status ➔ Targets**.
4. **Point your mouse cursor** to the two blue **`UP`** badges for `payment-api` and `payment-worker`.
5. Switch to **Git Bash terminal** and run: `./scripts/seed.sh 5`
6. Show the 5 payments being created and then showing status `completed`.
7. Switch back to **VS Code** and open `README.md` at the **SLO table**.

### 🎙️ [WHAT TO SAY]
> *"Now let's look at monitoring and how we track our Service Level Objectives, or SLOs.*
>
> *(Switch to Browser, show Prometheus Targets page)*
>
> *Here in Prometheus at `localhost:9090`, under Status -> Targets, you can see Prometheus is actively scraping both of our services:*
> - *`payment-api` on port 3000 is **UP** (point mouse).*
> - *`payment-worker` on port 3001 is **UP** (point mouse).*
>
> *Now let's generate some real traffic to see how the system handles it.*
>
> *(Switch to Terminal, run `./scripts/seed.sh 5`)*
>
> *I run `./scripts/seed.sh 5`. This script sends 5 payment requests to our API.*
> *(Point mouse at the terminal as it prints):*
> *You can see payment 1, 2, 3, 4, 5 are created with status `pending`. Then the worker picks them up, and within 2 seconds, all 5 payments become `completed` in PostgreSQL.*
>
> *(Switch to VS Code, show SLO table in README.md)*
>
> *For this project, we defined three important SLOs:*
> 1. *(Point to SLO 1)*: ***API Availability (99%)**: Over 99% of user requests must return a successful response, not a 500 error.*
> 2. *(Point to SLO 2)*: ***API Latency (P95 under 500 milliseconds)**: 95% of our users should get a response in under half a second. We look at P95 instead of average because average hides the slow requests.*
> 3. *(Point to SLO 3)*: ***Business SLO (Payments completed within 120 seconds)**: As an SRE, we also care about the business. When a user pays, the background CRM update must complete in under 120 seconds. If payments stay stuck in `pending` longer than that, it means our worker is failing, and an alert must fire."*

---

# PART 4: The Main Test — Silent Worker Stall & Recovery (12:00 – 17:00)

### 🖥️ [SCREEN ACTION]
1. Open **Browser** tab: `http://localhost:9090/alerts`.
2. **Point your mouse cursor** to `WorkerStalled` (show it is green / inactive).
3. Switch to **Git Bash terminal** and run:
   ```bash
   ./scripts/fault.sh worker-stall
   ```
4. In terminal, run the postgres check:
   ```bash
   kubectl exec deployment/postgres -- psql -U postgres -d payments_db -c "SELECT status, count(*) FROM payments GROUP BY status;"
   ```
   **Point your mouse** to the output showing `pending | 5`.
5. Switch to **Browser** (`http://localhost:9090/alerts`) and refresh.
   **Point your mouse** to `WorkerStalled` turning red / **`FIRING`**!
6. Switch back to **Terminal** and run:
   ```bash
   ./scripts/recover.sh worker-stall
   ```
7. Run the postgres check again:
   **Point your mouse** to the output showing all payments `completed` and `0` pending.

### 🎙️ [WHAT TO SAY]
> *"Now, I want to show you the most important test in this whole assignment: **The Silent Worker Stall**.*
>
> *In production, if a pod crashes, it is easy to see because Kubernetes shows an error. But the most dangerous bug is a **Silent Failure**—where the container is still running, the CPU looks normal, and `/health` returns 200 OK, but inside, the worker loop is stuck or frozen.*
>
> *Let's test this right now.*
>
> *(Switch to Browser, show Prometheus Alerts page)*
> *Here under alerts, our `WorkerStalled` alert is currently green and quiet.*
>
> *(Switch to Terminal, run `./scripts/fault.sh worker-stall`)*
> *Now, I run `./scripts/fault.sh worker-stall`.*
> *This tells the worker to stop processing, and then it creates 5 new payments.*
>
> *(Run postgres query in terminal)*
> *(Point mouse at output)*: *Look here in PostgreSQL. We have 5 payments stuck in `pending`. The worker is not touching them.*
>
> *(Switch to Browser, refresh alerts page)*
> *(Point mouse at `WorkerStalled`)*:
> *Now look at Prometheus! Within 30 seconds, our alert detected that pending payments exist, but the completed rate is zero. The alert is now **FIRING**!*
>
> *(Switch to Terminal, run `./scripts/recover.sh worker-stall`)*
> *Now let's recover the system. I run `./scripts/recover.sh worker-stall`.*
> *This resumes the worker.*
>
> *(Run postgres query again in terminal)*
> *(Point mouse at output)*:
> *Look at the database now! All 5 stuck payments were immediately processed and changed to `completed`. There are zero pending payments left.*
>
> *And very importantly: because our worker uses SQL `FOR UPDATE SKIP LOCKED`, no payment was processed twice. This guarantees **zero duplicate charges**."*

---

# PART 5: Live Change & AWS Cloud Plan (17:00 – 20:00)

### 🖥️ [SCREEN ACTION]
1. Open **VS Code**, open `helm/payment-system/values.yaml`.
2. **Point your mouse cursor** to line 28 (`worker: service:` or `replicaCount: 1`).
3. Under `worker:`, change `replicaCount` or show `values.yaml`.
4. Switch to **Git Bash terminal** and run:
   ```bash
   kubectl scale deployment payment-worker --replicas=2
   kubectl get pods
   ```
   **Point your mouse** to the two running `payment-worker` pods!
5. Switch to **VS Code**, open `README.md`, and scroll down to **AWS Production Migration Architecture**.
6. **Point your mouse cursor** at each of the bullet points as you speak.

### 🎙️ [WHAT TO SAY]
> *"As requested in the assignment, here is a quick live change.*
>
> *Suppose our business grows and we need more workers to process payments faster.*
> *(In terminal, run `kubectl scale deployment payment-worker --replicas=2` and `kubectl get pods`)*
> *(Point mouse at terminal)*: *You can see Kubernetes immediately started a second worker pod with zero downtime. Because of our row-level database locking, both workers can now process payments side by side without any conflict.*
>
> *(Switch to VS Code, show AWS section in README.md)*
>
> *Finally, how do we take this from my laptop to a real production environment on **AWS**?*
>
> *(Point mouse at each item as you mention it)*:
> 1. ***Compute**: In production, instead of local kind, we will use **Amazon EKS**. We will use Karpenter to automatically add and remove worker nodes, and an AWS Application Load Balancer with ACM for HTTPS security.*
> 2. ***Database**: Instead of a container in Kubernetes, we will use **Amazon RDS PostgreSQL with Multi-AZ**. This gives us automated daily backups and instant failover if one data center goes down.*
> 3. ***Queueing**: Instead of workers polling the database directly, we can put **Amazon SQS FIFO** in between. The API puts payment messages into SQS, and workers scale up or down based on how many messages are in the queue.*
> 4. ***Security & IaC**: All infrastructure will be written using **Terraform** with state stored safely in S3. Pods will access AWS using IAM Roles for Service Accounts (IRSA), so no passwords need to be saved in files.*
> 5. ***Monitoring**: We can use **Amazon Managed Prometheus** and **Managed Grafana** for our dashboards and alerts.*
>
> *To wrap up: We built a clean, decoupled payment system, deployed it safely on Kubernetes with Helm, proved that our monitoring catches silent failures, and showed how to scale it to AWS production.*
>
> *Thank you very much, Rohan and the Phoenix Labs team, for your time. I look forward to speaking with the Tech Lead in the next round!"*

---

### 💡 Tips for Sachin while recording:
1. Don't rush! Speak slowly. Pauses between sentences sound confident.
2. If you make a small slip-up, don't restart the video! Just say: *"Sorry, let me rephrase that..."* and continue. Hiring managers love authenticity.
3. Keep this file open on your second monitor or on your phone so you can glance at it while recording.
