# MindFrame — DEPLOYMENT QUICKSTART

### 1️⃣ Create 6 Accounts

| Service | Sign Up URL | Needed For |
|---------|------------|------------|
| Supabase | https://supabase.com | Database + Auth |
| Stripe | https://dashboard.stripe.com | Payments |
| Gumroad | https://app.gumroad.com | Digital product sales |
| OpenAI | https://platform.openai.com | AI script generation |
| ElevenLabs | https://elevenlabs.io | AI voiceover (optional) |
| Beehiiv | https://app.beehiiv.com | Email marketing |

### 2️⃣ Get API Keys

Open each dashboard → find API keys section → copy keys into `.env`:

```bash
cp engineering/deploy/.env .env    # Create .env from template
vim .env                            # Paste keys into each field
```

### 3️⃣ Deploy Database + n8n

```bash
bash engineering/deploy/deploy.sh
# ☐ Creates Supabase project + runs 10 migrations + seeds 50 hooks
# ☐ Launches n8n on http://localhost:5678
```

### 4️⃣ Deploy Landing Pages

```bash
# Go to https://vercel.com → Import repo → Root: landing-pages/
# Vercel auto-detects the static HTML files
```

### 5️⃣ Import Gumroad Products

```bash
# Go to https://app.gumroad.com → Products → Import
# Use files from: engineering/products/packages/
```

### 6️⃣ Import n8n Workflows

```bash
# Open http://localhost:5678 → Workflows → Add → Import from File
# Select all 8 files from: engineering/workflows/*.json
# Then toggle each to Active
```

### 7️⃣ Connect Stripe Webhooks

```bash
# Stripe Dashboard → Webhooks → Add endpoint → URL:
# https://your-n8n-host/webhook/mindframe/stripe-purchase
# Events: checkout.session.completed + customer.subscription.*
```

---

## Quick Reference

| Service | URL | API Key Location |
|---------|-----|-----------------|
| Supabase | supabase.com/dashboard | Settings → API → Project API keys |
| Stripe | dashboard.stripe.com | Developers → API keys |
| Gumroad | app.gumroad.com | Settings → Advanced → Access token |
| OpenAI | platform.openai.com | API keys → Create new secret key |
| ElevenLabs | elevenlabs.io | Profile → API Keys |
| Beehiiv | app.beehiiv.com | Settings → Integrations → API Key |
| n8n | localhost:5678 | Settings → Credentials (after deploy) |
| Vercel | vercel.com | Import repo → auto-deploy |