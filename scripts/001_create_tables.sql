-- Prescripta Database Schema
-- Auto-generated from live database

-- Drop existing tables (reverse dependency order)
DROP TABLE IF EXISTS prescripta_logs CASCADE;
DROP TABLE IF EXISTS flag_severity_configs CASCADE;
DROP TABLE IF EXISTS drug_dosage_limits CASCADE;
DROP TABLE IF EXISTS amp_products CASCADE;
DROP TABLE IF EXISTS vmp_products CASCADE;
DROP TABLE IF EXISTS flags CASCADE;
DROP TABLE IF EXISTS latin_codes CASCADE;
DROP TABLE IF EXISTS bnf_categories CASCADE;

-- BNF Categories (hierarchical)
CREATE TABLE bnf_categories (
    id SERIAL PRIMARY KEY,
    code VARCHAR,
    name VARCHAR,
    parent_id INTEGER REFERENCES bnf_categories(id)
);

-- Flags (LLM Judge error categories)
CREATE TABLE flags (
    id SERIAL PRIMARY KEY,
    code VARCHAR,
    description TEXT,
    examples TEXT
);

-- Latin Codes (prescription abbreviations)
CREATE TABLE latin_codes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) UNIQUE NOT NULL,
    description TEXT NOT NULL,
    examples TEXT
);

-- VMP Products (Virtual Medicinal Products)
CREATE TABLE vmp_products (
    id SERIAL PRIMARY KEY,
    vmp_code VARCHAR NOT NULL,
    vmp_name VARCHAR,
    bnf_id INTEGER REFERENCES bnf_categories(id),
    requires_dosage_check BOOLEAN,
    bnf_dosage_reference TEXT
);

-- AMP Products (Actual Medicinal Products)
CREATE TABLE amp_products (
    id SERIAL PRIMARY KEY,
    amp_code VARCHAR NOT NULL,
    amp_name VARCHAR,
    vmp_id INTEGER REFERENCES vmp_products(id)
);

-- Drug Dosage Limits
CREATE TABLE drug_dosage_limits (
    id SERIAL PRIMARY KEY,
    vmp_id INTEGER REFERENCES vmp_products(id),
    dosage_limit_type TEXT,
    route TEXT,
    age_band TEXT,
    numerator_unit VARCHAR,
    numerator_min_dose DOUBLE PRECISION,
    numerator_max_dose DOUBLE PRECISION,
    denominator_unit VARCHAR,
    denominator_min_dose DOUBLE PRECISION,
    denominator_max_dose DOUBLE PRECISION
);

-- Flag Severity Configs
CREATE TABLE flag_severity_configs (
    id SERIAL PRIMARY KEY,
    bnf_id INTEGER REFERENCES bnf_categories(id),
    flag_id INTEGER REFERENCES flags(id),
    is_red_flag BOOLEAN DEFAULT TRUE,
    annotation_status VARCHAR DEFAULT 'pending',
    annotated_by VARCHAR,
    annotated_at TIMESTAMP
);

-- Prescripta Logs (DDL only - no seed data)
CREATE TABLE prescripta_logs (
    id SERIAL PRIMARY KEY,
    prescription_id VARCHAR(100) NOT NULL,
    pharmacy_code VARCHAR(50),
    request_json JSONB NOT NULL,
    response_json JSONB NOT NULL,
    triage_result BOOLEAN,
    flag_count INTEGER DEFAULT 0,
    total_time_seconds DOUBLE PRECISION,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_prescripta_logs_prescription_id ON prescripta_logs(prescription_id);
