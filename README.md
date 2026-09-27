# Cortex Claim Verifier

AI-powered insurance claims photo analysis built on Snowflake Cortex. Upload property damage photos, and the system uses `claude-sonnet-4-6` vision to detect damage types, assess severity, check consistency against the customer's narrative, flag potential fraud, and indicate HO-3 policy coverage.

## Architecture

```
                     ┌──────────────────────────┐
                     │   Streamlit App (5 pages) │
                     │  Dashboard · Claims Queue │
                     │  Claim Detail · Upload    │
                     └────────────┬─────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          ▼                       ▼                       ▼
  Upload images to         CALL stored procs        Read from views
  @PROPERTY_IMAGES_STAGE   (ANALYZE_CLAIM_IMAGE)    (V_CLAIM_SUMMARY, etc.)
          │                       │
          ▼                       ▼
  CLAIM_IMAGES table     AI_COMPLETE('claude-sonnet-4-6',
                           GET_INSURANCE_ANALYSIS_PROMPT(...),
                           TO_FILE(@stage, image))
                                  │
                                  ▼
                         Parse JSON → CLAIM_FINDINGS table

  CUSTOMERS ← CLAIMS ← CLAIM_IMAGES ← CLAIM_FINDINGS
  (25 rows)   (30 rows)   (uploaded)    (AI results)
```

## What the AI Returns

For each uploaded photo, the model returns structured JSON with:

| Field | Description |
|-------|-------------|
| `observed_damage_types` | Roof, siding, window, fire, water, wind, hail, etc. |
| `overall_severity` | NONE / MINOR / MODERATE / MAJOR / CATASTROPHIC |
| `consistency_with_narrative` | Does the photo match what the customer reported? |
| `suspected_red_flags` | Pre-existing damage, wrong peril, staged photo, etc. |
| `coverage_indication` | LIKELY_COVERED / POSSIBLY_COVERED / LIKELY_EXCLUDED |
| `recommended_next_action` | Approve, request more photos, escalate to fraud unit |

## Prerequisites

- Snowflake account with **Cortex AI** enabled
- Role with permissions to create databases, schemas, stages, and stored procedures (e.g., `ACCOUNTADMIN`)
- A warehouse (the scripts use `COMPUTE_WH`)
- A few property damage images (JPG/PNG) to upload

## Setup

Run the SQL scripts in order in a Snowflake worksheet:

### Step 0 — Create database, schema, and stage
```sql
-- sql/00_setup_stage_and_database.sql
-- Creates: HOME_DAMAGE_INSPECTION database, AERIAL_HOME_IMAGES schema,
--          PROPERTY_IMAGES_STAGE (with server-side encryption for Cortex vision)
```

### Step 1 — Create tables and views
```sql
-- sql/01_create_schema.sql
-- Creates: CUSTOMERS, CLAIMS, CLAIM_IMAGES, CLAIM_FINDINGS tables
--          V_CLAIM_SUMMARY, V_IMAGES_WITH_FINDINGS, V_CLAIMS_NEEDING_REVIEW views
```

### Step 2 — Insert synthetic demo data
```sql
-- sql/02_generate_synthetic_data.sql
-- Inserts: 25 customers (FL, CA, TX, NY, OH, WV) and 30 claims
--          Mix: 16 natural disasters, 11 man-made, 3 theft/vandalism
```

### Step 3 — Create the AI analysis prompt
```sql
-- sql/03_insurance_analysis_prompt.sql
-- Creates: GET_INSURANCE_ANALYSIS_PROMPT() UDF
--          This is the system prompt that tells claude-sonnet-4-6 how to analyze photos
```

### Step 4 — Create analysis stored procedures
```sql
-- sql/04_analysis_procedures.sql
-- Creates: ANALYZE_CLAIM_IMAGE (single image)
--          ANALYZE_ALL_CLAIM_IMAGES (all images for a claim)
--          BATCH_ANALYZE_STAGE_IMAGES (bulk stage scan)
--          V_ANALYSIS_SUMMARY view
```

### Step 5 — Upload property damage images

Upload JPG/PNG images of property damage to the stage using any of these methods:

**Snowsight UI:** Data > Databases > HOME_DAMAGE_INSPECTION > AERIAL_HOME_IMAGES > Stages > PROPERTY_IMAGES_STAGE > + Files

**SnowSQL:**
```sql
PUT file:///path/to/images/*.jpg @HOME_DAMAGE_INSPECTION.AERIAL_HOME_IMAGES.PROPERTY_IMAGES_STAGE AUTO_COMPRESS=FALSE;
```

**Or use the app's Upload page** (Step 6) to upload images directly from the browser.

### Step 6 — Deploy the Streamlit app

1. In Snowsight, go to **Projects > Workspaces**
2. Create a new workspace or use an existing one
3. Copy the contents of the `app/` directory into a folder in your workspace
4. Open `streamlit_app.py` and click **Run**

The app needs a **compute pool** (configured in `snowflake.yml` as `SYSTEM_COMPUTE_POOL_CPU`) and a **warehouse** (`COMPUTE_WH`).

## Project Structure

```
cortex-claim-verifier/
├── README.md
├── .gitignore
├── sql/
│   ├── 00_setup_stage_and_database.sql   # Database, schema, stage
│   ├── 01_create_schema.sql              # Tables and views
│   ├── 02_generate_synthetic_data.sql    # 25 customers, 30 claims
│   ├── 03_insurance_analysis_prompt.sql  # AI prompt UDF
│   └── 04_analysis_procedures.sql        # Stored procedures
└── app/
    ├── streamlit_app.py                  # 5-page Streamlit app
    ├── snowflake.yml                     # Snowflake deployment config
    ├── pyproject.toml                    # Python dependencies
    └── .streamlit/
        └── config.toml                   # UI theme
```

## Tech Stack

- **Snowflake Cortex AI** — `AI_COMPLETE` with `claude-sonnet-4-6` vision model
- **Snowflake Stages** — Server-side encrypted image storage with `TO_FILE()` access
- **Streamlit in Snowflake** — 5-page app running on Container Runtime
- **SQL Stored Procedures** — Orchestrate image analysis and persist findings
