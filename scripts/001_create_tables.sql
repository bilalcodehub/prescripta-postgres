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
    parent_code VARCHAR(20) REFERENCES bnf_categories(code)
);

-- Error Codes (48 LLM Judge error categories)
CREATE TABLE error_codes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    description TEXT NOT NULL
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

-- Indexes for performance
CREATE INDEX idx_bnf_categories_code ON bnf_categories(code);
CREATE INDEX idx_error_codes_code ON error_codes(code);
CREATE INDEX idx_drugs_bnf_id ON drugs(bnf_id);
CREATE INDEX idx_flag_severity_bnf_id ON flag_severity(bnf_id);
CREATE INDEX idx_flag_severity_error_id ON flag_severity(error_id);
