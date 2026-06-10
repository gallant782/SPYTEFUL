#!/usr/bin/env bash
# =============================================================================
# MindFrame — Supabase Setup Script
# =============================================================================
# One-command Supabase project bootstrap: creates project, runs migrations,
# enables extensions, seeds data, and outputs connection credentials.
#
# Prerequisites:
#   supabase CLI installed and logged in
#
# Usage:
#   source ./deploy/env-template.sh && ./deploy/supabase-setup.sh
#   ./deploy/supabase-setup.sh --project-name mindframe-prod
#   ./deploy/supabase-setup.sh --dry-run
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINEERING_DIR="$(dirname "$SCRIPT_DIR")"
SQL_DIR="$ENGINEERING_DIR/sql"
SCHEMA_FILE="$ENGINEERING_DIR/schema.sql"

# ─── Defaults ─────────────────────────────────────────────────────────────────
SUPABASE_PROJECT_NAME="mindframe-prod"
SUPABASE_REGION="us-east-1"
SKIP_PROJECT_CREATE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name) SUPABASE_PROJECT_NAME="$2"; shift 2 ;;
    --region) SUPABASE_REGION="$2"; shift 2 ;;
    --skip-create) SKIP_PROJECT_CREATE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

run_sql_file() {
  local label="$1"
  local file="$2"
  info "Migration: $label"
  if [ "$DRY_RUN" = true ]; then
    echo "         (dry-run) would execute: $file"
    return 0
  fi
  supabase db execute --file "$file" || fail "Migration failed: $label"
  ok "  $label ✓"
}

run_sql() {
  local label="$1"
  local sql="$2"
  info "$label"
  if [ "$DRY_RUN" = true ]; then
    echo "   (dry-run) would execute inline SQL"
    return 0
  fi
  echo "$sql" | supabase db execute || fail "SQL failed: $label"
  ok "  ✓"
}

# ─── Step 1: Validate Prerequisites ───────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║     MindFrame — Supabase One-Click Setup     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

info "Step 1/6: Validating prerequisites..."

if ! command -v supabase &> /dev/null; then
  fail "Supabase CLI not found. Install: brew install supabase/tap/supabase"
fi

if [ "$(supabase login --status 2>&1 | grep -c 'logged in')" -eq 0 ] && [ "$DRY_RUN" = false ]; then
  warn "Not logged into Supabase. Running: supabase login"
  supabase login
fi
ok "Supabase CLI ready ($(supabase --version 2>/dev/null || echo 'version unknown'))"

# ─── Step 2: Create Project ───────────────────────────────────────────────────
echo ""
info "Step 2/6: Creating Supabase project..."

if [ "$SKIP_PROJECT_CREATE" = true ]; then
  warn "Skipping project creation (--skip-create)"
  info "Linking to existing project..."
  supabase link --project-ref "$SUPABASE_PROJECT_NAME" 2>/dev/null || \
    warn "Could not link. Ensure SUPABASE_PROJECT_NAME matches your project ref."
else
  if [ -z "${SUPABASE_ORG_ID:-}" ]; then
    warn "SUPABASE_ORG_ID not set. Listing organizations..."
    supabase orgs list
    echo ""
    echo "Set SUPABASE_ORG_ID in env-template.sh and source it, then re-run."
    echo "Example: export SUPABASE_ORG_ID=\"$(supabase orgs list --json 2>/dev/null | python3 -c 'import sys,json; orgs=json.load(sys.stdin); print(orgs[0][\"id\"] if orgs else \"\")' 2>/dev/null)\""
    fail "SUPABASE_ORG_ID is required."
  fi

  if [ -z "${SUPABASE_DB_PASSWORD:-}" ]; then
    warn "SUPABASE_DB_PASSWORD not set. Generating one..."
    SUPABASE_DB_PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)"
    echo "Generated password: $SUPABASE_DB_PASSWORD"
    echo "Save this — it won't be shown again."
  fi

  if [ "$DRY_RUN" = false ]; then
    info "Creating project: $SUPABASE_PROJECT_NAME (region: $SUPABASE_REGION)"
    supabase projects create \
      --name "$SUPABASE_PROJECT_NAME" \
      --org-id "$SUPABASE_ORG_ID" \
      --db-password "$SUPABASE_DB_PASSWORD" \
      --region "$SUPABASE_REGION"
    ok "Project created"

    # Get the project reference ID
    PROJECT_REF=$(supabase projects list --json 2>/dev/null | python3 -c "
import sys, json
projects = json.load(sys.stdin)
for p in projects:
    if p['name'] == '$SUPABASE_PROJECT_NAME':
        print(p['id'])
        break
" 2>/dev/null || echo "")
    
    if [ -n "$PROJECT_REF" ]; then
      info "Linking to project: $PROJECT_REF"
      supabase link --project-ref "$PROJECT_REF" || warn "Link failed — continuing anyway"
      PROJECT_URL="https://$PROJECT_REF.supabase.co"
    fi
  else
    info "(dry-run) Would create project: $SUPABASE_PROJECT_NAME"
  fi
fi

# ─── Step 3: Enable Extensions ────────────────────────────────────────────────
echo ""
info "Step 3/6: Enabling database extensions..."

run_sql "Enabling uuid-ossp" "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
run_sql "Enabling pgcrypto" "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";"
run_sql "Enabling pg_stat_statements" "CREATE EXTENSION IF NOT EXISTS \"pg_stat_statements\";"

# ─── Step 4: Run Migrations ───────────────────────────────────────────────────
echo ""
info "Step 4/6: Running schema migrations..."

MIGRATIONS=(
  "001_core.sql"
  "002_content.sql"
  "003_email.sql"
  "004_commerce.sql"
  "005_analytics.sql"
  "006_affiliates.sql"
  "007_automation.sql"
  "008_indexes.sql"
  "009_rls_policies.sql"
  "010_seed_hooks.sql"
)

for migration in "${MIGRATIONS[@]}"; do
  file="$SQL_DIR/$migration"
  if [ ! -f "$file" ]; then
    fail "Migration file not found: $file"
  fi
  run_sql_file "$migration" "$file"
done

ok "All 10 migrations applied successfully"

# ─── Step 5: Verify Deployment ────────────────────────────────────────────────
echo ""
info "Step 5/6: Verifying deployment..."

if [ "$DRY_RUN" = false ]; then
  VERIFY_SQL="
  SELECT 'viral_hooks' AS tbl, COUNT(*) AS cnt FROM viral_hooks UNION ALL
  SELECT 'profiles', COUNT(*) FROM profiles UNION ALL
  SELECT 'content_templates', COUNT(*) FROM content_templates UNION ALL
  SELECT 'digital_products', COUNT(*) FROM digital_products UNION ALL
  SELECT 'membership_plans', COUNT(*) FROM membership_plans UNION ALL
  SELECT 'email_tags', COUNT(*) FROM email_tags;
  "
  
  echo "$VERIFY_SQL" | supabase db execute --csv 2>/dev/null | while IFS=',' read -r tbl cnt; do
    line="  $tbl: $cnt rows"
    if [ "$cnt" -gt 0 ] 2>/dev/null; then
      echo -e "${GREEN}$line${NC}"
    else
      echo -e "${YELLOW}$line${NC}"
    fi
  done
fi

# ─── Step 6: Output Credentials ───────────────────────────────────────────────
echo ""
info "Step 6/6: Deployment complete!"

# Get the project URL and anon key
if [ "$DRY_RUN" = false ] && [ -n "${PROJECT_REF:-}" ]; then
  info "Fetching API credentials..."
  ANON_KEY=$(supabase projects list --json 2>/dev/null | python3 -c "
import sys, json
projects = json.load(sys.stdin)
for p in projects:
    if p.get('id') == '$PROJECT_REF' or p.get('name') == '$SUPABASE_PROJECT_NAME':
        print(p.get('anon_key', ''))
        break
" 2>/dev/null || echo "N/A")

  SERVICE_KEY=$(supabase projects list --json 2>/dev/null | python3 -c "
import sys, json
projects = json.load(sys.stdin)
for p in projects:
    if p.get('id') == '$PROJECT_REF' or p.get('name') == '$SUPABASE_PROJECT_NAME':
        print(p.get('service_key', ''))
        break
" 2>/dev/null || echo "N/A")

  echo ""
  echo "┌──────────────────────┬──────────────────────────────────────────┐"
  echo "│ Key                  │ Value                                    │"
  echo "├──────────────────────┼──────────────────────────────────────────┤"
  echo "│ Project URL          │ $PROJECT_URL                               │"
  echo "│ Project Ref          │ $PROJECT_REF                               │"
  echo "│ Anon Key (public)    │ ${ANON_KEY:0:20}...${ANON_KEY: -10}        │"
  echo "│ Service Key (secret) │ ${SERVICE_KEY:0:20}...${SERVICE_KEY: -10}  │"
  echo "└──────────────────────┴──────────────────────────────────────────┘"
  echo ""
  echo "  Add these to your env-template.sh:"
  echo "    export MINDFRAME_SUPABASE_URL=\"$PROJECT_URL\""
  echo "    export MINDFRAME_SUPABASE_SERVICE_KEY=\"$SERVICE_KEY\""
  echo ""

  # Save credentials to a tmp file for deploy.sh to read
  echo "MINDFRAME_SUPABASE_URL=$PROJECT_URL" > /tmp/mindframe-supabase-creds
  echo "MINDFRAME_SUPABASE_SERVICE_KEY=$SERVICE_KEY" >> /tmp/mindframe-supabase-creds
fi

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║      ✅  Supabase Setup Complete!            ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Next Steps:"
echo "    1. Copy the credentials above into your .env file"
echo "    2. Run: docker compose -f deploy/docker-compose.yml up -d"
echo "    3. Open http://localhost:5678 and set up n8n"
echo "    4. Import workflows from engineering/workflows/"
echo ""
echo "  Auth Configuration (do in Supabase Dashboard):"
echo "    Authentication → Settings → Site URL:  https://mindframe.ai"
echo "    Authentication → Settings → Redirect URLs:  https://mindframe.ai/**"
echo ""