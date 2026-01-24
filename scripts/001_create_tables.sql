-- Prescripta Database Schema
-- Drop existing tables (reverse dependency order)
DROP TABLE IF EXISTS flag_severity CASCADE;
DROP TABLE IF EXISTS drugs CASCADE;
DROP TABLE IF EXISTS error_codes CASCADE;
DROP TABLE IF EXISTS bnf_categories CASCADE;

-- BNF Categories (hierarchical)
CREATE TABLE bnf_categories (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    parent_id INTEGER REFERENCES bnf_categories(id)
);

-- Error Codes (48 LLM Judge error categories)
CREATE TABLE error_codes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    description TEXT NOT NULL,
    examples TEXT
);

-- Latin Codes (56 prescription abbreviations)
CREATE TABLE latin_codes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) UNIQUE NOT NULL,
    description TEXT NOT NULL,
    examples TEXT
);

-- Drugs (DMD code to BNF mapping)
CREATE TABLE drugs (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    bnf_id INTEGER REFERENCES bnf_categories(id)
);

-- Flag Severity Index (BNF × Error Code → is_red_flag)
CREATE TABLE flag_severity (
    bnf_id INTEGER REFERENCES bnf_categories(id),
    error_id INTEGER REFERENCES error_codes(id),
    is_red_flag BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (bnf_id, error_id)
);

-- Drug Limits (dosage safety thresholds)
CREATE TABLE drug_limits (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL,
    drug VARCHAR(255) NOT NULL,
    dosage_limit_type VARCHAR(20) NOT NULL,
    route VARCHAR(50) NOT NULL,
    age_band VARCHAR(20) NOT NULL,
    dosage_unit VARCHAR(20) NOT NULL,
    dosage_lower_limit FLOAT,
    dosage_upper_limit FLOAT,
    source TEXT,
    crawl_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Prescripta Logs (request/response logging)
CREATE TABLE prescripta_logs (
    id SERIAL PRIMARY KEY,
    prescription_id VARCHAR(100) NOT NULL,
    pharmacy_code VARCHAR(50),
    request_json JSONB NOT NULL,
    response_json JSONB NOT NULL,
    triage_result BOOLEAN,
    flag_count INTEGER DEFAULT 0,
    total_time_seconds FLOAT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_bnf_categories_code ON bnf_categories(code);
CREATE INDEX idx_error_codes_code ON error_codes(code);
CREATE INDEX idx_drugs_bnf_id ON drugs(bnf_id);
CREATE INDEX idx_flag_severity_bnf_id ON flag_severity(bnf_id);
CREATE INDEX idx_flag_severity_error_id ON flag_severity(error_id);
CREATE INDEX idx_drug_limits_lookup ON drug_limits(code, route, age_band);
