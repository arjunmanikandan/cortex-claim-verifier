-- ============================================================================
-- SETUP SCRIPT FOR HOME DAMAGE INSPECTION PROJECT
-- ============================================================================
-- 
-- This script creates the foundation for your insurance claims photo analysis
-- Run this BEFORE running test_vision_models.sql
--
-- Pattern: Follows vehicle_damage_image_analysis structure
-- ============================================================================

-- Step 1: Create database (if not exists)

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS HOME_DAMAGE_INSPECTION;
USE DATABASE HOME_DAMAGE_INSPECTION;

-- Step 2: Create schema
CREATE SCHEMA IF NOT EXISTS AERIAL_HOME_IMAGES;
USE SCHEMA AERIAL_HOME_IMAGES;

-- Step 3: Create stage with SERVER-SIDE ENCRYPTION (REQUIRED for Cortex vision)
-- This is the most important part - vision functions REQUIRE server-side encryption
CREATE OR REPLACE STAGE PROPERTY_IMAGES_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')  -- Server-side encryption REQUIRED
    DIRECTORY = (ENABLE = TRUE)             -- Enable directory table for DIRECTORY() function
    COMMENT = 'Stage for property damage photos - insurance claims analysis';

-- Verify stage was created successfully
SHOW STAGES LIKE 'PROPERTY_IMAGES_STAGE';

-- Check stage encryption settings
DESCRIBE STAGE PROPERTY_IMAGES_STAGE;


-- ============================================================================
-- NEXT STEPS:
-- ============================================================================
-- 
-- 1. ✅ You just created the stage with encryption
-- 
-- 2. ⬆️  Upload images to the stage using one of these methods:
--
--    METHOD A: SnowSQL (command line)
--    -----------------------------
--    PUT file:///path/to/your/images/*.jpg @HOME_DAMAGE_INSPECTION.PUBLIC.PROPERTY_IMAGES_STAGE AUTO_COMPRESS=FALSE;
--
--    METHOD B: Snowsight UI
--    -----------------------------
--    - Go to Data > Databases > HOME_DAMAGE_INSPECTION > PUBLIC > Stages
--    - Click PROPERTY_IMAGES_STAGE
--    - Click "+ Files" button
--    - Upload your property damage photos
--
--    METHOD C: Python (from Streamlit app later)
--    -----------------------------
--    session.file.put_stream(...)  -- We'll use this in the Streamlit app
--
-- 3. ✅ Verify images were uploaded:
--
--    SELECT * FROM DIRECTORY(@PROPERTY_IMAGES_STAGE);
--
-- 4. ✅ Then run test_vision_models.sql to test different AI models
--
-- ============================================================================

-- Helper query: List all files currently in the stage
SELECT 
    RELATIVE_PATH,
    SIZE,
    LAST_MODIFIED
FROM DIRECTORY(@PROPERTY_IMAGES_STAGE)
ORDER BY LAST_MODIFIED DESC;


-- ============================================================================
-- TROUBLESHOOTING:
-- ============================================================================
--
-- If you get "Stage not found" error:
--   - Make sure you're using the full path: @HOME_DAMAGE_INSPECTION.PUBLIC.PROPERTY_IMAGES_STAGE
--
-- If you get "Encryption not enabled" error:
--   - Re-run the CREATE STAGE statement above (it has ENCRYPTION = SNOWFLAKE_SSE)
--
-- If DIRECTORY() returns no results:
--   - You haven't uploaded any images yet
--   - Upload images using one of the methods above
--
-- ============================================================================
