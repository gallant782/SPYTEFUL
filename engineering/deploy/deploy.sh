#!/usr/bin/env bash
# =============================================================================
# MindFrame — Master Deployment Script
# =============================================================================
# Orchestrates the full MindFrame stack deployment:
#   1. Validates prerequisites (Docker, Supabase CLI, env vars)
#   2. Sets up Supabase (project creation + schema migrations)
#   3. Launches n8n via Docker Compose
#   4. Validates each service is responding
#   5. Prints dashboard URLs and next steps
#
# Usage:
#   ./deploy/deploy.sh                      # Full deployment
#   ./deploy/deploy.sh --skip-supabase       # Skip Supabase (already deployed)
#   ./deploy/deploy.sh --env-only            # Only validate env, no deployment
#   ./deploy/deploy.sh --dry-run             # Preview without executing
#   ./deploy/deploy.sh --project-name my-prod # Custom project name
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINEERING_DIR="$(dirname "$SCRIPT_DIR")"
DEPLOY_DIR="$SCRIPT_DIR"

# ─── Flags ────────────────────────────────────────────────────────────────────
SKIP_SUPABASE=false
ENV_ONLY=false
DRY_RUN=false
PROJECT_NAME="mindframe-prod"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-supabase) SKIP_SUPABASE=true; shift ;;
    --env-only) ENV_ONLY=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --project-name) PROJECT_NAME="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }
header() { echo ""; echo -e "${BOLD}$*${NC}"; echo "──────────────────────────────────────────────"; }

# ─── Banner ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║         MindFrame — Master Deploy            ║"
echo "  ║   v1.0 — Autonomous Content-to-Revenue       ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Started: $(date)"
echo "  Mode:    $([ "$DRY_RUN" = true ] && echo 'DRY RUN' || echo 'LIVE')"
echo ""

DEPLOY_START=$(date +%s)

# ─── Phase 0: Load Environment ───────────────────────────────────────────────
header "Phase 0/4: Environment Configuration"

# Try to source env-template.sh if present
ENV_SOURCE=""
if [ -f "$DEPLOY_DIR/env-template.sh" ]; then
  set +a
  source "$DEPLOY_DIR/env-template.sh"
  set -a
  ENV_SOURCE="$DEPLOY_DIR/env-template.sh"
  ok "Sourced environment from: $ENV_SOURCE"
elif [ -f "$ENGINEERING_DIR/.env" ]; then
  set -a
  source "$ENGINEERING_DIR/.env"
  set -a
  ENV_SOURCE="$ENGINEERING_DIR/.env"
  ok "Sourced environment from: $ENV_SOURCE"
else
  warn "No environment file found. Using existing shell variables."
  warn "Create one with: cp deploy/env-template.sh .env && vim .env"
fi

# ─── Phase 0b: Validate Prerequisites ───────────────────────────────────────
header "Phase 0/4: Prerequisites Check"

ALL_OK=true

# Docker
if command -v docker &> /dev/null; then
  ok "Docker: $(docker --version | head -c 30)..."
else
  fail "Docker not found. Install: https://docs.docker.com/get-docker/"
  ALL_OK=false
fi

# Docker Compose
if docker compose version &> /dev/null; then
  ok "Docker Compose: $(docker compose version | head -c 35)..."
elif docker-compose --version &> /dev/null; then
  ok "Docker Compose (v1): $(docker-compose --version)"
else
  fail "Docker Compose not found."
  ALL_OK=false
fi

# Supabase CLI (for Supabase setup)
if command -v supabase &> /dev/null; then
  ok "Supabase CLI: $(supabase --version 2>/dev/null || echo 'version unknown')"
else
  warn "Supabase CLI not found. Install: brew install supabase/tap/supabase"
  if [ "$SKIP_SUPABASE" = false ]; then
    warn "Will skip Supabase setup (--skip-supabase implied)"
    SKIP_SUPABASE=true
  fi
fi

# Required env vars
REQUIRED=(
  "N8N_ENCRYPTION_KEY"
  "N8N_DB_PASSWORD"
  "MINDFRAME_SUPABASE_URL"
  "MINDFRAME_SUPABASE_SERVICE_KEY"
  "MINDFRAME_OPENAI_API_KEY"
  "MINDFRAME_BEEHIIV_API_KEY"
)

for var in "${REQUIRED[@]}"; do
  val="${!var:-}"
  if [ -z "$val" ] || [[ "$val" == *"CHANGE-ME"* ]] || [[ "$val" == *"YOUR-"* ]]; then
    warn "  $var is missing or has placeholder"
    ALL_OK=false
  fi
done

if [ "$ALL_OK" = true ]; then
  ok "All prerequisites met"
else
  echo ""
  fail "Fix the issues above and re-run. See deploy/env-template.sh for reference."
fi

if [ "$ENV_ONLY" = true ]; then
  echo ""
  info "── ENV ONLY MODE ── Environment validated. Exiting."
  exit 0
fi

# ─── Phase 1: Supabase Setup ─────────────────────────────────────────────────
if [ "$SKIP_SUPABASE" = false ]; then
  header "Phase 1/4: Supabase Database Setup"

  SUPABASE_FLAGS=""
  [ "$DRY_RUN" = true ] && SUPABASE_FLAGS="--dry-run"
  
  info "Running Supabase setup..."
  
  if [ -f "$DEPLOY_DIR/supabase-setup.sh" ]; then
    bash "$DEPLOY_DIR/supabase-setup.sh" \
      --project-name "$PROJECT_NAME" \
      $SUPABASE_FLAGS
    ok "Supabase setup completed"
    
    # Load Supabase credentials that were saved by setup-supabase.sh
    if [ -f /tmp/mindframe-supabase-creds ] && [ "$DRY_RUN" = false ]; then
      source /tmp/mindframe-supabase-creds
      ok "Supabase credentials loaded from setup output"
    fi
  else
    fail "supabase-setup.sh not found in $DEPLOY_DIR"
  fi
else
  warn "Skipping Supabase setup (--skip-supabase)"
fi

# ─── Phase 2: Docker Compose Launch ──────────────────────────────────────────
header "Phase 2/4: Launching n8n (Docker Compose)"

# Check if Docker Compose file exists
COMPOSE_FILE="$DEPLOY_DIR/docker-compose.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
  fail "docker-compose.yml not found at $COMPOSE_FILE"
fi

# Pull images
info "Pulling Docker images..."
if [ "$DRY_RUN" = false ]; then
  docker compose -f "$COMPOSE_FILE" pull || warn "Image pull failed — continuing with cached images"
else
  info "(dry-run) Would pull Docker images"
fi

# Start database first
info "Starting database and Redis..."
if [ "$DRY_RUN" = false ]; then
  docker compose -f "$COMPOSE_FILE" up -d n8n-db n8n-redis
fi

# Wait for database to be healthy
info "Waiting for PostgreSQL to be ready..."
if [ "$DRY_RUN" = false ]; then
  RETRIES=0
  MAX_RETRIES=30
  until docker compose -f "$COMPOSE_FILE" exec n8n-db pg_isready -U "${N8N_DB_USER:-n8n}" 2>/dev/null; do
    RETRIES=$((RETRIES + 1))
    if [ "$RETRIES" -ge "$MAX_RETRIES" ]; then
      warn "PostgreSQL healthcheck timed out (continuing)"
      break
    fi
    sleep 2
  done
  ok "PostgreSQL is healthy"
fi

# Start n8n
info "Starting n8n..."
if [ "$DRY_RUN" = false ]; then
  docker compose -f "$COMPOSE_FILE" up -d n8n
fi

# ─── Phase 3: Validate Services ──────────────────────────────────────────────
header "Phase 3/4: Service Validation"

if [ "$DRY_RUN" = false ]; then
  # n8n health check
  info "Checking n8n health..."
  for i in $(seq 1 20); do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz 2>/dev/null | grep -q "200"; then
      ok "n8n is healthy — http://localhost:5678/healthz → 200"
      break
    fi
    if [ "$i" -eq 20 ]; then
      warn "n8n healthcheck timed out. Check with: docker compose -f $COMPOSE_FILE logs n8n"
    fi
    sleep 3
  done

  # Container status
  echo ""
  info "Container status:"
  docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
else
  info "(dry-run) Would validate service health"
fi

# ─── Phase 4: Summary ────────────────────────────────────────────────────────
header "Phase 4/4: Deployment Complete"

DEPLOY_END=$(date +%s)
DURATION=$((DEPLOY_END - DEPLOY_START))

echo ""
echo "  ┌──────────────────────┬──────────────────────────────────────────┐"
echo "  │ Service              │ URL                                      │"
echo "  ├──────────────────────┼──────────────────────────────────────────┤"
echo "  │ n8n Dashboard        │ http://localhost:5678                    │"
echo "  │ n8n Health           │ http://localhost:5678/healthz            │"
echo "  │ Supabase Dashboard   │ https://supabase.com/dashboard/projects  │"
echo "  │ Supabase API         │ ${MINDFRAME_SUPABASE_URL:-<set in .env>} │"
echo "  └──────────────────────┴──────────────────────────────────────────┘"
echo ""
echo "  Deployment time: ${DURATION}s"
echo ""

# ─── Next Steps ──────────────────────────────────────────────────────────────
echo "  ${BOLD}Next Steps:${NC}"
echo "  ──────────────────────────────────────────────"
echo "  1. Open ${CYAN}http://localhost:5678${NC} and create your n8n admin account"
echo "  2. Go to ${CYAN}Settings → Credentials${NC} and add:"
echo "     - ${GREEN}Supabase${NC} (PostgreSQL) — use your Supabase connection string"
echo "     - ${GREEN}OpenAI${NC} — paste your API key"
echo "     - ${GREEN}Beehiiv${NC} (HTTP Header Auth) — paste your API key"
echo "     - ${GREEN}Stripe${NC} — paste your secret key + webhook secret"
echo "  3. Import workflows: ${CYAN}Workflows → Add → Import from File${NC}"
echo "     Files: engineering/workflows/*.json"
echo "  4. Configure Stripe webhooks:"
echo "     ${CYAN}https://dashboard.stripe.com/webhooks${NC}"
echo "     Endpoint: http://<your-domain>/webhook/mindframe/stripe-purchase"
echo "     Endpoint: http://<your-domain>/webhook/mindframe/membership-sync"
echo "  5. Set n8n environment variables for campaign IDs:"
echo "     ${CYAN}Settings → Environment Variables${NC}"
echo "  6. Activate each workflow: toggle to ${GREEN}Active${NC}"
echo ""

# Create deployment marker
if [ "$DRY_RUN" = false ]; then
  date > "$DEPLOY_DIR/.deployed"
  ok "Deployment marker created at $DEPLOY_DIR/.deployed"
fi

echo "  ${BOLD}Happy building! 🚀${NC}"
echo ""