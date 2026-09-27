-- ============================================================================
-- DATABASE SCHEMA SETUP FOR INSURANCE CLAIMS PHOTO ANALYSIS
-- ============================================================================
-- 
-- Project: Home Damage Inspection - Property Insurance Claims
-- Model: claude-sonnet-4-6
-- Pattern: Follows vehicle_damage_image_analysis structure
-- 
-- This script creates the complete data model for insurance claims analysis
-- ============================================================================

USE DATABASE HOME_DAMAGE_INSPECTION;
USE SCHEMA AERIAL_HOME_IMAGES;  -- Using your existing schema

-- ============================================================================
-- TABLE 1: CUSTOMERS
-- ============================================================================
-- Stores policyholder information

CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID VARCHAR(50) PRIMARY KEY,
    FULL_NAME VARCHAR(200) NOT NULL,
    EMAIL VARCHAR(200),
    PHONE VARCHAR(20),
    STREET_ADDRESS VARCHAR(300),
    CITY VARCHAR(100),
    STATE VARCHAR(2),
    ZIP VARCHAR(10),
    POLICY_NUMBER VARCHAR(50) UNIQUE NOT NULL,
    POLICY_TYPE VARCHAR(50) DEFAULT 'HO-3',  -- Homeowners policy type
    COVERAGE_LIMIT_DWELLING NUMBER(12,2),
    DEDUCTIBLE NUMBER(10,2),
    POLICY_EFFECTIVE_DATE DATE,
    POLICY_STATUS VARCHAR(20) DEFAULT 'ACTIVE',  -- ACTIVE, LAPSED, CANCELLED
    CREATED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- TABLE 2: CLAIMS
-- ============================================================================
-- Stores claim header information

CREATE OR REPLACE TABLE CLAIMS (
    CLAIM_ID VARCHAR(50) PRIMARY KEY,  -- e.g. CLM-2026-00041
    CUSTOMER_ID VARCHAR(50) NOT NULL,
    DATE_OF_LOSS DATE NOT NULL,
    REPORTED_DATE DATE NOT NULL,
    REPORTED_CAUSE VARCHAR(50) NOT NULL,  -- NATURAL_DISASTER, MAN_MADE, THEFT_VANDALISM, UNKNOWN
    REPORTED_INCIDENT_NARRATIVE TEXT,     -- What customer said happened
    PERIL_DETAIL VARCHAR(100),            -- hurricane, wildfire, flood, tornado, hail, etc.
    CLAIMED_LOSS_AMOUNT NUMBER(12,2),
    CLAIM_STATUS VARCHAR(50) DEFAULT 'INTAKE',  -- INTAKE, UNDER_REVIEW, NEEDS_PHOTOS, READY_FOR_ADJUSTER
    STATE_OF_LOSS VARCHAR(2),
    CREATED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMERS(CUSTOMER_ID)
);

-- ============================================================================
-- TABLE 3: CLAIM_IMAGES
-- ============================================================================
-- Stores metadata about photos attached to claims

CREATE OR REPLACE TABLE CLAIM_IMAGES (
    IMAGE_ID VARCHAR(50) PRIMARY KEY,
    CLAIM_ID VARCHAR(50) NOT NULL,
    FILE_NAME VARCHAR(500),
    STAGE_PATH VARCHAR(1000) NOT NULL,     -- Full path: @stage/path/file.jpg
    RELATIVE_PATH VARCHAR(1000),           -- Relative path within stage
    FILE_SIZE_BYTES NUMBER,
    FILE_TYPE VARCHAR(50),                 -- image/jpeg, image/png, etc.
    UPLOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    PHOTO_ANGLE VARCHAR(100),              -- front exterior, roof, interior living room, etc.
    IS_PRIMARY_PHOTO BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (CLAIM_ID) REFERENCES CLAIMS(CLAIM_ID)
);

-- ============================================================================
-- TABLE 4: CLAIM_FINDINGS
-- ============================================================================
-- Stores AI analysis results (written by Cortex AI)
-- This is the most important table - it holds all AI-generated insights

CREATE OR REPLACE TABLE CLAIM_FINDINGS (
    FINDING_ID VARCHAR(50) PRIMARY KEY,
    CLAIM_ID VARCHAR(50) NOT NULL,
    IMAGE_ID VARCHAR(50),                   -- NULL for claim-level rollup findings
    MODEL_NAME VARCHAR(50) NOT NULL,        -- claude-sonnet-4-6
    ANALYZED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- Visual Analysis Fields
    VISUAL_DESCRIPTION TEXT,
    OBSERVED_DAMAGE_TYPES VARIANT,          -- Array of damage types: ["roof damage", "water intrusion"]
    LIKELY_CAUSE_FROM_IMAGE VARCHAR(200),
    
    -- Severity Assessment
    SEVERITY VARCHAR(50),                   -- NONE, MINOR, MODERATE, MAJOR, CATASTROPHIC
    
    -- Consistency Check
    CONSISTENCY_WITH_NARRATIVE VARCHAR(50), -- CONSISTENT, PARTIALLY_CONSISTENT, INCONSISTENT, INSUFFICIENT_EVIDENCE
    INCONSISTENCY_NOTES TEXT,
    SUSPECTED_RED_FLAGS VARIANT,            -- JSON array of red flags
    
    -- Coverage Indication (not binding)
    COVERAGE_INDICATION VARCHAR(100),       -- LIKELY_COVERED, POSSIBLY_COVERED_SUBJECT_TO_REVIEW, LIKELY_EXCLUDED, UNABLE_TO_DETERMINE
    COVERAGE_RATIONALE TEXT,
    RECOMMENDED_NEXT_ACTION TEXT,
    
    -- Raw Response
    RAW_MODEL_JSON VARIANT,                 -- Complete JSON response from AI
    
    FOREIGN KEY (CLAIM_ID) REFERENCES CLAIMS(CLAIM_ID),
    FOREIGN KEY (IMAGE_ID) REFERENCES CLAIM_IMAGES(IMAGE_ID)
);

-- ============================================================================
-- QUERY OPTIMIZATION (Optional)
-- ============================================================================
-- 
-- Note: Snowflake doesn't support traditional secondary indexes on standard tables.
-- Instead, Snowflake uses:
--   1. Automatic micro-partition pruning (based on table clustering)
--   2. Search Optimization Service (optional, for point lookups)
-- 
-- For production workloads with frequent filtering on specific columns,
-- you can enable Search Optimization Service like this:
--
-- ALTER TABLE CLAIMS ADD SEARCH OPTIMIZATION ON EQUALITY(CLAIM_STATUS, STATE_OF_LOSS);
-- ALTER TABLE CLAIM_FINDINGS ADD SEARCH OPTIMIZATION ON EQUALITY(CONSISTENCY_WITH_NARRATIVE, SEVERITY);
--
-- This is optional and adds storage cost. For a demo/small dataset, it's not needed.
-- Snowflake's automatic clustering is sufficient for most use cases.
-- ============================================================================

-- ============================================================================
-- VIEWS FOR EASY QUERYING
-- ============================================================================

-- View 1: Claim Summary (joins all relevant data)
CREATE OR REPLACE VIEW V_CLAIM_SUMMARY AS
SELECT 
    c.CLAIM_ID,
    c.DATE_OF_LOSS,
    c.REPORTED_CAUSE,
    c.PERIL_DETAIL,
    c.CLAIMED_LOSS_AMOUNT,
    c.CLAIM_STATUS,
    cu.FULL_NAME,
    cu.CITY,
    cu.STATE,
    cu.POLICY_NUMBER,
    COUNT(DISTINCT ci.IMAGE_ID) AS IMAGE_COUNT,
    MAX(cf.SEVERITY) AS MAX_SEVERITY,
    MAX(CASE WHEN cf.CONSISTENCY_WITH_NARRATIVE = 'INCONSISTENT' THEN 1 ELSE 0 END) AS HAS_INCONSISTENCY,
    MAX(cf.COVERAGE_INDICATION) AS COVERAGE_STATUS
FROM CLAIMS c
JOIN CUSTOMERS cu ON c.CUSTOMER_ID = cu.CUSTOMER_ID
LEFT JOIN CLAIM_IMAGES ci ON c.CLAIM_ID = ci.CLAIM_ID
LEFT JOIN CLAIM_FINDINGS cf ON c.CLAIM_ID = cf.CLAIM_ID
GROUP BY 
    c.CLAIM_ID, c.DATE_OF_LOSS, c.REPORTED_CAUSE, c.PERIL_DETAIL,
    c.CLAIMED_LOSS_AMOUNT, c.CLAIM_STATUS, cu.FULL_NAME, cu.CITY, 
    cu.STATE, cu.POLICY_NUMBER;

-- View 2: Images with Findings (ready for adjuster review)
CREATE OR REPLACE VIEW V_IMAGES_WITH_FINDINGS AS
SELECT 
    ci.IMAGE_ID,
    ci.CLAIM_ID,
    ci.FILE_NAME,
    ci.RELATIVE_PATH,
    ci.PHOTO_ANGLE,
    cf.VISUAL_DESCRIPTION,
    cf.SEVERITY,
    cf.CONSISTENCY_WITH_NARRATIVE,
    cf.COVERAGE_INDICATION,
    cf.RECOMMENDED_NEXT_ACTION,
    cf.ANALYZED_AT
FROM CLAIM_IMAGES ci
LEFT JOIN CLAIM_FINDINGS cf ON ci.IMAGE_ID = cf.IMAGE_ID
ORDER BY ci.UPLOADED_AT DESC;

-- View 3: Claims Needing Review (flagged or inconsistent)
CREATE OR REPLACE VIEW V_CLAIMS_NEEDING_REVIEW AS
SELECT 
    c.CLAIM_ID,
    cu.FULL_NAME,
    c.REPORTED_CAUSE,
    c.PERIL_DETAIL,
    cf.SEVERITY,
    cf.CONSISTENCY_WITH_NARRATIVE,
    cf.SUSPECTED_RED_FLAGS,
    cf.COVERAGE_INDICATION,
    c.CLAIM_STATUS
FROM CLAIMS c
JOIN CUSTOMERS cu ON c.CUSTOMER_ID = cu.CUSTOMER_ID
JOIN CLAIM_FINDINGS cf ON c.CLAIM_ID = cf.CLAIM_ID
WHERE cf.CONSISTENCY_WITH_NARRATIVE IN ('INCONSISTENT', 'PARTIALLY_CONSISTENT')
   OR cf.SEVERITY IN ('MAJOR', 'CATASTROPHIC')
   OR cf.SUSPECTED_RED_FLAGS IS NOT NULL
ORDER BY cf.SEVERITY DESC, c.DATE_OF_LOSS DESC;

-- ============================================================================
-- VERIFY SCHEMA
-- ============================================================================

SHOW TABLES;
SHOW VIEWS;

-- ============================================================================
-- NEXT STEPS:
-- ============================================================================
-- 
-- ✅ Schema created successfully!
-- 
-- Next, we'll:
--   1. Generate synthetic customer and claim data
--   2. Create the insurance analysis prompt
--   3. Build SQL procedures to analyze images
--   4. Build the Streamlit adjuster app
-- 
-- ============================================================================
