# MindFrame — Deployment Quickstart Checklist

> **One-page guide.** From zero to running n8n + Supabase in ~10 minutes.
> ⏱ Estimated time: **10 minutes**

---

## ⬜ Step 1: Prerequisites (2 min)

| ✅ | Item | How to check |
|---|------|-------------|
| ☐ | Git repo cloned | `git clone https://github.com/gallant782/SPYTEFUL.git && cd SPYTEFUL` |
| ☐ | Docker installed | `docker --version` → 24+ |
| ☐ | Supabase CLI installed | `supabase --version` |
| ☐ | Supabase logged in | `supabase login` |
| ☐ | `openssl` available | `openssl version` |

---

## ⬜ Step 2: Configure .env (3 min)

| ✅ | Variable | Value / Source |
|---|----------|---------------|
| ☐ | `N8N_ENCRYPTION_KEY` | Run: `openssl rand -base64 32` |
| ☐ | `N8N_DB_PASSWORD` | Pick a strong password (16+ chars) |
| ☐ | `MINDFRAME_STRIPE_PUBLISHABLE_KEY` | Stripe Dashboard → API keys → Publishable key |
| ☐ | `MINDFRAME_STRIPE_SECRET_KEY` | Stripe Dashboard → API keys → Secret key |
| ☐ | `MINDFRAME_STRIPE_WEBHOOK_SECRET` | Stripe Dashboard → Webhooks (create endpoint after n8n is live) |
| ☐ | `MINDFRAME_OPENAI_API_KEY` | platform.openai.com/api-keys |
| ☐ | `MINDFRAME_BEEHIIV_API_KEY` | app.beehiiv.com/settings/integrations |

Edit the file: `cp engineering/deploy/.env .env && vim .env`

---

## ⬜ Step 3: Deploy Database (2 min)

```bash
./engineering/deploy/supabase-setup.sh
```

| ✅ | Check | How to verify |
|---|-------|--------------|
| ☐ | Migrations applied | Output shows no errors |
| ☐ | Hooks seeded | `SELECT COUNT(*) FROM viral_hooks;` → **50** |
| ☐ | Credentials saved | Set `MINDFRAME_SUPABASE_URL` and `MINDFRAME_SUPABASE_SERVICE_KEY` in `.env` |

---

## ⬜ Step 4: Launch n8n (2 min)

```bash
docker compose -f engineering/deploy/docker-compose.yml up -d
```

| ✅ | Check | How to verify |
|---|-------|--------------|
| ☐ | All 3 containers up | `docker compose ps` → **3/3 running** |
| ☐ | n8n healthy | `curl http://localhost:5678/healthz` → **200** |
| ☐ | UI accessible | Open http://localhost:5678 |

---

## ⬜ Step 5: Configure n8n (3 min)

| ✅ | Task |
|---|------|
| ☐ | Create admin account at http://localhost:5678 |
| ☐ | Add **Supabase** credential (PostgreSQL) |
| ☐ | Add **OpenAI** credential (API key) |
| ☐ | Add **Stripe** credential (Secret key) |
| ☐ | Add **Beehiiv** credential (HTTP Header Auth) |
| ☐ | Import **8 workflows** from `engineering/workflows/*.json` |
| ☐ | Set **environment variables** (campaign IDs from Beehiiv) |
| ☐ | **Activate** each workflow (toggle to green) |

---

## ⬜ Step 6: Connect Stripe Webhooks (1 min)

| ✅ | Task |
|---|------|
| ☐ | Stripe Dashboard → Webhooks → Add endpoint |
| ☐ | URL: `https://YOUR-N8N-DOMAIN/webhook/mindframe/stripe-purchase` |
| ☐ | Events: `checkout.session.completed`, `customer.subscription.*` |
| ☐ | Copy signing secret → set as `MINDFRAME_STRIPE_WEBHOOK_SECRET` |

---

## 🚀 Final Verification

```bash
# Run this to confirm everything is green:
docker compose -f engineering/deploy/docker-compose.yml ps
curl -s -o /dev/null -w "n8n: HTTP %{http_code}\n" http://localhost:5678/healthz
echo "Hooks: $(echo "SELECT COUNT(*) FROM viral_hooks;" | supabase db execute --csv 2>/dev/null | tail -1)"
```

---

## 🔧 Common Issues

| Problem | Solution |
|---------|----------|
| `docker compose` not found | Install Docker Desktop |
| `supabase` not found | `brew install supabase/tap/supabase` |
| n8n 502 error | `docker compose restart n8n` |
| n8n unreachable from Stripe | Use a public domain or ngrok: `ngrok http 5678` |
| Webhook 401 | Stripe signing secret doesn't match — re-copy from Stripe |
| Script gen fails | Check OpenAI key has credits |

---

*📄 Full docs: `engineering/deployment-plan.md` • 🗄 Schema: `engineering/database-architecture.md` • ⚙ Workflows: `engineering/workflows/README.md`*