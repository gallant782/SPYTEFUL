#!/usr/bin/env bash
# =============================================================================
# MindFrame — Supabase Setup Script
# =============================================================================
# Automates: project creation, schema migration, seed data, auth config
#
# Prerequisites:
#   1. Install Supabase CLI:  brew install supabase/tap/supabase
#   2. Create a Supabase access token: https://supabase.com/dashboard/account/tokens
#   3. Run:  supabase login
#   4. Copy .env.example → .env and fill in SUPABASE_* vars
#
# Usage:
#   ./scripts/setup-supabase.sh              # Full automated setup
#   ./scripts/setup-supabase.sh --skip-create # Skip project creation, just run migrations
#   ./scripts/setup-supabase.sh --dry-run     # Show what would happen, don't execute
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINEERING_DIR="$(dirname "$SCRIPT_DIR")"
SQL_DIR="$ENGINEERING_DIR/sql"
SCHEMA_FILE="$ENGINEERING_DIR/schema.sql"

# Load .env if present
if [ -f "$ENGINEERING_DIR/.env" ]; then
  set -a
  source "$ENGINEERING_DIR/.env"
  set +a
fi

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ─── Flags ────────────────────────────────────────────────────────────────────
SKIP_CREATE=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --skip-create) SKIP_CREATE=true ;;
    --dry-run) DRY_RUN=true ;;
  esac
done

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

run_sql() {
  local label="$1"
  local file="$2"
  info "Running: $label..."
  if [ "$DRY_RUN" = true ]; then
    echo "        Would execute: $file"
    return 0
  fi
  supabase db execute --file "$file" || fail "Failed: $label"
  ok "$label ✓"
}

run_raw_sql() {
  local label="$1"
  local sql="$2"
  info "Running: $label..."
  if [ "$DRY_RUN" = true ]; then
    echo "        Would execute SQL inline"
    return 0
  fi
  echo "$sql" | supabase db execute || fail "Failed: $label"
  ok "$label ✓"
}

# ─── Validation ────────────────────────────────────────────────────────────────
info "Checking prerequisites..."

if ! command -v supabase &> /dev/null; then
  fail "Supabase CLI not found. Install: brew install supabase/tap/supabase"
fi

if ! supabase login --status &> /dev/null; then
  warn "Not logged into Supabase. Run: supabase login"
  exit 1
fi
ok "Supabase CLI ready"

# ─── Step 1: Create Project ──────────────────────────────────────────────────
if [ "$SKIP_CREATE" = false ]; then
  if [ -z "${SUPABASE_PROJECT_NAME:-}" ]; then
    fail "SUPABASE_PROJECT_NAME not set. Add it to your .env file."
  fi
  if [ -z "${SUPABASE_ORG_ID:-}" ]; then
    fail "SUPABASE_ORG_ID not set. Add it to your .env file."
  fi
  if [ -z "${SUPABASE_DB_PASSWORD:-}" ]; then
    fail "SUPABASE_DB_PASSWORD not set. Add it to your .env file."
  fi

  info "Creating Supabase project: $SUPABASE_PROJECT_NAME ..."
  if [ "$DRY_RUN" = false ]; then
    supabase projects create \
      --name "$SUPABASE_PROJECT_NAME" \
      --org-id "$SUPABASE_ORG_ID" \
      --db-password "$SUPABASE_DB_PASSWORD" \
      --region us-east-1
    ok "Project '$SUPABASE_PROJECT_NAME' created"

    # Link local project to remote
    supabase link --project-ref "$SUPABASE_PROJECT_NAME"
    ok "Local project linked to remote"
  else
    echo "        Would create project: $SUPABASE_PROJECT_NAME"
  fi
else
  warn "Skipping project creation (--skip-create)"
fi

echo ""
info "============================================="
info "  Migrating Database Schema"
info "============================================="
echo ""

# ─── Step 2: Enable Extensions ───────────────────────────────────────────────
run_raw_sql "Enabling uuid-ossp" "
  CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";
  CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";
  CREATE EXTENSION IF NOT EXISTS \"pg_stat_statements\";
"

# ─── Step 3: Run Migrations in Order ─────────────────────────────────────────
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
  run_sql "$migration" "$file"
done

# ─── Step 4: Verify ──────────────────────────────────────────────────────────
echo ""
info "============================================="
info "  Verifying Deployment"
info "============================================="
echo ""

VERIFY_SQL="
SELECT 'viral_hooks' AS table_name, COUNT(*) AS row_count FROM viral_hooks
UNION ALL
SELECT 'profiles', COUNT(*) FROM profiles
UNION ALL
SELECT 'content_templates', COUNT(*) FROM content_templates
UNION ALL
SELECT 'digital_products', COUNT(*) FROM digital_products
UNION ALL
SELECT 'membership_plans', COUNT(*) FROM membership_plans
UNION ALL
SELECT 'automation_workflows', COUNT(*) FROM automation_workflows
UNION ALL
SELECT 'email_tags', COUNT(*) FROM email_tags
ORDER BY table_name;
"

if [ "$DRY_RUN" = false ]; then
  echo "$VERIFY_SQL" | supabase db execute --csv 2>/dev/null | while IFS=',' read -r table count; do
    echo "  $table: $count rows"
  done
else
  echo "  Would verify table row counts"
fi

# ─── Step 5: Configure Auth ──────────────────────────────────────────────────
echo ""
info "============================================="
info "  Configuring Authentication"
info "============================================="
echo ""

AUTH_SQL="
-- Enable email + password auth (Supabase default)
-- Site URL for redirects
SELECT 1 FROM (VALUES (1)) AS t WHERE NOT EXISTS (
  SELECT 1 FROM auth.config WHERE id = 1
);

-- Note: Auth provider config must be done in Supabase Dashboard:
--   Authentication → Settings → Site URL:       https://mindframe.ai
--   Authentication → Settings → Redirect URLs:   https://mindframe.ai/**
--   Authentication → Providers → Email:          Enable confirm email (recommended)
"
run_raw_sql "Auth config notes" "SELECT 'Auth configuration: Set Site URL in Supabase Dashboard → Authentication → Settings' AS info;"

# ─── Done ────────────────────────────────────────────────────────────────────
echo ""
info "============================================="
info "  ✅  Supabase Setup Complete!"
info "============================================="
echo ""
echo "  Next steps:"
echo "    1. Go to Supabase Dashboard → Authentication → Settings"
echo "       Set Site URL: https://mindframe.ai"
echo ""
echo "    2. Go to Supabase Dashboard → SQL Editor"
echo "       Run your first query: SELECT * FROM analytics_daily_metrics;"
echo ""
echo "    3. Import n8n workflows:"
echo "       docker compose up -d"
echo "       Open http://localhost:5678"
echo "       Import workflows from engineering/workflows/*.json"
echo ""
echo "    4. Configure Stripe webhooks:"
echo "       Endpoint: https://your-n8n-host/webhook/mindframe/stripe-purchase"
echo "       Events: checkout.session.completed, customer.subscription.*"
echo ""

# Create a marker file
if [ "$DRY_RUN" = false ]; then
  date > "$ENGINEERING_DIR/.supabase-deployed"
  ok "Deployment marker created at .supabase-deployed"
fi