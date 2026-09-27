-- ============================================================================
-- IMAGE ANALYSIS PROCEDURES FOR INSURANCE CLAIMS
-- ============================================================================
-- 
-- Project: Home Damage Inspection - Property Insurance Claims
-- Model: claude-sonnet-4-6
-- 
-- These procedures analyze property damage photos using Cortex AI and save
-- findings to the CLAIM_FINDINGS table.
-- 
-- Pattern: Follows vehicle_damage_image_analysis logic
-- ============================================================================

USE DATABASE HOME_DAMAGE_INSPECTION;
USE SCHEMA AERIAL_HOME_IMAGES;

-- ============================================================================
-- PROCEDURE 1: ANALYZE SINGLE IMAGE
-- ============================================================================
-- Analyzes one image for a claim and inserts findings into CLAIM_FINDINGS

CREATE OR REPLACE PROCEDURE ANALYZE_CLAIM_IMAGE(
    P_CLAIM_ID VARCHAR,
    P_IMAGE_ID VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_customer_narrative VARCHAR;
    v_peril_detail VARCHAR;
    v_relative_path VARCHAR;
    v_analysis_result VARIANT;
    v_finding_id VARCHAR;
BEGIN
    -- Get claim details and image path
    SELECT 
        c.REPORTED_INCIDENT_NARRATIVE,
        c.PERIL_DETAIL,
        ci.RELATIVE_PATH
    INTO 
        v_customer_narrative,
        v_peril_detail,
        v_relative_path
    FROM CLAIMS c
    JOIN CLAIM_IMAGES ci ON c.CLAIM_ID = ci.CLAIM_ID
    WHERE c.CLAIM_ID = :P_CLAIM_ID
      AND ci.IMAGE_ID = :P_IMAGE_ID;
    
    -- Call AI_COMPLETE with the insurance analysis prompt
    SELECT 
        AI_COMPLETE(
            'claude-sonnet-4-6',
            GET_INSURANCE_ANALYSIS_PROMPT(
                :v_customer_narrative,
                :v_peril_detail
            ),
            TO_FILE('@PROPERTY_IMAGES_STAGE', :v_relative_path)
        )
    INTO v_analysis_result;
    
    -- Generate finding ID
    v_finding_id := 'FIND-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS') || '-' || SUBSTR(UUID_STRING(), 1, 8);
    
    -- Parse JSON and insert into CLAIM_FINDINGS
    INSERT INTO CLAIM_FINDINGS (
        FINDING_ID,
        CLAIM_ID,
        IMAGE_ID,
        MODEL_NAME,
        VISUAL_DESCRIPTION,
        OBSERVED_DAMAGE_TYPES,
        LIKELY_CAUSE_FROM_IMAGE,
        SEVERITY,
        CONSISTENCY_WITH_NARRATIVE,
        INCONSISTENCY_NOTES,
        SUSPECTED_RED_FLAGS,
        COVERAGE_INDICATION,
        COVERAGE_RATIONALE,
        RECOMMENDED_NEXT_ACTION,
        RAW_MODEL_JSON
    )
    SELECT
        :v_finding_id,
        :P_CLAIM_ID,
        :P_IMAGE_ID,
        'claude-sonnet-4-6',
        v_analysis_result:visual_description::VARCHAR,
        v_analysis_result:observed_damage_types,
        v_analysis_result:likely_cause_from_image::VARCHAR,
        v_analysis_result:overall_severity::VARCHAR,
        v_analysis_result:consistency_with_narrative::VARCHAR,
        v_analysis_result:inconsistency_notes::VARCHAR,
        v_analysis_result:suspected_red_flags,
        v_analysis_result:coverage_indication::VARCHAR,
        v_analysis_result:coverage_rationale::VARCHAR,
        v_analysis_result:recommended_next_action::VARCHAR,
        v_analysis_result;
    
    RETURN 'Analysis complete. Finding ID: ' || v_finding_id;
END;
$$;

-- ============================================================================
-- PROCEDURE 2: ANALYZE ALL IMAGES FOR A CLAIM
-- ============================================================================
-- Analyzes all images attached to a claim

CREATE OR REPLACE PROCEDURE ANALYZE_ALL_CLAIM_IMAGES(
    P_CLAIM_ID VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_image_count INTEGER;
    v_processed INTEGER := 0;
    c1 CURSOR FOR 
        SELECT IMAGE_ID 
        FROM CLAIM_IMAGES 
        WHERE CLAIM_ID = :P_CLAIM_ID;
BEGIN
    -- Count images
    SELECT COUNT(*) INTO v_image_count
    FROM CLAIM_IMAGES
    WHERE CLAIM_ID = :P_CLAIM_ID;
    
    -- Analyze each image
    FOR record IN c1 DO
        CALL ANALYZE_CLAIM_IMAGE(:P_CLAIM_ID, record.IMAGE_ID);
        v_processed := v_processed + 1;
    END FOR;
    
    -- Update claim status
    UPDATE CLAIMS
    SET CLAIM_STATUS = 'READY_FOR_ADJUSTER',
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE CLAIM_ID = :P_CLAIM_ID;
    
    RETURN 'Analyzed ' || v_processed || ' image(s) for claim ' || :P_CLAIM_ID;
END;
$$;

-- ============================================================================
-- PROCEDURE 3: BATCH ANALYZE IMAGES FROM STAGE
-- ============================================================================
-- Processes all images in stage that aren't yet in CLAIM_IMAGES table
-- Useful for bulk upload scenarios

CREATE OR REPLACE PROCEDURE BATCH_ANALYZE_STAGE_IMAGES(
    P_CLAIM_ID VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_processed INTEGER := 0;
    c1 CURSOR FOR 
        SELECT RELATIVE_PATH, SIZE
        FROM DIRECTORY(@PROPERTY_IMAGES_STAGE)
        WHERE LOWER(RELATIVE_PATH) LIKE '%.jpg'
           OR LOWER(RELATIVE_PATH) LIKE '%.jpeg'
           OR LOWER(RELATIVE_PATH) LIKE '%.png'
           OR LOWER(RELATIVE_PATH) LIKE '%.webp';
BEGIN
    -- For each image in stage, create CLAIM_IMAGES record and analyze
    FOR record IN c1 DO
        -- Generate image ID
        LET v_image_id VARCHAR := 'IMG-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS') || '-' || v_processed;
        
        -- Insert into CLAIM_IMAGES
        INSERT INTO CLAIM_IMAGES (
            IMAGE_ID,
            CLAIM_ID,
            FILE_NAME,
            STAGE_PATH,
            RELATIVE_PATH,
            FILE_SIZE_BYTES,
            FILE_TYPE
        )
        VALUES (
            v_image_id,
            :P_CLAIM_ID,
            SPLIT_PART(record.RELATIVE_PATH, '/', -1),
            '@PROPERTY_IMAGES_STAGE/' || record.RELATIVE_PATH,
            record.RELATIVE_PATH,
            record.SIZE,
            'image/' || LOWER(SPLIT_PART(record.RELATIVE_PATH, '.', -1))
        );
        
        -- Analyze the image
        CALL ANALYZE_CLAIM_IMAGE(:P_CLAIM_ID, v_image_id);
        
        v_processed := v_processed + 1;
    END FOR;
    
    RETURN 'Processed ' || v_processed || ' image(s) from stage for claim ' || :P_CLAIM_ID;
END;
$$;

-- ============================================================================
-- HELPER VIEW: ANALYSIS SUMMARY
-- ============================================================================
-- Quick view of all analyzed images with key findings

CREATE OR REPLACE VIEW V_ANALYSIS_SUMMARY AS
SELECT 
    cf.FINDING_ID,
    cf.CLAIM_ID,
    c.REPORTED_CAUSE,
    c.PERIL_DETAIL,
    cu.FULL_NAME AS CUSTOMER_NAME,
    cu.STATE,
    ci.FILE_NAME,
    cf.SEVERITY,
    cf.CONSISTENCY_WITH_NARRATIVE,
    cf.COVERAGE_INDICATION,
    cf.RECOMMENDED_NEXT_ACTION,
    cf.ANALYZED_AT
FROM CLAIM_FINDINGS cf
JOIN CLAIMS c ON cf.CLAIM_ID = c.CLAIM_ID
JOIN CUSTOMERS cu ON c.CUSTOMER_ID = cu.CUSTOMER_ID
LEFT JOIN CLAIM_IMAGES ci ON cf.IMAGE_ID = ci.IMAGE_ID
ORDER BY cf.ANALYZED_AT DESC;

-- ============================================================================
-- EXAMPLE USAGE
-- ============================================================================

-- Example 1: Analyze a single image
-- CALL ANALYZE_CLAIM_IMAGE('CLM-2026-00001', 'IMG-001');

-- Example 2: Analyze all images for a claim
-- CALL ANALYZE_ALL_CLAIM_IMAGES('CLM-2026-00001');

-- Example 3: Batch process all images in stage for a claim
-- CALL BATCH_ANALYZE_STAGE_IMAGES('CLM-2026-00001');

-- View results:
-- SELECT * FROM V_ANALYSIS_SUMMARY;
-- SELECT * FROM V_CLAIMS_NEEDING_REVIEW;

-- ============================================================================
-- NEXT STEPS:
-- ============================================================================
-- 
-- ✅ Analysis procedures created!
-- 
-- Next:
--   1. Test with your actual images in the stage
--   2. Build Streamlit app (adjuster UI)
-- 
-- To test right now:
--   1. Make sure images are in @PROPERTY_IMAGES_STAGE
--   2. Pick a claim ID (e.g., 'CLM-2026-00001')
--   3. Run: CALL BATCH_ANALYZE_STAGE_IMAGES('CLM-2026-00001');
--   4. Check results: SELECT * FROM V_ANALYSIS_SUMMARY;
-- 
-- ============================================================================
