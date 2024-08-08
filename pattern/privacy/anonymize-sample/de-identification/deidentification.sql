--TODO: Ask Bassit to create a unique value generator for ids 
--The function ulid() when invoked in any insert command in this file generated error 'No such function ulid()'.
--The file was executed using this command 'surveilr anonymize --sql deidentification.sql

--Example: modified the insert command like this 
--INSERT INTO orchestration_session_entry (orchestration_session_entry_id, session_id, ingest_src, ingest_table_name, elaboration)
--SELECT
    --(ulid()) as orchestration_session_entry_id,
    --orchestration_session_id,
    --'de-identification',
    --NULL,
   -- '{"description": "Processing de-identification"}'
--FROM session_info;
--Save this file after changing as above .see the ulid function being called
--execute command 'surveilr anonymize --sql deidentification.sql'
--Error is generated

--TODO: Ask Basit to capture any errors,logs etc while executing the anonymize or any operation using surveilr
--example: if 'surveilr anonymize --sql deidentification.sql' caused any error,or any action(like number of records de-identified,tables that under went deidentification) must be logged in respective tables
--An issue has be created : Ensure Anonymize and Verification/Validation Operations Log to Orchestration Tables #166

-- Begin a transaction
BEGIN;

-- Perform De-identification
UPDATE uniform_resource_investigator
SET email = anonymize_email(email)
WHERE email IS NOT NULL;

UPDATE uniform_resource_author
SET email = anonymize_email(email)
WHERE email IS NOT NULL;


-- Insert into orchestration_nature if not exists
INSERT OR IGNORE INTO orchestration_nature (orchestration_nature_id, nature)
VALUES ('deidentify', 'De-identification');

-- Retrieve the device ID and orchestration nature ID
WITH device_info AS (
    SELECT device_id FROM device LIMIT 1
),
orch_nature_info AS (
    SELECT orchestration_nature_id FROM orchestration_nature WHERE nature = 'De-identification' LIMIT 1
)
INSERT OR IGNORE INTO orchestration_session (orchestration_session_id, device_id, orchestration_nature_id, version, args_json, diagnostics_json, diagnostics_md)
SELECT
    'ORCSESSIONID-'||((SELECT COUNT(*) FROM orchestration_session) + 1) AS orchestration_session_id,    
    d.device_id,
    o.orchestration_nature_id,
    '1.0',
    '{"parameters": "de-identification"}',
    '{"status": "started"}',
    'Started de-identification process'
FROM device_info d, orch_nature_info o;

-- Retrieve the new session ID
WITH session_info AS (
    SELECT orchestration_session_id FROM orchestration_session LIMIT 1
)
INSERT OR IGNORE INTO orchestration_session_entry (orchestration_session_entry_id, session_id, ingest_src, ingest_table_name, elaboration)
SELECT
    'ORCSESENID-'||((SELECT COUNT(*) FROM orchestration_session_entry) + 1) AS orchestration_session_entry_id,
    orchestration_session_id,
    'de-identification',
    NULL,
    '{"description": "Processing de-identification"}'
FROM session_info;

-- Create a temporary table
CREATE TEMP TABLE temp_session_info AS
SELECT
    orchestration_session_id,
    (SELECT orchestration_session_entry_id FROM orchestration_session_entry WHERE session_id = orchestration_session_id LIMIT 1) AS orchestration_session_entry_id
FROM orchestration_session
LIMIT 1;

-- Insert into orchestration_session_exec for uniform_resource_investigator
INSERT OR IGNORE INTO orchestration_session_exec (
    orchestration_session_exec_id,
    exec_nature,
    session_id,
    session_entry_id,
    exec_code,
    exec_status,
    input_text,
    output_text,
    exec_error_text,
    narrative_md
)
SELECT
    'ORCHSESSEXID-' || ((SELECT COUNT(*) FROM orchestration_session_exec) + 1 ),
    'De-identification',
    s.orchestration_session_id,
    s.orchestration_session_entry_id,
    'UPDATE uniform_resource_investigator SET email = anonymize_email(email) executed',
    1,
    'email column in uniform_resource_investigator',
    'De-identification completed',
    CASE 
        WHEN (SELECT changes() = 0) THEN 'No rows updated' 
        ELSE NULL 
    END,
    'username in email is masked'
FROM temp_session_info s;

-- Insert into orchestration_session_exec for uniform_resource_author
INSERT OR IGNORE INTO orchestration_session_exec (
    orchestration_session_exec_id,
    exec_nature,
    session_id,
    session_entry_id,
    exec_code,
    exec_status,
    input_text,
    output_text,
    exec_error_text,
    narrative_md
)
SELECT
    'ORCHSESSEXID-' || ((SELECT COUNT(*) FROM orchestration_session_exec) + 1) ,
    'De-identification',
    s.orchestration_session_id,
    s.orchestration_session_entry_id,
    'UPDATE uniform_resource_author SET email = anonymize_email(email) executed',
    1,
    'email column in uniform_resource_author',
    'De-identification completed',
    CASE 
        WHEN (SELECT changes() = 0) THEN 'No rows updated' 
        ELSE NULL 
    END,
    'username in email is masked'
FROM temp_session_info s;

-- Update orchestration_session to set finished timestamp and diagnostics
UPDATE orchestration_session
SET 
    orch_finished_at = CURRENT_TIMESTAMP,
    diagnostics_json = '{"status": "completed"}',
    diagnostics_md = 'De-identification process completed'
WHERE orchestration_session_id = (SELECT orchestration_session_id FROM temp_session_info LIMIT 1);

-- Drop the temporary table when done
DROP TABLE temp_session_info;

-- Commit the transaction
COMMIT;

-- Handle exceptions, errors if any in an external mechanism (not possible through SQLITE)
-- For example:
-- ROLLBACK;
-- INSERT INTO orchestration_session_exec (orchestration_session_exec_id, exec_nature, session_id, exec_code, exec_status, input_text, output_text, exec_error_text, narrative_md)
-- VALUES (
--     'orc-exec-id-' || hex(randomblob(16)),
--     'De-identification',
--     (SELECT orchestration_session_id FROM orchestration_session LIMIT 1),
--     'UPDATE commands executed',
--     1,
--     'Data from uniform_resource_investigator, uniform_resource_author  tables',
--     'Error occurred during de-identification',
--     'Detailed error message here',
--     'Error during update'
-- );
