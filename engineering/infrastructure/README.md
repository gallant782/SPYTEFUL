# MindFrame — Deployment Infrastructure

One-command infrastructure setup for the entire MindFrame automation stack.

## Quick Start

```bash
# 1. Clone the repo and cd to engineering/
cd /home/team/shared/engineering

# 2. Configure environment
cp .env.example .env
vim .env  # Fill in your API keys and secrets

# 3. Launch everything
./scripts/launch.sh
```

That single command:
1. Validates your environment configuration
2. Creates a Supabase project and migrates all 27 tables
3. Seeds 50 viral hooks into the database
4. Launches n8n + PostgreSQL + Redis via Docker Compose
5. Prints a summary of running services

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  n8n (Docker)                        │
│  ┌────────────┐  ┌────────────┐  ┌──────────────┐   │
│  │ PostgreSQL │  │   Redis    │  │   n8n App    │   │
│  │ (n8n state)│  │  (queue)   │  │ (workflows)  │   │
│  └────────────┘  └────────────┘  └──────┬───────┘   │
│                                         │           │
└─────────────────────────────────────────┼───────────┘
                                          │
                    ┌─────────────────────┼──────────────┐
                    │                     │              │
              ┌─────┴─────┐        ┌──────┴──────┐  ┌───┴────┐
              │  Supabase  │        │   Stripe    │  │ Beehiiv │
              │ (Cloud DB) │        │  (Payments) │  │ (Email) │
              └───────────┘        └─────────────┘  └────────┘
```

### Key Decisions

| Component | Why this choice |
|-----------|----------------|
| **Supabase cloud** (not self-hosted) | Free tier for 500MB DB, built-in Auth, RLS, Edge Functions. Managed = no ops burden. |
| **n8n self-hosted** (not cloud) | $0/mo vs $20/mo for n8n cloud. Unlimited workflows. Full control of webhook URLs. |
| **PostgreSQL for n8n** (not SQLite) | Production-grade. Supports concurrent workflows. Can be backed up/replicated. |
| **Redis optional** | Only needed if scaling to queue mode. Single-instance mode (regular) works for launch. |

---

## File Structure

```
engineering/
├── docker-compose.yml           # n8n + PostgreSQL + Redis
├── .env.example                 # All environment variables (template)
├── scripts/
│   ├── launch.sh                # One-command launch (chmod +x)
│   └── setup-supabase.sh        # Supabase project + migration script
└── infrastructure/
    └── n8n/
        └── backup/              # n8n workflow backup directory
```

---

## $ ./scripts/launch.sh

The launch script handles everything:

```
Usage: ./scripts/launch.sh [options]

Options:
  --env-file=FILE.env    Use custom env file
  --skip-supabase        Skip Supabase setup (already deployed)
  --skip-n8n             Skip Docker Compose launch
  --dry-run              Preview actions without executing
```

### What it does step by step:

| Step | Action | Time |
|------|--------|------|
| 0 | Load environment from `.env` | 1s |
| 1 | Validate all required variables are set | 1s |
| 2 | Check Docker + Docker Compose are installed | 1s |
| 3 | Run `setup-supabase.sh` (project creation + migrations) | 2-5 min |
| 4 | Pull Docker images for n8n, PostgreSQL, Redis | 1-2 min |
| 5 | Start PostgreSQL + Redis, wait for healthy | 15s |
| 6 | Start n8n, verify health endpoint | 10s |
| 7 | Print connection summary | 1s |

**Total time:** ~5 minutes

---

## $ ./scripts/setup-supabase.sh

Standalone Supabase setup script (can also be run independently):

```
Usage: ./scripts/setup-supabase.sh [options]

Options:
  --skip-create    Skip project creation (just run migrations)
  --dry-run        Preview actions without executing
```

### Prerequisites

```bash
# Install Supabase CLI
brew install supabase/tap/supabase

# Login
supabase login

# Get your Access Token: https://supabase.com/dashboard/account/tokens
```

### What it does:

1. **Creates a Supabase project** (us-east-1 region, free tier)
2. **Enables extensions**: `uuid-ossp`, `pgcrypto`, `pg_stat_statements`
3. **Runs all 10 migrations** in order (001 → 010)
4. **Seeds 50 viral hooks** into `viral_hooks` table
5. **Verifies** table row counts
6. **Prints next steps** for auth and Stripe configuration

---

## Environment Variables

### Required (must set before launch)

| Variable | Description | Source |
|----------|-------------|--------|
| `N8N_ENCRYPTION_KEY` | 32+ char random string for n8n | Generate with `openssl rand -base64 32` |
| `N8N_DB_PASSWORD` | PostgreSQL password for n8n state DB | Any strong password |
| `MINDFRAME_SUPABASE_URL` | Your Supabase project URL | Supabase Dashboard → Settings → API |
| `MINDFRAME_SUPABASE_SERVICE_KEY` | Supabase service_role key | Supabase Dashboard → Settings → API |
| `MINDFRAME_OPENAI_API_KEY` | OpenAI API key | platform.openai.com/api-keys |
| `MINDFRAME_BEEHIIV_API_KEY` | Beehiiv API key | app.beehiiv.com/settings/integrations |

### Required for Supabase setup

| Variable | Description | Source |
|----------|-------------|--------|
| `SUPABASE_ACCESS_TOKEN` | Supabase CLI access token | supabase.com/dashboard/account/tokens |
| `SUPABASE_ORG_ID` | Organization ID | supabase.com/dashboard/org/YOUR-ORG |
| `SUPABASE_PROJECT_NAME` | Project name (e.g., mindframe-prod) | Choose any name |
| `SUPABASE_DB_PASSWORD` | Database password (32 chars) | Generate a strong one |

### Optional (add after launch)

| Variable | Description |
|----------|-------------|
| `WELCOME_DAY1-5_CAMPAIGN_ID` | Beehiiv campaign IDs for welcome sequence |
| `PURCHASE_WELCOME_CAMPAIGN_ID` | Beehiiv campaign for post-purchase welcome |
| `MEMBERSHIP_WELCOME_CAMPAIGN_ID` | Beehiiv campaign for new membership |
| `CHURN_REMINDER_CAMPAIGN_ID` | Beehiiv campaign for expiry reminders |

---

## Docker Compose Services

| Service | Image | Port | Volume | Purpose |
|---------|-------|------|--------|---------|
| **n8n** | n8nio/n8n:latest | 5678 | n8n_data | Automation workflows |
| **n8n-db** | postgres:15-alpine | 5432 | n8n_db_data | n8n state persistence |
| **n8n-redis** | redis:7-alpine | 6379 | n8n_redis_data | Queue broker (optional) |

### Common Commands

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f n8n

# Check status
docker compose ps

# Stop services
docker compose down

# Stop + delete data (reset)
docker compose down -v

# Restart a single service
docker compose restart n8n

# Backup n8n data
docker compose exec n8n cp -r /home/node/.n8n /backup/n8n-backup-$(date +%Y%m%d)
```

---

## Post-Deployment Checklist

After `./scripts/launch.sh` completes:

- [ ] Open http://localhost:5678 and create n8n admin account
- [ ] Go to Settings → Credentials and add: Supabase, OpenAI, Beehiiv, Stripe
- [ ] Import workflows from `engineering/workflows/*.json`
- [ ] Configure Stripe webhooks in Stripe Dashboard
- [ ] Set n8n environment variables (WELCOME_CAMPAIGN_IDs etc.)
- [ ] Activate each workflow (toggle to "Active")
- [ ] Run verification: `SELECT COUNT(*) FROM viral_hooks;` → 50

---

## Production Deployment

For production (not localhost):

1. **Get a domain** and point DNS to your server
2. **Set up SSL** (Caddy or Nginx + Let's Encrypt):
   ```nginx
   # nginx reverse proxy for n8n
   server {
       listen 443 ssl;
       server_name n8n.mindframe.ai;
       location / {
           proxy_pass http://localhost:5678;
           proxy_set_header Host $host;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```
3. **Update .env**: `N8N_HOST=n8n.mindframe.ai`, `N8N_PROTOCOL=https`
4. **Set Stripe webhooks** to `https://n8n.mindframe.ai/webhook/mindframe/...`
5. **Add monitoring**: UptimeRobot (free) → HTTP check on n8n health endpoint
6. **Configure backups**: Add `crontab -e` entry for daily n8n backup
   ```cron
   0 3 * * * cd /home/team/shared/engineering && docker compose exec n8n cp -r /home/node/.n8n /backup/n8n-$(date +\%Y\%m\%d) && docker compose exec n8n-db pg_dump -U n8n n8n > /backup/n8n-db-$(date +\%Y\%m\%d).sql
   ```

---

## Troubleshooting

### "docker compose: command not found"
```bash
# Install Docker Desktop (includes Compose v2)
# Or install standalone:
sudo apt-get install docker-compose-plugin
```

### "n8n returns 502 Bad Gateway"
```bash
# Check if n8n is running
docker compose ps
# Check n8n logs
docker compose logs n8n
# Restart
docker compose restart n8n
```

### "Supabase project creation fails"
```bash
# Check you're logged in
supabase login --status
# Verify org ID
supabase orgs list
# Retry with verbose output
./scripts/setup-supabase.sh --skip-create 2>&1
```

### "PostgreSQL connection refused"
```bash
# Check if DB container is running
docker compose ps n8n-db
# Check health
docker compose exec n8n-db pg_isready -U n8n
# Restart
docker compose restart n8n-db
```

### "Workflow imports fail in n8n"
The JSON exports use n8n's standard format. If import fails:
1. Open the JSON file and validate it: `python3 -c "import json; json.load(open('workflow.json'))"`
2. Check n8n version: the exports target n8n 1.x
3. Try importing via n8n API if UI fails:
   ```bash
   curl -X POST http://localhost:5678/rest/workflows \
     -H "Content-Type: application/json" \
     -H "Cookie: n8n-auth=..." \
     -d @workflow.json
   ```