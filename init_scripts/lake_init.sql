CREATE SCHEMA IF NOT EXISTS raw;

-- Watermarks table tracks the last time each entity was extracted
-- This is what makes incremental loading work (no full scans)
CREATE TABLE IF NOT EXISTS raw.watermarks (
    entity_name     VARCHAR(100) PRIMARY KEY,
    last_updated_at TIMESTAMPTZ,
    last_run_at     TIMESTAMPTZ DEFAULT NOW()
);

-- These tables will be created automatically by the extractor
-- when it first runs. But we create the schema here so it's
-- ready before any container tries to connect.