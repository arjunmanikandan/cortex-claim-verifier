-- ============================================================================
-- SYNTHETIC DATA GENERATION FOR INSURANCE CLAIMS DEMO
-- ============================================================================
-- 
-- Project: Home Damage Inspection - Property Insurance Claims
-- Model: claude-sonnet-4-6
-- 
-- This script generates realistic demo data:
--   - 25 customers across FL, CA, TX, NY, OH, WV
--   - 30 claims with varied perils (natural disasters, man-made, theft/vandalism)
--   - Realistic narratives that you'll test against photos
-- ============================================================================

USE DATABASE HOME_DAMAGE_INSPECTION;
USE SCHEMA AERIAL_HOME_IMAGES;

-- ============================================================================
-- INSERT CUSTOMERS (25 synthetic policyholders)
-- ============================================================================

INSERT INTO CUSTOMERS (CUSTOMER_ID, FULL_NAME, EMAIL, PHONE, STREET_ADDRESS, CITY, STATE, ZIP, 
                       POLICY_NUMBER, POLICY_TYPE, COVERAGE_LIMIT_DWELLING, DEDUCTIBLE, 
                       POLICY_EFFECTIVE_DATE, POLICY_STATUS)
VALUES
-- Florida customers (hurricane/wind prone)
('CUST-001', 'Maria Rodriguez', 'maria.rodriguez@email.com', '305-555-0101', '1234 Ocean Drive', 'Miami', 'FL', '33139', 'POL-FL-2024-001', 'HO-3', 450000, 2500, '2024-01-15', 'ACTIVE'),
('CUST-002', 'James Wilson', 'j.wilson@email.com', '813-555-0102', '567 Gulf Boulevard', 'Tampa', 'FL', '33602', 'POL-FL-2024-002', 'HO-3', 380000, 2000, '2023-08-20', 'ACTIVE'),
('CUST-003', 'Linda Chen', 'lchen@email.com', '904-555-0103', '890 Beach Road', 'Jacksonville', 'FL', '32202', 'POL-FL-2023-003', 'HO-3', 420000, 3000, '2023-03-10', 'ACTIVE'),
('CUST-004', 'Robert Martinez', 'r.martinez@email.com', '954-555-0104', '2345 Palm Avenue', 'Fort Lauderdale', 'FL', '33301', 'POL-FL-2025-004', 'HO-3', 550000, 5000, '2025-02-01', 'ACTIVE'),

-- California customers (wildfire/earthquake prone)
('CUST-005', 'Sarah Thompson', 's.thompson@email.com', '415-555-0201', '123 Hill Street', 'San Francisco', 'CA', '94102', 'POL-CA-2024-001', 'HO-3', 950000, 5000, '2024-06-15', 'ACTIVE'),
('CUST-006', 'David Kim', 'dkim@email.com', '213-555-0202', '456 Sunset Boulevard', 'Los Angeles', 'CA', '90028', 'POL-CA-2023-002', 'HO-3', 875000, 4500, '2023-11-20', 'ACTIVE'),
('CUST-007', 'Jennifer White', 'jwhite@email.com', '619-555-0203', '789 Bay View Drive', 'San Diego', 'CA', '92101', 'POL-CA-2024-003', 'HO-3', 720000, 3500, '2024-04-05', 'ACTIVE'),
('CUST-008', 'Michael Brown', 'mbrown@email.com', '510-555-0204', '234 Oak Street', 'Oakland', 'CA', '94601', 'POL-CA-2024-004', 'HO-3', 680000, 3000, '2024-09-12', 'ACTIVE'),
('CUST-009', 'Emily Garcia', 'egarcia@email.com', '916-555-0205', '567 River Road', 'Sacramento', 'CA', '95814', 'POL-CA-2023-005', 'HO-3', 540000, 2500, '2023-07-18', 'ACTIVE'),

-- Texas customers (tornado/hail prone)
('CUST-010', 'Christopher Davis', 'c.davis@email.com', '214-555-0301', '890 Ranch Drive', 'Dallas', 'TX', '75201', 'POL-TX-2024-001', 'HO-3', 420000, 2500, '2024-02-20', 'ACTIVE'),
('CUST-011', 'Amanda Johnson', 'ajohnson@email.com', '713-555-0302', '1234 Houston Street', 'Houston', 'TX', '77002', 'POL-TX-2023-002', 'HO-3', 390000, 2000, '2023-12-10', 'ACTIVE'),
('CUST-012', 'Daniel Lee', 'dlee@email.com', '512-555-0303', '567 Congress Avenue', 'Austin', 'TX', '78701', 'POL-TX-2024-003', 'HO-3', 580000, 3500, '2024-05-08', 'ACTIVE'),
('CUST-013', 'Patricia Moore', 'pmoore@email.com', '210-555-0304', '890 Alamo Plaza', 'San Antonio', 'TX', '78205', 'POL-TX-2024-004', 'HO-3', 350000, 2000, '2024-07-22', 'ACTIVE'),

-- New York customers (winter storm/flooding prone)
('CUST-014', 'Thomas Anderson', 't.anderson@email.com', '212-555-0401', '1234 Broadway', 'New York', 'NY', '10001', 'POL-NY-2024-001', 'HO-3', 1200000, 7500, '2024-03-15', 'ACTIVE'),
('CUST-015', 'Elizabeth Taylor', 'etaylor@email.com', '718-555-0402', '567 Brooklyn Avenue', 'Brooklyn', 'NY', '11201', 'POL-NY-2023-002', 'HO-3', 850000, 5000, '2023-09-28', 'ACTIVE'),
('CUST-016', 'William Harris', 'wharris@email.com', '516-555-0403', '890 Long Island Drive', 'Hempstead', 'NY', '11550', 'POL-NY-2024-003', 'HO-3', 620000, 3500, '2024-01-10', 'ACTIVE'),
('CUST-017', 'Jessica Martin', 'jmartin@email.com', '315-555-0404', '234 Lake Road', 'Syracuse', 'NY', '13202', 'POL-NY-2024-004', 'HO-3', 280000, 1500, '2024-06-20', 'ACTIVE'),

-- Ohio customers (tornado/flooding prone)
('CUST-018', 'Richard Clark', 'rclark@email.com', '216-555-0501', '567 Euclid Avenue', 'Cleveland', 'OH', '44114', 'POL-OH-2024-001', 'HO-3', 240000, 1500, '2024-04-12', 'ACTIVE'),
('CUST-019', 'Barbara Lewis', 'blewis@email.com', '614-555-0502', '890 High Street', 'Columbus', 'OH', '43215', 'POL-OH-2023-003', 'HO-3', 310000, 2000, '2023-10-05', 'ACTIVE'),
('CUST-020', 'Joseph Walker', 'jwalker@email.com', '513-555-0503', '1234 Vine Street', 'Cincinnati', 'OH', '45202', 'POL-OH-2024-004', 'HO-3', 275000, 1500, '2024-08-17', 'ACTIVE'),

-- West Virginia customers (flooding/winter storm prone)
('CUST-021', 'Nancy Young', 'nyoung@email.com', '304-555-0601', '567 Capitol Street', 'Charleston', 'WV', '25301', 'POL-WV-2024-001', 'HO-3', 195000, 1000, '2024-02-28', 'ACTIVE'),
('CUST-022', 'Charles King', 'cking@email.com', '304-555-0602', '890 Mountain Road', 'Morgantown', 'WV', '26501', 'POL-WV-2023-002', 'HO-3', 220000, 1500, '2023-11-15', 'ACTIVE'),
('CUST-023', 'Karen Wright', 'kwright@email.com', '304-555-0603', '234 Valley Drive', 'Huntington', 'WV', '25701', 'POL-WV-2024-003', 'HO-3', 185000, 1000, '2024-05-30', 'ACTIVE'),

-- Additional diverse customers
('CUST-024', 'Steven Lopez', 'slopez@email.com', '305-555-0701', '1111 Bay Road', 'Miami Beach', 'FL', '33140', 'POL-FL-2024-005', 'HO-3', 780000, 5000, '2024-03-22', 'ACTIVE'),
('CUST-025', 'Margaret Hill', 'mhill@email.com', '323-555-0702', '2222 Highland Avenue', 'Los Angeles', 'CA', '90036', 'POL-CA-2024-006', 'HO-3', 920000, 5000, '2024-07-08', 'ACTIVE');

-- ============================================================================
-- INSERT CLAIMS (30 varied claims)
-- ============================================================================

INSERT INTO CLAIMS (CLAIM_ID, CUSTOMER_ID, DATE_OF_LOSS, REPORTED_DATE, REPORTED_CAUSE, 
                    REPORTED_INCIDENT_NARRATIVE, PERIL_DETAIL, CLAIMED_LOSS_AMOUNT, 
                    CLAIM_STATUS, STATE_OF_LOSS)
VALUES
-- Natural Disaster Claims
('CLM-2026-00001', 'CUST-001', '2026-08-15', '2026-08-16', 'NATURAL_DISASTER', 
 'Hurricane Category 3 hit our area. High winds tore off roof shingles and damaged fascia. Water leaked into master bedroom and living room causing ceiling damage.', 
 'hurricane', 85000, 'NEEDS_PHOTOS', 'FL'),

('CLM-2026-00002', 'CUST-002', '2026-07-20', '2026-07-21', 'NATURAL_DISASTER',
 'Severe thunderstorm with 70mph winds damaged roof and knocked down large tree onto garage. Garage door crushed and roof penetrated.',
 'wind', 45000, 'NEEDS_PHOTOS', 'FL'),

('CLM-2026-00003', 'CUST-005', '2026-06-10', '2026-06-11', 'NATURAL_DISASTER',
 'Wildfire approached within 500 feet of property. Heat damage to vinyl siding on west side. Smoke damage throughout interior. Landscaping destroyed.',
 'wildfire', 125000, 'NEEDS_PHOTOS', 'CA'),

('CLM-2026-00004', 'CUST-006', '2026-09-05', '2026-09-06', 'NATURAL_DISASTER',
 'Wildfire embers ignited roof. Fire department responded quickly but attic and roof sustained significant fire damage. Heavy smoke throughout home.',
 'wildfire', 280000, 'UNDER_REVIEW', 'CA'),

('CLM-2026-00005', 'CUST-010', '2026-05-22', '2026-05-23', 'NATURAL_DISASTER',
 'Tornado touched down 2 blocks away. Flying debris shattered multiple windows, damaged roof, ripped off gutters. Hail dented all exterior surfaces.',
 'tornado', 92000, 'NEEDS_PHOTOS', 'TX'),

('CLM-2026-00006', 'CUST-011', '2026-04-18', '2026-04-19', 'NATURAL_DISASTER',
 'Golf ball sized hail storm lasted 20 minutes. All roof shingles damaged, gutters dented, AC unit damaged, skylights cracked.',
 'hail', 68000, 'NEEDS_PHOTOS', 'TX'),

('CLM-2026-00007', 'CUST-014', '2026-02-10', '2026-02-11', 'NATURAL_DISASTER',
 'Winter storm ice accumulation caused roof collapse in sunroom. Water pipes froze and burst in basement. Extensive water damage to first floor.',
 'winter_storm', 145000, 'NEEDS_PHOTOS', 'NY'),

('CLM-2026-00008', 'CUST-021', '2026-03-28', '2026-03-29', 'NATURAL_DISASTER',
 'Spring flooding - river overflowed banks. First floor flooded with 3 feet of water. All appliances, flooring, drywall on first floor destroyed.',
 'flood', 175000, 'UNDER_REVIEW', 'WV'),

('CLM-2026-00009', 'CUST-018', '2026-06-15', '2026-06-16', 'NATURAL_DISASTER',
 'Severe thunderstorm with straight-line winds knocked tree onto house. Tree penetrated roof and damaged master bedroom. Rain water damage.',
 'wind', 78000, 'NEEDS_PHOTOS', 'OH'),

('CLM-2026-00010', 'CUST-003', '2026-08-25', '2026-08-26', 'NATURAL_DISASTER',
 'Hurricane storm surge flooded first floor. 18 inches of saltwater throughout. Electrical panel submerged. Mold concerns.',
 'hurricane', 195000, 'NEEDS_PHOTOS', 'FL'),

-- Man-Made / Accidental Claims
('CLM-2026-00011', 'CUST-007', '2026-07-12', '2026-07-12', 'MAN_MADE',
 'Kitchen fire started from grease on stovetop. Fire spread to cabinets and ceiling. Kitchen destroyed, heavy smoke damage to adjacent rooms.',
 'kitchen_fire', 95000, 'NEEDS_PHOTOS', 'CA'),

('CLM-2026-00012', 'CUST-012', '2026-05-08', '2026-05-08', 'MAN_MADE',
 'Electrical fire in attic from faulty wiring. Fire contained to attic but smoke damage throughout home. Roof partially burned.',
 'electrical_fire', 115000, 'NEEDS_PHOTOS', 'TX'),

('CLM-2026-00013', 'CUST-015', '2026-04-20', '2026-04-21', 'MAN_MADE',
 'Water heater in basement failed and flooded. 6 inches of water throughout basement. Furnace damaged. Finished basement ruined.',
 'water_leak', 42000, 'NEEDS_PHOTOS', 'NY'),

('CLM-2026-00014', 'CUST-019', '2026-06-30', '2026-07-01', 'MAN_MADE',
 'Burst pipe in bathroom while we were on vacation. Water ran for 3 days. Extensive water damage to 2 bathrooms and hallway.',
 'burst_pipe', 58000, 'NEEDS_PHOTOS', 'OH'),

('CLM-2026-00015', 'CUST-008', '2026-08-05', '2026-08-05', 'MAN_MADE',
 'Vehicle lost control and crashed through garage wall into living room. Structural damage to wall, garage door destroyed.',
 'vehicle_impact', 72000, 'UNDER_REVIEW', 'CA'),

('CLM-2026-00016', 'CUST-013', '2026-07-15', '2026-07-16', 'MAN_MADE',
 'Chimney fire from creosote buildup. Fire department contained fire but chimney needs rebuild. Smoke damage in living room.',
 'chimney_fire', 38000, 'NEEDS_PHOTOS', 'TX'),

('CLM-2026-00017', 'CUST-022', '2026-05-18', '2026-05-19', 'MAN_MADE',
 'Sewer backup flooded basement with sewage. All basement contents ruined. Need sanitization and restoration.',
 'sewer_backup', 48000, 'NEEDS_PHOTOS', 'WV'),

-- Theft / Vandalism Claims
('CLM-2026-00018', 'CUST-004', '2026-08-10', '2026-08-11', 'THEFT_VANDALISM',
 'Burglars broke in through rear sliding glass door while we were out. Stole electronics and jewelry. Glass door shattered.',
 'forced_entry', 15000, 'NEEDS_PHOTOS', 'FL'),

('CLM-2026-00019', 'CUST-009', '2026-07-25', '2026-07-26', 'THEFT_VANDALISM',
 'HVAC unit stolen from side of house. Copper piping cut. Refrigerant released. Need full AC replacement.',
 'hvac_theft', 12000, 'NEEDS_PHOTOS', 'CA'),

('CLM-2026-00020', 'CUST-016', '2026-06-08', '2026-06-09', 'THEFT_VANDALISM',
 'Vandals spray painted graffiti on garage door and front of house. Windows broken with rocks. Mailbox destroyed.',
 'vandalism', 8500, 'NEEDS_PHOTOS', 'NY'),

-- Additional Mixed Claims
('CLM-2026-00021', 'CUST-024', '2026-09-01', '2026-09-02', 'NATURAL_DISASTER',
 'Hurricane Category 2. Storm surge flooded garage. Wind tore off pool enclosure. Roof shingles damaged. Fence destroyed.',
 'hurricane', 112000, 'NEEDS_PHOTOS', 'FL'),

('CLM-2026-00022', 'CUST-025', '2026-08-20', '2026-08-21', 'NATURAL_DISASTER',
 'Brush fire spread to property. Wooden fence completely burned. Deck partially burned. Smoke damage to exterior and interior.',
 'wildfire', 87000, 'NEEDS_PHOTOS', 'CA'),

('CLM-2026-00023', 'CUST-020', '2026-07-04', '2026-07-05', 'MAN_MADE',
 'Fireworks accident caused fire on roof. Fire spread to attic. Firefighters contained it but roof and attic destroyed.',
 'fire', 134000, 'UNDER_REVIEW', 'OH'),

('CLM-2026-00024', 'CUST-017', '2026-03-15', '2026-03-16', 'NATURAL_DISASTER',
 'Ice dam caused water to back up under shingles. Water leaked into attic and 3 bedrooms. Ceiling stains and insulation damage.',
 'ice_dam', 24000, 'NEEDS_PHOTOS', 'NY'),

('CLM-2026-00025', 'CUST-023', '2026-04-10', '2026-04-11', 'NATURAL_DISASTER',
 'Flash flood from creek behind house. Basement flooded, foundation cracked. Extensive water damage.',
 'flood', 98000, 'NEEDS_PHOTOS', 'WV'),

('CLM-2026-00026', 'CUST-002', '2026-09-10', '2026-09-11', 'MAN_MADE',
 'Lightning strike caused power surge. Electrical panel fried. Multiple appliances damaged. Need electrical system replacement.',
 'lightning', 32000, 'NEEDS_PHOTOS', 'FL'),

('CLM-2026-00027', 'CUST-011', '2026-08-12', '2026-08-13', 'THEFT_VANDALISM',
 'Catalytic converter stolen from car in driveway. Thieves also stole copper downspouts from house.',
 'theft', 4500, 'NEEDS_PHOTOS', 'TX'),

('CLM-2026-00028', 'CUST-006', '2026-07-30', '2026-07-31', 'MAN_MADE',
 'Dryer vent fire in laundry room. Fire contained but laundry room destroyed. Smoke damage to surrounding rooms.',
 'appliance_fire', 28000, 'NEEDS_PHOTOS', 'CA'),

('CLM-2026-00029', 'CUST-014', '2026-06-22', '2026-06-23', 'MAN_MADE',
 'Air conditioning unit malfunctioned and caused water leak through ceiling. Damaged living room ceiling and hardwood floors.',
 'ac_leak', 18000, 'NEEDS_PHOTOS', 'NY'),

('CLM-2026-00030', 'CUST-010', '2026-09-15', '2026-09-16', 'NATURAL_DISASTER',
 'Severe hailstorm with tennis ball size hail. Roof completely destroyed. All windows cracked. Cars in driveway totaled.',
 'hail', 156000, 'NEEDS_PHOTOS', 'TX');

-- ============================================================================
-- VERIFY DATA
-- ============================================================================

SELECT 'Customers Inserted' AS summary, COUNT(*) AS count FROM CUSTOMERS
UNION ALL
SELECT 'Claims Inserted', COUNT(*) FROM CLAIMS;

-- View claim distribution by cause
SELECT REPORTED_CAUSE, COUNT(*) AS claim_count
FROM CLAIMS
GROUP BY REPORTED_CAUSE
ORDER BY claim_count DESC;

-- View claim distribution by state
SELECT STATE_OF_LOSS, COUNT(*) AS claim_count
FROM CLAIMS
GROUP BY STATE_OF_LOSS
ORDER BY claim_count DESC;

-- ============================================================================
-- NEXT STEPS:
-- ============================================================================
-- 
-- ✅ Data inserted successfully!
-- 
-- You now have:
--   - 25 customers across FL, CA, TX, NY, OH, WV
--   - 30 claims with realistic narratives
--   - Mix of natural disasters (16), man-made (11), theft/vandalism (3)
-- 
-- Next we'll:
--   1. Create the insurance analysis prompt (the AI's instructions)
--   2. Link images to claims in CLAIM_IMAGES table
--   3. Build the analysis procedures
--   4. Create the Streamlit app
-- 
-- ============================================================================

SELECT * FROM CUSTOMERS;  -- Should show 25
SELECT * FROM CLAIMS;     -- Should show 30