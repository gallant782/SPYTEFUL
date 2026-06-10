# MindFrame Deployment Plan

> **Author:** Systems Engineer
> **Date:** 2025-06-07
> **Version:** v1.0

---

## 1. Infrastructure Stack

| Component | Service | Tier | Monthly Cost |
|-----------|---------|------|-------------|
| **Database** | Supabase (PostgreSQL) | Free Tier | $0 |
| **Auth** | Supabase Auth | Included | $0 |
| **File Storage** | Supabase Storage | Free (1GB) | $0 |
| **Automation** | n8n (self-hosted on railway/fly) | Free-tier capable | $0–$5 |
| **Email** | Beehiiv / ConvertKit | Free (up to 1K subs) | $0 |
| **Payments** | Stripe + Gumroad | Transaction fee only | ~2.9% + $0.30 |
| **Landing Page** | Framer / Vercel + Next.js | Free | $0 |
| **Community** | Skool | $99/mo (or free for first 100) | $0–$99 |
| **CDN** | Supabase CDN / Cloudflare | Free | $0 |
| **DNS** | Cloudflare | Free | $0 |
| **Monitoring** | Sentry (free) + uptimerobot | Free | $0 |
| **Analytics** | PostHog self-hosted or free cloud | Free (1M events) | $0 |
| **AI / Voice** | ElevenLabs API | Pay as you go | ~$5–$22/mo |
| **AI / Script** | OpenAI API | Pay as you go | ~$5–$20/mo |

**Estimated total infrastructure cost: $0–$30/mo at launch**

---

## 2. Deployment Order (Week 1)

### Day 1: Database Foundation
- [ ] Create Supabase project at [supabase.com](https://supabase.com)
- [ ] Enable extensions: `uuid-ossp`, `pgcrypto`
- [ ] Run migrations in order via Supabase SQL Editor:
  ```bash
  001_core.sql          # Profiles, sessions, base tables
  002_content.sql       # Videos, scripts, hooks, templates
  003_email.sql         # Subscribers, campaigns, logs
  004_commerce.sql      # Products, purchases, memberships
  005_analytics.sql     # Events, funnel, daily rollup
  006_affiliates.sql    # Affiliates, referrals, commissions
  007_automation.sql    # Workflows, execution logs
  008_indexes.sql       # Supplemental indexes
  009_rls_policies.sql  # Row-level security policies
  ```
- [ ] Seed data: `010_seed_hooks.sql`
- [ ] **Verify:** Run `SELECT COUNT(*) FROM viral_hooks;` → should return 50
- [ ] **Verify:** Check RLS by creating a test user

### Day 2: Auth & Profiles
- [ ] Configure Supabase Auth (email/password + magic link)
- [ ] Set up Auth webhook → create `profiles` row on signup
- [ ] Configure redirect URLs for landing pages
- [ ] **Test:** Create a user, verify profile row created
- [ ] **Test:** RLS — anon cannot read profiles, authenticated can read own

### Day 3: n8n Automation Server
- [ ] Deploy n8n (choose one):
  - **Option A: Railway** (`railway.app` — easiest)
    ```bash
    # 1-click deploy from n8n template
    # Set env: N8N_ENCRYPTION_KEY, N8N_HOST
    ```
  - **Option B: Fly.io** (cheaper at scale)
    ```bash
    fly launch --image n8nio/n8n
    fly secrets set N8N_ENCRYPTION_KEY=<random>
    ```
  - **Option C: Docker locally (dev only)**
    ```bash
    docker run -d --name n8n -p 5678:5678 n8nio/n8n
    ```
- [ ] Configure n8n credentials:
  - Supabase API key (service_role)
  - OpenAI API key
  - ElevenLabs API key
  - Stripe secret key
  - Gumroad access token
  - Beehiiv/ConvertKit API key
- [ ] **Verify:** n8n dashboard loads, webhook URL responds

### Day 4: API Layer (Edge Functions)
- [ ] Create Supabase Edge Functions:
  - `content-hooks` — Fetch best-performing hooks
  - `analytics-track` — POST funnel events
  - `email-subscribe` — Subscribe handler with source tracking
  - `affiliate-code` — Generate unique referral codes
- [ ] Deploy: `supabase functions deploy`
- [ ] **Test:** Hit `GET /functions/v1/content-hooks` → returns hooks JSON

### Day 5: Payment Integration
- [ ] Stripe setup:
  - [ ] Create products in Stripe Dashboard (membership monthly/annual)
  - [ ] Configure Stripe webhook → Edge Function → `purchases` table
  - [ ] Configure membership lifecycle (created → memberships row, canceled → status update)
- [ ] Gumroad setup:
  - [ ] Create digital products (The Productivity Vault)
  - [ ] Enable affiliate system
  - [ ] Set Gumroad webhook → n8n → `purchases` table
- [ ] **Test:** Run a test purchase via Stripe test mode
- [ ] **Test:** Verify `purchases` row created with correct data

### Day 6-7: Content & Email Workflows
- [ ] Build n8n workflow: **Content Pipeline**
  ```
  Trigger: n8n webhook → 
    Step 1: OpenAI generate script from template + hook →
    Step 2: ElevenLabs generate voiceover →
    Step 3: Store in Supabase `content_scripts` →
    Step 4: Update `content_videos` with script_id
  ```
- [ ] Build n8n workflow: **Email Sync**
  ```
  Trigger: On new `email_subscribers` row →
    Step 1: Create subscriber in Beehiiv/ConvertKit →
    Step 2: Tag based on `source` →
    Step 3: Trigger welcome sequence step 1
  ```
- [ ] Build n8n workflow: **Analytics Rollup** (CRON daily at midnight)
  ```
  Trigger: CRON @daily →
    Step 1: Aggregate funnel events by day →
    Step 2: UPSERT into `analytics_daily_metrics` →
    Step 3: Update `content_videos` total_views etc.
  ```
- [ ] **Verify:** Trigger each workflow manually, check logs in `automation_execution_logs`

---

## 3. Automation Workflow Catalog

### Priority Workflows (Launch Critical)

| # | Workflow | Triggers | Actions | Category |
|---|----------|----------|---------|----------|
| 1 | **Script Generator** | Webhook (manual trigger) | OpenAI → ElevenLabs → Supabase | Content |
| 2 | **Lead Magnet Delivery** | New email subscriber → n8n webhook | Tag → Send email via Beehiiv → Track in Supabase | Email |
| 3 | **Purchase Handler** | Stripe/Gumroad webhook | Create purchase row → Grant access → Tag subscriber | Commerce |
| 4 | **Welcome Sequence** | Purchase confirmed | Delay 1h → Send email 1 → Delay 24h → Send email 2 ... | Email |
| 5 | **Daily Metrics Rollup** | CRON @daily | Aggregate from funnel_events → UPSERT daily_metrics | Analytics |
| 6 | **Affiliate Commission** | Purchase completed with affiliate | Calculate commission → Create commission row | Affiliate |
| 7 | **Membership Sync** | Stripe subscription webhook | Create/update memberships → Update profile membership flag | Commerce |
| 8 | **Churn Alert** | CRON @daily | Check past_due/canceled → Send admin alert | Monitoring |

### Secondary Workflows (Week 2+)

| # | Workflow | Triggers | Actions |
|---|----------|----------|---------|
| 9 | **Abandoned Cart** | Checkout initiated but not completed | Hour 1 → 24 → 48 reminders |
| 10 | **Re-engagement** | Subscriber inactive for 60 days | Send re-engagement series → Unsubscribe if no response |
| 11 | **Viral Hook Ranking** | Weekly CRON | Compare estimated vs actual performance → Flag top/bottom |
| 12 | **Referral Reward** | Referral converts to paid | Apply discount/credit to referrer |

---

## 4. Environment Variables

### Required by n8n Workflows

```bash
# Supabase
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_SERVICE_KEY=<service_role_key>

# OpenAI
OPENAI_API_KEY=sk-...

# ElevenLabs
ELEVENLABS_API_KEY=...

# Stripe
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Gumroad
GUMROAD_ACCESS_TOKEN=...
GUMROAD_WEBHOOK_SECRET=...

# Beehiiv / ConvertKit
BEEHIIV_API_KEY=...
CONVERTKIT_API_KEY=...

# Email (SMTP fallback)
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=SG....
```

---

## 5. Monitoring & Alerting

### Dashboard Queries (Run in Supabase SQL Editor)

**Daily revenue snapshot:**
```sql
SELECT metric_date,
       total_revenue_cents / 100.0 AS revenue_dollars,
       tripwire_sales,
       membership_new_sales,
       new_subscribers,
       churned_members
FROM analytics_daily_metrics
WHERE metric_date >= NOW() - INTERVAL '30 days'
ORDER BY metric_date DESC;
```

**Workflow health check:**
```sql
SELECT w.name,
       COUNT(*) FILTER (WHERE l.status = 'failed') AS failures,
       COUNT(*) FILTER (WHERE l.status = 'success') AS successes,
       ROUND(
           COUNT(*) FILTER (WHERE l.status = 'success')::DECIMAL /
           NULLIF(COUNT(*), 0) * 100, 2
       ) AS success_rate
FROM automation_workflows w
JOIN automation_execution_logs l ON l.workflow_id = w.id
WHERE l.started_at >= NOW() - INTERVAL '24 hours'
GROUP BY w.id, w.name
ORDER BY success_rate ASC;
```

**Failed workflow alerts (n8n + email):**
- n8n has built-in error workflows — connect to Slack or email
- Fallback: Python script via CRON checking `automation_execution_logs`

### Uptime Monitoring
- **Supabase:** Built-in status page at status.supabase.com
- **n8n:** Deploy with healthcheck endpoint, monitor via uptimerobot.com (free)
- **Goal:** ≥99% automation uptime (trigger alert at 3 failures/hr)

---

## 6. Scaling Plan

### Phase 1: Launch (0–1,000 subscribers)
- Supabase free tier (500MB DB)
- n8n single instance
- Manual content publishing

### Phase 2: Growth (1,000–10,000 subscribers)
- Supabase Pro ($25/mo) — 8GB DB, 100K users
- n8n upgrade (Railway $5–$20)
- Add PostHog for product analytics

### Phase 3: Scale (10,000+ subscribers)
- Supabase Team ($599/mo) — dedicated infra
- n8n multi-instance with Redis queue
- Database read replicas for dashboards

---

## 7. Rollback Strategy

### Schema Rollback
Each migration is transactional (wrapped in `BEGIN...COMMIT`). To roll back:
```sql
-- Drop entire schema (destructive — only in dev)
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
-- Then re-run from 001 onward
```

### Safe Additions
Always use `IF NOT EXISTS` / `IF EXISTS` for idempotent operations:
```sql
ALTER TABLE content_videos ADD COLUMN IF NOT EXISTS new_column TEXT;
CREATE INDEX IF NOT EXISTS idx_name ON table(column);
```

### Data Recovery
- Supabase provides daily backups on Pro plan
- Export critical tables weekly: `pg_dump --table=purchases ...`

---

*End of Deployment Plan*