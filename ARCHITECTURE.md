
# Junkan Demo Architecture

This document explains how the pieces of the demo fit together to detect cross-domain breaking changes.

## The "Kill Chain"

The core value of Junkan is detecting the invisible dependency chain that links a Terraform resource to a BI Dashboard.

```mermaid
graph TD
    subgraph Infrastructure ["1. Infrastructure (Terraform)"]
        RDS[aws_db_instance.payments_db]
        TAG[Identifier: payments-production-db]
        RDS --- TAG
    end

    subgraph Stitching ["2. The Stitch (Junkan Core)"]
        MATCH{Fuzzy Match}
        ENV_VAR[os.getenv PAYMENTS_DB_HOST]
    end

    subgraph Application ["3. Application (Python)"]
        SERVICE[payment_service.py]
        ETL[Job: payment_service_etl]
        SERVICE -.-> ETL
    end

    subgraph Production ["4. Runtime Lineage (OpenLineage)"]
        TABLE[warehouse.fact_payments]
        DASH[reports.executive_revenue_dashboard]
    end

    RDS --> MATCH
    ENV_VAR --> MATCH
    MATCH --> SERVICE
    ETL -->|Writes to| TABLE
    TABLE -->|Reads from| DASH

    style RDS fill:#4dabf7,color:#fff
    style DASH fill:#ff6b6b,color:#fff,stroke:#c92a2a,stroke-width:2px
````

## Data Flow: How `junkan check` Works

When you run `./simulate_block.sh`, the following process executes:

```mermaid
sequenceDiagram
    participant User
    participant CLI as junkan check
    participant Static as Static Analysis
    participant Runtime as OpenLineage
    participant Policy as Policy Engine

    User->>CLI: Run check (with mocked diff)
    
    rect rgb(240, 248, 255)
        Note over CLI,Static: Phase 1: What Changed?
        CLI->>Static: Parse changed file (rds.tf)
        Static-->>CLI: Detected change: "aws_db_instance renamed"
    end

    rect rgb(255, 248, 240)
        Note over CLI,Runtime: Phase 2: What is the Blast Radius?
        CLI->>Static: Find code using this resource (Stitching)
        Static-->>CLI: Link found: payment_service.py
        
        CLI->>Runtime: Load production lineage (production_lineage.json)
        Runtime-->>CLI: payment_service -> fact_payments -> Executive Dashboard
    end

    rect rgb(240, 255, 240)
        Note over CLI,Policy: Phase 3: Is this Allowed?
        CLI->>Policy: Evaluate Impact vs. Rules (policy.yaml)
        Policy-->>CLI: Violation! "Executive Dashboard" is CRITICAL.
    end

    CLI-->>User: ❌ EXIT 1 (BLOCKED)
```

## Component Breakdown

### 1\. Infrastructure (`infra/rds.tf`)

Defines the AWS resource. The key is the `identifier`.

  * **Change:** Renaming `identifier` breaks the contract with the app.

### 2\. Application (`app/payment_service.py`)

Reads the database host from the environment.

  * **Detection:** Junkan's Python parser finds `os.getenv("PAYMENTS_DB_HOST")`.
  * **Stitching:** The Stitcher connects "PAYMENTS\_DB\_HOST" (Env Var) to "payments-production-db" (Terraform Resource) using fuzzy token matching.

### 3\. Runtime Data (`data/production_lineage.json`)

A mocked export from a tool like Marquez or DataHub.

  * **Role:** Provides the "truth" about what happens *after* the code runs. It proves that `payment_service` writes to tables that power the dashboard.

### 4\. Policy (`policy.yaml`)

The governance layer.

  * **Rule:** Any impact to `.*executive.*dashboard.*` is `severity: CRITICAL`.
  * **Action:** If `CRITICAL` impact is found, return Exit Code 1 to fail the CI pipeline.
