#!/usr/bin/env bash
# =============================================================================
# MindFrame — One-Command Launch Script
# =============================================================================
# Sets up the entire infrastructure with a single command.
#
# Usage:
#   ./scripts/launch.sh                    # Full setup (requires .env)
#   ./scripts/launch.sh --env-file prod.env # Use custom env file
#   ./scripts/launch.sh --skip-supabase    # Skip Supabase setup (already done)
#   ./scripts/launch.sh --skip-n8n         # Skip n8n Docker launch
#   ./scripts/launch.sh --dry-run          # Preview without executing
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINEERING_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$ENGINEERING_DIR")"

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─── Flags ────────────────────────────────────────────────────────────────────
SKIP_SUPABASE=false
SKIP_N8N=false
DRY_RUN=false
ENV_FILE=""

for arg in "$@"; do
  case "$arg" in
    --skip-supabase) SKIP_SUPABASE=true ;;
    --skip-n8n) SKIP_N8N=true ;;
    --dry-run) DRY_RUN=true ;;
    --env-file=*) ENV_FILE="${arg#*=}" ;;
    --env-file) echo "Use: --env-file=filename.env"; exit 1 ;;
  esac
done

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

run() {
  info "Running: $*"
  if [ "$DRY_RUN" = false ]; then
    eval "$*" || fail "Command failed: $*"
  fi
}

# ─── Banner ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║         MindFrame — Launch Script         ║"
echo "  ║   One-command infrastructure deployment    ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"
echo "  $(date)"
echo ""

# ─── Step 0: Load Environment ────────────────────────────────────────────────
info "Step 0: Loading environment..."

# Determine which env file to use
if [ -n "$ENV_FILE" ]; then
  ENV_PATH="$ENV_FILE"
elif [ -f "$ENGINEERING_DIR/.env" ]; then
  ENV_PATH="$ENGINEERING_DIR/.env"
elif [ -f "$PROJECT_ROOT/.env" ]; then
  ENV_PATH="$PROJECT_ROOT/.env"
else
  warn "No .env file found. Creating from .env.example..."
  if [ "$DRY_RUN" = false ]; then
    cp "$ENGINEERING_DIR/.env.example" "$ENGINEERING_DIR/.env"
    ENV_PATH="$ENGINEERING_DIR/.env"
    warn "Created $ENV_PATH — EDIT IT before running again"
    warn "At minimum, set: N8N_ENCRYPTION_KEY, N8N_DB_PASSWORD, MINDFRAME_* keys"
    exit 1
  fi
fi

set -a
source "$ENV_PATH"
set +a
ok "Environment loaded from: $ENV_PATH"

# ─── Step 1: Validate Environment ────────────────────────────────────────────
info "Step 1: Validating configuration..."

REQUIRED_VARS=(
  "N8N_ENCRYPTION_KEY"
  "N8N_DB_PASSWORD"
  "MINDFRAME_SUPABASE_URL"
  "MINDFRAME_SUPABASE_SERVICE_KEY"
  "MINDFRAME_OPENAI_API_KEY"
  "MINDFRAME_BEEHIIV_API_KEY"
)

MISSING=false
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ] || [ "${!var}" = "your-..." ] || [ "${!var}" = "change-me-..." ]; then
    warn "  $var is not set or still has placeholder value"
    MISSING=true
  fi
done

if [ "$MISSING" = true ]; then
  warn "Some required variables are missing. Edit $ENV_PATH and re-run."
  echo ""
  echo "  Minimal config needed to start:"
  echo "    - N8N_ENCRYPTION_KEY (any 32+ char random string)"
  echo "    - N8N_DB_PASSWORD (any password for local Postgres)"
  echo "    - MINDFRAME_SUPABASE_URL + MINDFRAME_SUPABASE_SERVICE_KEY"
  echo "    - MINDFRAME_OPENAI_API_KEY (for script generation)"
  echo "    - MINDFRAME_BEEHIIV_API_KEY (for email)"
  echo ""
  if [ "$DRY_RUN" = false ]; then
    exit 1
  fi
fi
ok "Configuration validated"

# ─── Step 2: Check Docker ────────────────────────────────────────────────────
info "Step 2: Checking Docker..."

if ! command -v docker &> /dev/null; then
  fail "Docker not found. Install: https://docs.docker.com/get-docker/"
fi
if ! docker compose version &> /dev/null && ! docker-compose --version &> /dev/null; then
  fail "Docker Compose not found. Install: https://docs.docker.com/compose/install/"
fi
ok "Docker + Compose ready"

# ─── Step 3: Setup Supabase ──────────────────────────────────────────────────
if [ "$SKIP_SUPABASE" = false ]; then
  echo ""
  info "============================================="
  info "  Step 3: Setting up Supabase"
  info "============================================="
  echo ""

  SUPABASE_FLAGS=""
  if [ "$DRY_RUN" = true ]; then
    SUPABASE_FLAGS="--dry-run"
  fi

  run "$SCRIPT_DIR/setup-supabase.sh $SUPABASE_FLAGS"
  ok "Supabase setup complete"
else
  warn "Skipping Supabase setup (--skip-supabase)"
fi

# ─── Step 4: Launch n8n via Docker Compose ──────────────────────────────────
if [ "$SKIP_N8N" = false ]; then
  echo ""
  info "============================================="
  info "  Step 4: Launching n8n (Docker Compose)"
  info "============================================="
  echo ""

  # Copy .env to docker-compose directory for n8n to pick up
  cd "$ENGINEERING_DIR"

  # Pull latest images
  run "docker compose pull n8n n8n-db n8n-redis"

  # Start services
  run "docker compose up -d n8n-db n8n-redis"

  # Wait for DB to be healthy
  info "Waiting for PostgreSQL to be healthy..."
  if [ "$DRY_RUN" = false ]; then
    timeout 30 bash -c 'until docker compose exec n8n-db pg_isready -U n8n 2>/dev/null; do sleep 2; done' || warn "DB healthcheck timed out (continuing)"
  fi

  # Start n8n
  run "docker compose up -d n8n"

  # Wait for n8n to start
  info "Waiting for n8n to start..."
  if [ "$DRY_RUN" = false ]; then
    sleep 5
    for i in $(seq 1 15); do
      if curl -s http://localhost:5678/healthz > /dev/null 2>&1; then
        ok "n8n is running on http://localhost:5678"
        break
      fi
      if [ "$i" -eq 15 ]; then
        warn "n8n may not be ready yet. Check with: docker compose logs n8n"
      fi
      sleep 2
    done
  fi

  ok "Docker Compose services launched"
else
  warn "Skipping n8n Docker launch (--skip-n8n)"
fi

# ─── Step 5: Print Summary ───────────────────────────────────────────────────
echo ""
info "============================================="
info "  ✅  MindFrame Infrastructure Running!"
info "============================================="
echo ""

# Get Supabase URL from env
echo "  ┌──────────────┬──────────────────────────────────────────┐"
echo "  │ Service       │ URL                                      │"
echo "  ├──────────────┼──────────────────────────────────────────┤"
echo "  │ n8n           │ http://localhost:5678                     │"
echo "  │ Supabase      │ ${MINDFRAME_SUPABASE_URL:-<set in .env>} │"
echo "  │ Supabase DB   │ Direct via Dashboard SQL Editor          │"
echo "  └──────────────┴──────────────────────────────────────────┘"
echo ""

if [ "$DRY_RUN" = false ]; then
  echo "  Commands:"
  echo "    docker compose logs -f n8n       # Watch n8n logs"
  echo "    docker compose ps                # Check service status"
  echo "    docker compose down              # Stop all services"
  echo "    docker compose up -d             # Start all services"
  echo ""
  echo "  n8n Setup:"
  echo "    1. Open http://localhost:5678"
  echo "    2. Create admin account"
  echo "    3. Settings → Credentials → Add:"
  echo "       - Supabase (PostgreSQL)"
  echo "       - OpenAI"
  echo "       - Beehiiv (HTTP Header Auth)"
  echo "       - Stripe"
  echo "    4. Workflows → Add → Import from File"
  echo "       Select files from engineering/workflows/"
  echo ""
  echo "  Stripe Webhooks:"
  echo "    Endpoint: https://your-domain.com/webhook/mindframe/stripe-purchase"
  echo "    Endpoint: https://your-domain.com/webhook/mindframe/membership-sync"
  echo ""

  # Create deployment marker
  date > "$ENGINEERING_DIR/.deployed"
  ok "Deployment marker created"
fi