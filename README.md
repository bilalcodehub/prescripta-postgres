# Prescripta PostgreSQL Backend

Standalone PostgreSQL database for the Prescripta multi-agent system.

## Quick Start

```bash
# Copy and configure environment
cp .env.example .env

# Start the database
docker compose up -d

# Check status
docker compose ps
```

## Connection

| Setting | Value |
|---------|-------|
| Host | `localhost` (or server IP) |
| Port | `11001` |
| Database | `prescripta_db` |
| User | `prescripta_admin` |

**Connection URL:**
```
postgresql://prescripta_admin:prescripta_secret@localhost:11001/prescripta_db
```

## Data Persistence

Data is stored in `./pgdata/` and persists across container restarts.

## Tables

- `bnf_categories` — BNF hierarchy
- `drugs` — DMD code to BNF mapping
- `error_codes` — 48 LLM Judge error categories
- `flag_severity` — BNF × error code → red flag severity
