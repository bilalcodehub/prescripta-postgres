-- Prescripta Database Schema
-- LLM Judge Tables

-- BNF Categories (hierarchical)
CREATE TABLE bnf_categories (
    code VARCHAR(20) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    parent_code VARCHAR(20) REFERENCES bnf_categories(code)
);

-- Drugs (DMD code to BNF mapping)
CREATE TABLE drugs (
    dmd_code VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    bnf_code VARCHAR(20) REFERENCES bnf_categories(code)
);

-- Error Codes (48 LLM Judge error categories)
CREATE TABLE error_codes (
    code VARCHAR(50) PRIMARY KEY,
    description TEXT NOT NULL
);

-- Flag Severity Index (BNF category × error code → red flag)
CREATE TABLE flag_severity (
    bnf_code VARCHAR(20) REFERENCES bnf_categories(code),
    error_code VARCHAR(50) REFERENCES error_codes(code),
    is_red_flag BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (bnf_code, error_code)
);

-- Indexes
CREATE INDEX idx_drugs_bnf_code ON drugs(bnf_code);
CREATE INDEX idx_flag_severity_error_code ON flag_severity(error_code);
