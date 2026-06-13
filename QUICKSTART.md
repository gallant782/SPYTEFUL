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
| ☐ | `MINDFRAME_STRIPE_PUBLISHABLE_KEY` | **Your key:** `[OWNER PROVIDES THIS]` → Stripe Dashboard → API keys |
| ☐ | `MINDFRAME_STRIPE_SECRET_KEY` | Stripe Dashboard → API keys (sk_live_... or sk_test_...) |
| ☐ | `MINDFRAME_STRIPE_WEBHOOK_SECRET` | Stripe Dashboard → Webhooks (create endpoint after n8n is running) |
| ☐ | `MINDFRAME_OPENAI_API_KEY` | platform.openai.com/api-keys |
| ☐ | `MINDFRAME_CONVERTKIT_API_KEY` | app.convertkit.com/account_settings/advanced_settings |

Edit the file: `vim .env` *(or `cp engineering/deploy/.env .env && vim .env`)*

---

## ⬜ Step 3: Deploy Database (2 min)

```bash
# One command: creates Supabase project + runs all 10 migrations + seeds 50 hooks
./engineering/deploy/supabase-setup.sh
```

| ✅ | Check | Verify |
|---|-------|--------|
| ☐ | Project created | Supabase Dashboard shows new project |
| ☐ | Migrations applied | 10/10 success (no errors in output) |
| ☐ | Hooks seeded | Run: `SELECT COUNT(*) FROM viral_hooks;` → **50** |
| ☐ | Copy credentials | Set `MINDFRAME_SUPABASE_URL` and `MINDFRAME_SUPABASE_SERVICE_KEY` in `.env` |

---

## ⬜ Step 4: Launch n8n (2 min)

```bash
# Start n8n + PostgreSQL + Redis
docker compose -f engineering/deploy/docker-compose.yml up -d
```

| ✅ | Check | Verify |
|---|-------|--------|
| ☐ | All containers running | `docker compose -f engineering/deploy/docker-compose.yml ps` → **3/3 up** |
| ☐ | n8n healthy | `curl http://localhost:5678/healthz` → **200 OK** |
| ☐ | Can open UI | Open http://localhost:5678 in browser |

---

## ⬜ Step 5: Configure n8n (3 min)

| ✅ | Task | Details |
|---|------|---------|
| ☐ | Create admin account | n8n UI → sign up (first user becomes admin) |
| ☐ | Add Supabase credential | Settings → Credentials → PostgreSQL → use `MINDFRAME_SUPABASE_URL` as host |
| ☐ | Add OpenAI credential | Settings → Credentials → OpenAI → paste `MINDFRAME_OPENAI_API_KEY` |
| ☐ | Add Stripe credential | Settings → Credentials → Stripe → paste `MINDFRAME_STRIPE_SECRET_KEY` |
| ☐ | Add ConvertKit credential | Settings → Credentials → HTTP Header Auth → paste `MINDFRAME_CONVERTKIT_API_KEY` |
| ☐ | Import 8 workflows | Workflows → Add → Import from File → select each from `engineering/workflows/*.json` |
| ☐ | Set env variables | Settings → Environment Variables → add all `WELCOME_*_CAMPAIGN_ID` vars |
| ☐ | Activate workflows | Toggle each workflow to **Active** (green switch) |

---

## ⬜ Step 6: Connect Stripe Webhooks (1 min)

| ✅ | Task | Details |
|---|------|---------|
| ☐ | Create webhook endpoint | Stripe Dashboard → Webhooks → Add endpoint |
| ☐ | Endpoint URL | `https://YOUR-N8N-DOMAIN/webhook/mindframe/stripe-purchase` |
| ☐ | Events to listen for | `checkout.session.completed`, `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted` |
| ☐ | Copy signing secret | Set as `MINDFRAME_STRIPE_WEBHOOK_SECRET` in n8n env vars |

---

## 🚀 Launch Verification

```bash
# Final health check — run this:
echo "── Container Status ──"
docker compose -f engineering/deploy/docker-compose.yml ps
echo "── n8n Health ──"
curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz
echo ""
echo "── Database ──"
echo "SELECT COUNT(*) FROM viral_hooks;" | supabase db execute --csv
echo "── Webhooks Active ──"
curl -s http://localhost:5678/rest/workflows?active=true | python3 -c "import sys,json; ws=json.load(sys.stdin); [print(f'  {w[\"name\"]}: {\"✅ Active\" if w.get(\"active\") else \"⬜ Inactive\"}') for w in ws]"
```

---

## 🔧 Troubleshooting

| Symptom | Fix |
|---------|-----|
| `docker compose` not found | Install Docker Desktop (includes Compose v2) |
| `supabase` not found | `brew install supabase/tap/supabase` |
| n8n returns 502 | `docker compose -f engineering/deploy/docker-compose.yml restart n8n` |
| n8n webhook not responding | Check n8n is on a public URL (not localhost) for Stripe to reach it |
| Webhook returns 401 | Stripe signing secret doesn't match — re-copy from Stripe Dashboard |
| Script generation fails | Check `MINDFRAME_OPENAI_API_KEY` has credits and is active |

---

*📄 Full documentation: `engineering/deployment-plan.md` | 🗄 Schema: `engineering/database-architecture.md` | ⚙ Workflows: `engineering/workflows/README.md`*