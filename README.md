# Junkan Vertical Spike Demo

This repository is a self-contained demonstration of **Junkan**, the pre-flight impact analysis engine.

It simulates a "Golden Path" failure scenario where an infrastructure change silently breaks a downstream BI dashboard—a problem that traditional linters and tests miss, but Junkan catches.

## The Scenario

1.  **The Change:** A developer renames an AWS RDS instance in Terraform (`infra/rds.tf`).
2.  **The Break:** A Python service (`app/payment_service.py`) relies on that resource via an environment variable `PAYMENTS_DB_HOST`. The rename breaks this link.
3.  **The Impact:** Production OpenLineage data shows that this Python service feeds the **Executive Revenue Dashboard**.
4.  **The Gate:** Junkan detects this chain of events and **BLOCKS** the PR before it merges.

## Architecture at a Glance

```mermaid
graph LR
    TF[Terraform Change] --"Breaks"--> APP[Python App]
    APP --"Feeds"--> DATA[Warehouse Table]
    DATA --"Powers"--> DASH[Executive Dashboard]
    
    style TF fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style DASH fill:#ff6b6b,stroke:#c92a2a,color:#fff
````

## Quick Start

### Prerequisites

  * Python 3.11+
  * The `junkan` source code in a sibling directory (`../junkan`)

### 1\. Install Junkan

Since Junkan is currently in private development, install it in "editable" mode from the sibling directory:

```bash
git clone git@github.com:bordumb/junkan-demo.git
git clone git@github.com:bordumb/junkan.git
# From the root of junkan-demo
pip install -e "../junkan[full]"
```

Verify installation:

```bash
junkan --version
```

### 2\. Run the Simulation

We have provided a script that simulates a "Bad PR" by modifying the Terraform file and running the Junkan gate against it.

```bash
cd junkan_spike
./simulate_block.sh
```

**Expected Output:**
You should see a **BLOCKED** status with a critical violation report:

```text
❌ BLOCKED - Critical Impact Detected
Policy Violations:
  🚨 Executive Reporting: Changes affect 1 executive assets
```

## 📂 Repository Structure

  * **`junkan_spike/`**: The root of the simulated project.
      * **`infra/`**: Terraform definitions (`rds.tf`).
      * **`app/`**: Application code (`payment_service.py`).
      * **`data/`**: Mocked OpenLineage production data.
      * **`policy.yaml`**: Rules defining "Critical" assets.
      * **`.github/workflows/`**: CI configuration.

## 🤖 CI/CD Integration

This demo includes a GitHub Actions workflow (`junkan_gate.yml`). In a real environment, this runs automatically on every Pull Request.

To see it in action:

1.  Push this repo to GitHub.
2.  Open a PR that modifies `junkan_spike/infra/rds.tf`.
3.  Watch the Action fail and post a comment on your PR.
