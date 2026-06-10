#!/usr/bin/env bash
# =============================================================================
# MindFrame — Environment Template
# =============================================================================
# Source this file to export all required environment variables:
#   source ./deploy/env-template.sh
#
# Or use as a reference to create a custom .env:
#   cp deploy/env-template.sh .env  (then edit the values)
# =============================================================================

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1: n8n Configuration
# ═══════════════════════════════════════════════════════════════════════════════

# n8n host and protocol (change to your domain in production)
export N8N_HOST="localhost"
export N8N_PROTOCOL="http"

# Encryption key (generate with: openssl rand -base64 32)
export N8N_ENCRYPTION_KEY="CHANGE-ME-to-a-32-char-random-string-abcdef1234"

# PostgreSQL for n8n internal state (runs inside Docker)
export N8N_DB_HOST="n8n-db"
export N8N_DB_PORT="5432"
export N8N_DB_NAME="n8n"
export N8N_DB_USER="n8n"
export N8N_DB_PASSWORD="CHANGE-ME-n8n-db-password-123"

# Execution mode: "regular" or "queue" (queue requires Redis workers)
export N8N_EXECUTIONS_MODE="regular"

# Redis (only needed if EXECUTIONS_MODE=queue)
export REDIS_HOST="n8n-redis"
export REDIS_PORT="6379"
export REDIS_PASSWORD=""
export REDIS_DB="0"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2: Supabase (Business Database)
# ═══════════════════════════════════════════════════════════════════════════════

# Get these from: Supabase Dashboard → Settings → API
# Or run: ./deploy/supabase-setup.sh  (outputs these automatically)
export MINDFRAME_SUPABASE_URL="https://YOUR-PROJECT-REF.supabase.co"
export MINDFRAME_SUPABASE_SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Supabase CLI (for setup script - optional after initial deploy)
export SUPABASE_ACCESS_TOKEN="sbp_YOUR-SUPABASE-ACCESS-TOKEN"
export SUPABASE_ORG_ID="YOUR-ORG-ID"
export SUPABASE_DB_PASSWORD="CHANGE-ME-supabase-db-password-32chars"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3: AI Providers
# ═══════════════════════════════════════════════════════════════════════════════

# OpenAI — https://platform.openai.com/api-keys
export MINDFRAME_OPENAI_API_KEY="sk-proj-YOUR-OPENAI-KEY"

# ElevenLabs — https://elevenlabs.io/app/settings/api-keys
export MINDFRAME_ELEVENLABS_API_KEY="YOUR-ELEVENLABS-KEY"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4: Payment Processors
# ═══════════════════════════════════════════════════════════════════════════════

# Stripe — https://dashboard.stripe.com/apikeys
export MINDFRAME_STRIPE_SECRET_KEY="sk_live_YOUR-STRIPE-SECRET-KEY"
export MINDFRAME_STRIPE_WEBHOOK_SECRET="whsec_YOUR-WEBHOOK-SIGNING-SECRET"

# Gumroad — https://app.gumroad.com/settings/advanced#access-token
export MINDFRAME_GUMROAD_ACCESS_TOKEN="YOUR-GUMROAD-ACCESS-TOKEN"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5: Email Marketing
# ═══════════════════════════════════════════════════════════════════════════════

# Beehiiv — https://app.beehiiv.com/settings/integrations
export MINDFRAME_BEEHIIV_API_KEY="YOUR-BEEHIIV-API-KEY"

# ConvertKit (alternative to Beehiiv)
export MINDFRAME_CONVERTKIT_API_KEY="YOUR-CONVERTKIT-API-KEY"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6: SMTP (Email Fallback)
# ═══════════════════════════════════════════════════════════════════════════════

export MINDFRAME_SMTP_HOST="smtp.sendgrid.net"
export MINDFRAME_SMTP_PORT="587"
export MINDFRAME_SMTP_USER="apikey"
export MINDFRAME_SMTP_PASS="SG.YOUR-SENDGRID-KEY"
export MINDFRAME_SMTP_FROM="noreply@mindframe.ai"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 7: n8n Email Campaign IDs (set after importing workflows)
# ═══════════════════════════════════════════════════════════════════════════════
# Create campaigns in Beehiiv for each of these, then update the values.
# Alternatively, set these in n8n's environment variables UI after activation.

export WELCOME_DAY1_CAMPAIGN_ID=""
export WELCOME_DAY2_CAMPAIGN_ID=""
export WELCOME_DAY3_CAMPAIGN_ID=""
export WELCOME_DAY4_CAMPAIGN_ID=""
export WELCOME_DAY5_CAMPAIGN_ID=""
export PURCHASE_WELCOME_CAMPAIGN_ID=""
export MEMBERSHIP_WELCOME_CAMPAIGN_ID=""
export MEMBERSHIP_UPDATE_CAMPAIGN_ID=""
export CHURN_REMINDER_CAMPAIGN_ID=""

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 8: Admin & Monitoring
# ═══════════════════════════════════════════════════════════════════════════════

export ADMIN_EMAIL="admin@mindframe.ai"

# ═══════════════════════════════════════════════════════════════════════════════
# Validation: Check that required values are set
# ═══════════════════════════════════════════════════════════════════════════════

echo "MindFrame — Environment Template"
echo "─────────────────────────────────"
echo ""

REQUIRED_VARS=(
  "N8N_ENCRYPTION_KEY"
  "N8N_DB_PASSWORD"
  "MINDFRAME_SUPABASE_URL"
  "MINDFRAME_SUPABASE_SERVICE_KEY"
  "MINDFRAME_OPENAI_API_KEY"
  "MINDFRAME_BEEHIIV_API_KEY"
  "MINDFRAME_STRIPE_SECRET_KEY"
)

MISSING=false
for var in "${REQUIRED_VARS[@]}"; do
  value="${!var:-}"
  if [ -z "$value" ]; then
    echo "  ⚠️  $var is not set"
    MISSING=true
  elif [[ "$value" == *"CHANGE-ME"* ]] || [[ "$value" == *"YOUR-"* ]]; then
    echo "  ⚠️  $var still has placeholder value"
    MISSING=true
  else
    echo "  ✅ $var is set"
  fi
done

echo ""
if [ "$MISSING" = true ]; then
  echo "  ⚠️  Some variables need your attention. Edit this file and re-source it."
else
  echo "  ✅ All required variables are set! Ready to deploy."
fi
echo ""