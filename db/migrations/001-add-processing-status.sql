-- Migration 001: Add processing status tracking
-- Context: First E2E test (2026-02-14) revealed need to track pipeline stage
-- completion per org and email extraction outcomes per contact.
-- Run with: sqlite3 db/ilg.db < db/migrations/001-add-processing-status.sql

-- Organizations: track enrichment pipeline state
ALTER TABLE organizations ADD COLUMN processing_status TEXT DEFAULT 'discovered';
ALTER TABLE organizations ADD COLUMN enrichment_attempted_at DATETIME;
ALTER TABLE organizations ADD COLUMN enrichment_error_log TEXT;

-- Contacts: track email extraction outcome
ALTER TABLE contacts ADD COLUMN email_status TEXT DEFAULT 'not_checked';

-- Index for filtering orgs by processing status
CREATE INDEX IF NOT EXISTS idx_orgs_processing_status ON organizations(processing_status, vertical_id);

-- Backfill existing records based on current data
UPDATE organizations SET processing_status = 'enriched'
WHERE id IN (SELECT DISTINCT org_id FROM contacts WHERE org_id IS NOT NULL);

UPDATE contacts SET email_status = 'found' WHERE email IS NOT NULL;
UPDATE contacts SET email_status = 'not_found' WHERE email IS NULL;
