# Prescripta PostgreSQL Backend

Standalone PostgreSQL 16 database for the Prescripta multi-agent prescription checking system.

This package contains everything needed to deploy the database from scratch on any Linux or macOS server with Docker.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Folder Structure](#folder-structure)
3. [Installation](#installation)
4. [Verifying the Installation](#verifying-the-installation)
5. [Connection Details](#connection-details)
6. [Configuring Prescripta](#configuring-prescripta-to-connect)
7. [Database Schema](#database-schema)
8. [Data Persistence](#data-persistence)
9. [Backup & Restore](#backup--restore)
10. [Maintenance](#maintenance)
11. [Troubleshooting](#troubleshooting)
12. [Uninstalling](#uninstalling)

---

## Prerequisites

### 1. Docker Engine

Install Docker on your server. Choose your OS:

**Ubuntu / Debian:**
```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

**macOS:**
Download and install [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/).

**Windows (WSL2):**
Download and install [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/) with WSL2 backend enabled.

### 2. Verify Docker is running

```bash
docker --version
docker compose version
```

You should see version numbers for both. If `docker compose` is not found, install the compose plugin:
```bash
sudo apt install -y docker-compose-plugin
```

### 3. (Optional) Allow non-root Docker access

```bash
sudo usermod -aG docker $USER
# Log out and back in for this to take effect
```

---

## Folder Structure

```
prescripta-postgres/
├── README.md                  # This file
├── docker-compose.yml         # Docker service definition
├── .env.example               # Template for environment variables
├── .gitignore                 # Excludes .env, pgdata/, backups/ from git
├── scripts/
│   ├── 001_create_tables.sql  # Database schema (DDL)
│   └── 002_seed_data.sql      # Reference data (INSERT statements)
├── pgdata/                    # [auto-created] PostgreSQL data directory
└── backups/                   # [auto-created] Backup storage
```

> **Note:** The `pgdata/` and `backups/` directories are created automatically. Do not commit them to version control.

---

## Installation

### Step 1: Place the folder on your server

Copy the entire `prescripta-postgres/` folder to your server, e.g.:

```bash
scp -r prescripta-postgres/ user@your-server:/opt/prescripta-postgres
```

Or clone from your repository if applicable.

### Step 2: Navigate to the folder

```bash
cd /opt/prescripta-postgres
```

### Step 3: Configure credentials

Copy the example environment file and **change the password**:

```bash
cp .env.example .env
```

Edit `.env` with your preferred editor:

```bash
nano .env
```

Set a strong password:

```env
POSTGRES_USER=prescripta_admin
POSTGRES_PASSWORD=your_strong_password_here
POSTGRES_DB=prescripta_db
```

> ⚠️ **SECURITY**: Never use the default password in production. Use a password with at least 16 characters including uppercase, lowercase, numbers, and symbols.

### Step 4: Start the database

```bash
docker compose up -d
```

This will:
1. Pull the `postgres:16-alpine` image (~80MB) if not already present
2. Create the `pgdata/` directory for persistent storage
3. Run `scripts/001_create_tables.sql` to create the schema
4. Run `scripts/002_seed_data.sql` to load reference data (~67MB, may take 1–3 minutes)
5. Start PostgreSQL listening on port **11001**

> **Important:** The init scripts in `scripts/` only run on **first start** (when `pgdata/` does not yet exist). If you need to re-initialise, see [Troubleshooting](#troubleshooting).

### Step 5: Monitor startup progress

```bash
# Watch logs until you see "database system is ready to accept connections"
docker compose logs -f
```

Press `Ctrl+C` to stop following logs once the database is ready.

---

## Verifying the Installation

### Check container health

```bash
docker compose ps
```

You should see `prescripta-postgres` with status **healthy**.

### Test the connection

```bash
docker exec -it prescripta-postgres psql -U prescripta_admin -d prescripta_db -c "\dt"
```

Expected output — 8 tables:

| Table                  | Description                           |
|------------------------|---------------------------------------|
| `bnf_categories`       | BNF drug classification hierarchy     |
| `flags`                | LLM Judge error flag definitions      |
| `latin_codes`          | Prescription Latin abbreviations      |
| `vmp_products`         | Virtual Medicinal Products (VMP)      |
| `amp_products`         | Actual Medicinal Products (AMP)       |
| `drug_dosage_limits`   | Dosage safety limits per drug         |
| `flag_severity_configs`| BNF × flag → red flag severity matrix |
| `prescripta_logs`      | API request/response audit log        |

### Verify row counts

```bash
docker exec -it prescripta-postgres psql -U prescripta_admin -d prescripta_db -c "
  SELECT 'bnf_categories' as table_name, count(*) FROM bnf_categories
  UNION ALL SELECT 'flags', count(*) FROM flags
  UNION ALL SELECT 'latin_codes', count(*) FROM latin_codes
  UNION ALL SELECT 'vmp_products', count(*) FROM vmp_products
  UNION ALL SELECT 'amp_products', count(*) FROM amp_products
  UNION ALL SELECT 'drug_dosage_limits', count(*) FROM drug_dosage_limits
  UNION ALL SELECT 'flag_severity_configs', count(*) FROM flag_severity_configs
  ORDER BY 1;
"
```

Expected counts:

| Table                  | Rows    |
|------------------------|---------|
| `amp_products`         | 91,471  |
| `bnf_categories`       | 515     |
| `drug_dosage_limits`   | 62,276  |
| `flag_severity_configs`| 26,780  |
| `flags`                | 51      |
| `latin_codes`          | 56      |
| `vmp_products`         | 19,435  |

---

## Connection Details

| Setting    | Value                                   |
|------------|-----------------------------------------|
| Host       | `localhost` or your server's IP address |
| Port       | `11001`                                 |
| Database   | `prescripta_db`                         |
| User       | `prescripta_admin`                      |
| Password   | *(as set in your `.env` file)*          |

**Connection URL:**
```
postgresql://prescripta_admin:<your_password>@<host>:11001/prescripta_db
```

**Example (Python with psycopg2):**
```python
import psycopg2
conn = psycopg2.connect(
    host="your-server-ip",
    port=11001,
    database="prescripta_db",
    user="prescripta_admin",
    password="your_password"
)
```

### Remote Access

If connecting from another machine, ensure port `11001` is open in your firewall:

```bash
# UFW (Ubuntu)
sudo ufw allow 11001/tcp

# firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=11001/tcp
sudo firewall-cmd --reload
```

If using ngrok for tunnelling:
```bash
ngrok tcp 11001
```

### Configuring Prescripta to Connect

Once the database is running, you **must** update the Prescripta application config to point to it. Edit `prescripta/config/config.yml` and set the `database` section to the **IP address or domain name** and **port** of the server running this database:

```yaml
database:
  host: <your-database-server-ip-or-domain>
  port: 11001
  name: prescripta_db
  user: prescripta_admin
  password: <your_password_from_.env>
```

**Examples (AWS EC2):**

- If Prescripta and the database run on the **same EC2 instance**: use `host: localhost`
- If Prescripta runs on a **different EC2 instance**, use the database server's **private IP** (e.g. `host: 10.0.1.45`) if both are in the same VPC, or the **public IP / Elastic IP** if they are not
- If using a **custom domain** (e.g. via Route 53): use `host: db.prescripta.example.com`

> ⚠️ **Important:** The `password` in `prescripta/config/config.yml` must match the `POSTGRES_PASSWORD` you set in the `.env` file. If you change one, update the other.

> 🔒 **AWS Security:** Ensure port `11001` is open in the EC2 **Security Group** inbound rules, but **only** to the IP addresses or security groups of the Prescripta application servers — do not open it to `0.0.0.0/0`.

---

## Database Schema

### Entity Relationship Overview

```
bnf_categories (self-referencing hierarchy)
    ├── vmp_products.bnf_id → bnf_categories.id
    │       ├── amp_products.vmp_id → vmp_products.id
    │       └── drug_dosage_limits.vmp_id → vmp_products.id
    └── flag_severity_configs.bnf_id → bnf_categories.id

flags
    └── flag_severity_configs.flag_id → flags.id

latin_codes (standalone)
prescripta_logs (standalone)
```

### Table Details

**`bnf_categories`** — British National Formulary classification hierarchy
- `id` SERIAL PRIMARY KEY
- `code` VARCHAR — BNF code (e.g. "01.01.01")
- `name` VARCHAR — Category name
- `parent_id` INTEGER → self-referencing FK

**`flags`** — LLM Judge error flag definitions
- `id` SERIAL PRIMARY KEY
- `code` VARCHAR — Flag code
- `description` TEXT — What this flag means
- `examples` TEXT — Example triggers

**`latin_codes`** — Prescription Latin abbreviations (e.g. "bd" = "twice daily")
- `id` SERIAL PRIMARY KEY
- `code` VARCHAR(20) UNIQUE NOT NULL
- `description` TEXT NOT NULL
- `examples` TEXT

**`vmp_products`** — Virtual Medicinal Products
- `id` SERIAL PRIMARY KEY
- `vmp_code` VARCHAR NOT NULL — DMD VMP code
- `vmp_name` VARCHAR — Product name
- `bnf_id` INTEGER → `bnf_categories.id`
- `requires_dosage_check` BOOLEAN
- `bnf_dosage_reference` TEXT

**`amp_products`** — Actual Medicinal Products
- `id` SERIAL PRIMARY KEY
- `amp_code` VARCHAR NOT NULL — DMD AMP code
- `amp_name` VARCHAR — Product name
- `vmp_id` INTEGER → `vmp_products.id`

**`drug_dosage_limits`** — Dosage safety limits
- `id` SERIAL PRIMARY KEY
- `vmp_id` INTEGER → `vmp_products.id`
- `dosage_limit_type` TEXT
- `route` TEXT — Administration route
- `age_band` TEXT — Patient age group
- `numerator_unit` VARCHAR, `numerator_min_dose` FLOAT, `numerator_max_dose` FLOAT
- `denominator_unit` VARCHAR, `denominator_min_dose` FLOAT, `denominator_max_dose` FLOAT

**`flag_severity_configs`** — Severity matrix (BNF category × flag → red flag?)
- `id` SERIAL PRIMARY KEY
- `bnf_id` INTEGER → `bnf_categories.id`
- `flag_id` INTEGER → `flags.id`
- `is_red_flag` BOOLEAN (default TRUE)
- `annotation_status` VARCHAR (default 'pending')
- `annotated_by` VARCHAR
- `annotated_at` TIMESTAMP

**`prescripta_logs`** — API audit log
- `id` SERIAL PRIMARY KEY
- `prescription_id` VARCHAR(100) NOT NULL (indexed)
- `pharmacy_code` VARCHAR(50)
- `request_json` JSONB NOT NULL
- `response_json` JSONB NOT NULL
- `triage_result` BOOLEAN
- `flag_count` INTEGER (default 0)
- `total_time_seconds` FLOAT
- `created_at` TIMESTAMP (default CURRENT_TIMESTAMP)

---

## Data Persistence

PostgreSQL data is stored in `./pgdata/` on the host machine, mapped into the container. This means:

- ✅ Data **survives** container restarts (`docker compose restart`)
- ✅ Data **survives** container recreation (`docker compose down && docker compose up -d`)
- ✅ Data **survives** Docker image updates
- ❌ Data is **lost** if `./pgdata/` is manually deleted

> **Important:** Do NOT delete the `pgdata/` folder unless you intend to completely reset the database. Always back up first.

---

## Backup & Restore

### Create a backup

**Full database dump (recommended):**
```bash
mkdir -p backups
docker exec prescripta-postgres pg_dump -U prescripta_admin -d prescripta_db \
  --format=custom --compress=9 \
  -f /tmp/prescripta_backup.dump

docker cp prescripta-postgres:/tmp/prescripta_backup.dump \
  ./backups/prescripta_$(date +%Y%m%d_%H%M%S).dump
```

**SQL text dump (human-readable):**
```bash
mkdir -p backups
docker exec prescripta-postgres pg_dump -U prescripta_admin -d prescripta_db \
  > ./backups/prescripta_$(date +%Y%m%d_%H%M%S).sql
```

### Automated daily backups (cron)

Create a backup script:

```bash
cat > backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="$(dirname "$0")/backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

docker exec prescripta-postgres pg_dump -U prescripta_admin -d prescripta_db \
  --format=custom --compress=9 \
  -f /tmp/prescripta_backup.dump

docker cp prescripta-postgres:/tmp/prescripta_backup.dump \
  "$BACKUP_DIR/prescripta_${TIMESTAMP}.dump"

# Keep only last 7 daily backups
ls -tp "$BACKUP_DIR"/prescripta_*.dump | tail -n +8 | xargs -r rm --
echo "[$(date)] Backup completed: prescripta_${TIMESTAMP}.dump"
EOF
chmod +x backup.sh
```

Add to cron (runs daily at 2 AM):
```bash
crontab -e
# Add this line:
0 2 * * * /opt/prescripta-postgres/backup.sh >> /opt/prescripta-postgres/backups/backup.log 2>&1
```

### Restore from backup

**From a `.dump` file (custom format):**
```bash
docker cp ./backups/prescripta_XXXXXXXX_XXXXXX.dump prescripta-postgres:/tmp/restore.dump

docker exec prescripta-postgres pg_restore -U prescripta_admin -d prescripta_db \
  --clean --if-exists /tmp/restore.dump
```

**From a `.sql` file:**
```bash
cat ./backups/prescripta_XXXXXXXX_XXXXXX.sql | \
  docker exec -i prescripta-postgres psql -U prescripta_admin -d prescripta_db
```

---

## Maintenance

### View logs

```bash
# Last 100 lines
docker compose logs --tail=100

# Follow live logs
docker compose logs -f
```

### Restart the database

```bash
docker compose restart
```

### Stop the database

```bash
docker compose down
```

> This stops the container but **preserves all data** in `pgdata/`.

### Update PostgreSQL image

```bash
docker compose down
docker compose pull
docker compose up -d
```

### Check disk usage

```bash
# Data directory size
du -sh ./pgdata/

# Database size from inside PostgreSQL
docker exec -it prescripta-postgres psql -U prescripta_admin -d prescripta_db -c "
  SELECT pg_size_pretty(pg_database_size('prescripta_db')) as db_size;
"

# Per-table sizes
docker exec -it prescripta-postgres psql -U prescripta_admin -d prescripta_db -c "
  SELECT relname as table, pg_size_pretty(pg_total_relation_size(relid)) as size
  FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;
"
```

### Run VACUUM (reclaim space after large deletes)

```bash
docker exec -it prescripta-postgres psql -U prescripta_admin -d prescripta_db -c "VACUUM ANALYZE;"
```

---

## Troubleshooting

### Container won't start

```bash
# Check logs for errors
docker compose logs

# Check if port 11001 is already in use
sudo lsof -i :11001
# or
sudo ss -tlnp | grep 11001
```

### Connection refused

1. Check the container is running: `docker compose ps`
2. Check it's healthy: look for `(healthy)` in the status
3. Check firewall allows port 11001
4. If connecting remotely, use the server's IP, not `localhost`

### Re-initialise the database from scratch

The init scripts only run when `pgdata/` does not exist. To start fresh:

```bash
# ⚠️ THIS DELETES ALL DATA — back up first!
docker compose down
sudo rm -rf ./pgdata
docker compose up -d
```

This will re-run `001_create_tables.sql` and `002_seed_data.sql`.

### "Permission denied" on pgdata

```bash
sudo chown -R 70:70 ./pgdata
```

(UID 70 is the `postgres` user inside the Alpine container.)

### Seed data takes too long

The `002_seed_data.sql` file is ~67MB with ~200K INSERT statements. On first start, this may take 1–3 minutes depending on your server. Monitor progress with:

```bash
docker compose logs -f
```

---

## Uninstalling

### Remove container only (keep data)

```bash
docker compose down
```

### Remove everything (including all data)

```bash
docker compose down
sudo rm -rf ./pgdata
docker rmi postgres:16-alpine
```

---

## Support

For issues or questions, contact the Prescripta development team.
