-- ============================================================================
-- INSURANCE PROPERTY DAMAGE ANALYSIS PROMPT
-- ============================================================================
-- 
-- Project: Home Damage Inspection - Property Insurance Claims
-- Model: claude-sonnet-4-6
-- 
-- This prompt is the "brain" of your system - it tells the AI how to analyze
-- property damage photos for insurance claims.
-- 
-- Pattern: Similar to vehicle damage prompt, but for property insurance with:
--   - Damage detection and classification
--   - Severity assessment
--   - Consistency checking (photo vs customer narrative)
--   - Coverage indication (based on standard HO-3 policy)
--   - Red flag detection for potential fraud
-- ============================================================================

USE DATABASE HOME_DAMAGE_INSPECTION;
USE SCHEMA AERIAL_HOME_IMAGES;

-- ============================================================================
-- THE INSURANCE ANALYSIS PROMPT
-- ============================================================================
-- 
-- This prompt will be passed to AI_COMPLETE() along with property damage photos
-- It enforces strict JSON output that maps to the CLAIM_FINDINGS table
-- ============================================================================

CREATE OR REPLACE FUNCTION GET_INSURANCE_ANALYSIS_PROMPT(
    CUSTOMER_NARRATIVE VARCHAR,
    REPORTED_PERIL VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    'You are an insurance property damage photo analyst assisting a senior claims adjuster. Analyze the property image to triage damage for a homeowners insurance claim.

CONTEXT:
- Customer reported peril: ' || REPORTED_PERIL || '
- Customer narrative: ' || CUSTOMER_NARRATIVE || '

TASK:
Analyze the property image and identify all clearly visible damage. Compare what you see in the photo to what the customer reported.

Return ONLY valid JSON in this EXACT structure (no markdown, no code fences):
{
  "image_quality": "good, acceptable, poor, or unusable",
  "property_type": "single-family home, multi-family, commercial, or unknown",
  "property_description": "brief description of visible structure and setting",
  "damage_detected": true,
  "damage_count": 0,
  "visual_description": "detailed description of what is visible in the photo",
  "observed_damage_types": [
    "roof damage", "siding damage", "window damage", "structural damage", 
    "fire damage", "water damage", "wind damage", "hail damage", 
    "foundation damage", "tree/debris impact", "other"
  ],
  "likely_cause_from_image": "what type of event likely caused the visible damage based on visual evidence",
  "overall_severity": "NONE, MINOR, MODERATE, MAJOR, or CATASTROPHIC",
  "damages": [
    {
      "damage_location": "specific location (roof, front facade, garage, etc.)",
      "damage_type": "type of damage observed",
      "description": "detailed description of this specific damage",
      "severity": "NONE, MINOR, MODERATE, MAJOR, or CATASTROPHIC",
      "habitability_concern": false,
      "safety_concern": false
    }
  ],
  "consistency_with_narrative": "CONSISTENT, PARTIALLY_CONSISTENT, INCONSISTENT, or INSUFFICIENT_EVIDENCE",
  "inconsistency_notes": "if not consistent, explain what differs between photo and customer narrative",
  "suspected_red_flags": [
    "possible red flags: pre-existing damage, wrong peril type, cosmetic only, 
     no visible loss, staged, stock photo appearance, date inconsistency, 
     wear-and-tear not sudden event, other property visible, none"
  ],
  "coverage_indication": "LIKELY_COVERED, POSSIBLY_COVERED_SUBJECT_TO_REVIEW, LIKELY_EXCLUDED, or UNABLE_TO_DETERMINE",
  "coverage_rationale": "brief explanation based on standard HO-3 policy (covered perils: fire, lightning, wind, hail, explosion, vehicle impact, vandalism. Common exclusions: flood requires separate policy, earth movement, wear-and-tear, neglect, intentional acts). This is INDICATIVE ONLY - not a binding coverage determination.",
  "recommended_next_action": "recommended next step for adjuster (approve for inspection, request additional photos, escalate to fraud unit, etc.)"
}

CRITICAL RULES:
- Only report visible damage in THIS photo
- Do NOT infer hidden damage, mechanical issues, or damage not visible in the image
- Do NOT estimate dollar amounts for repairs
- Do NOT treat shadows, reflections, dirt, moss, or normal wear as damage
- If comparing to customer narrative, note when the visible damage does NOT match the reported peril
- Be specific about location (front facade, rear roof, etc.) not just "damage present"
- Coverage indication is advisory only - note common HO-3 exclusions but acknowledge human review required
- Red flags are for adjuster attention, not accusations
- Return empty damages array if no damage visible
- Return ONLY JSON, no other text

Remember: You are a triage assistant. Your job is to give the senior adjuster accurate information to make informed decisions, not to make final determinations yourself.'
$$;

-- ============================================================================
-- EXAMPLE USAGE
-- ============================================================================
-- 
-- Test the prompt function:
SELECT GET_INSURANCE_ANALYSIS_PROMPT(
    'Hurricane damaged my roof and water leaked inside',
    'hurricane'
);

-- ============================================================================
-- HOW THIS INTEGRATES WITH AI_COMPLETE
-- ============================================================================
--
-- In your analysis procedure, you'll call it like this:
--
-- SELECT AI_COMPLETE(
--     'claude-sonnet-4-6',
--     GET_INSURANCE_ANALYSIS_PROMPT(
--         claim.REPORTED_INCIDENT_NARRATIVE,
--         claim.PERIL_DETAIL
--     ),
--     TO_FILE('@PROPERTY_IMAGES_STAGE', image.RELATIVE_PATH)
-- ) AS analysis_result
--
-- The AI will return structured JSON that maps directly to CLAIM_FINDINGS table!
-- ============================================================================

-- ============================================================================
-- NEXT STEPS:
-- ============================================================================
-- 
-- ✅ Prompt created!
-- 
-- Next, we'll create:
--   1. Analysis procedures (SQL functions to process images and save findings)
--   2. Streamlit app (adjuster UI to upload images and view results)
-- 
-- ============================================================================
