# MindFrame n8n Automation Workflows

8 production-ready n8n workflow JSON exports powering MindFrame's autonomous content-to-revenue pipeline.

## Quick Start

```bash
# 1. Import workflows into n8n
#    In n8n UI: Workflows → Add Workflow → Import from File
#    Select each .json file from workflows/ directory

# 2. Configure credentials in n8n
#    Settings → Credentials → Add credentials for each service

# 3. Set environment variables
#    Settings → Environment Variables → Add each var

# 4. Activate workflows
#    Toggle each workflow to "Active" in n8n
```

## Credentials Required

Before activating any workflow, configure these credentials in n8n:

| Credential Name | Type | Used By |
|----------------|------|---------|
| `Supabase DB` | PostgreSQL | All workflows (DB read/write) |
| `OpenAI` | OpenAI API | Workflow 01 (Script Generator) |
| `ElevenLabs` | HTTP Header Auth | Workflow 01 (Voiceover, optional) |
| `Beehiiv API` | HTTP Header Auth | Workflows 02, 03, 05, 07, 08 |
| `Stripe API` | HTTP Header Auth | Workflows 03, 07 |
| `Email (SMTP)` | SMTP | Workflows 04, 06, 08 |
| `Gumroad` | HTTP Header Auth | Workflow 03 (alt payment) |

## Environment Variables

Set these in n8n Settings → Environment Variables:

```bash
# Beehiiv Campaign IDs (create these campaigns first in Beehiiv dashboard)
WELCOME_DAY1_CAMPAIGN_ID=xxx
WELCOME_DAY2_CAMPAIGN_ID=xxx
WELCOME_DAY3_CAMPAIGN_ID=xxx
WELCOME_DAY4_CAMPAIGN_ID=xxx
WELCOME_DAY5_CAMPAIGN_ID=xxx
PURCHASE_WELCOME_CAMPAIGN_ID=xxx
MEMBERSHIP_WELCOME_CAMPAIGN_ID=xxx
MEMBERSHIP_UPDATE_CAMPAIGN_ID=xxx
CHURN_REMINDER_CAMPAIGN_ID=xxx

# Supabase
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_SERVICE_KEY=<service_role_key>

# Admin notifications
ADMIN_EMAIL=admin@mindframe.ai
```

## Workflow Overview

| # | Workflow | Trigger | Node Count | Category |
|---|----------|---------|------------|----------|
| 1 | **Script Generator** | Manual webhook | 10 | Content Pipeline |
| 2 | **Lead Magnet Delivery** | Landing page webhook | 13 | Email / Lead Capture |
| 3 | **Purchase Handler** | Stripe webhook | 13 | Commerce / Stripe |
| 4 | **Daily Metrics Rollup** | CRON @midnight | 6 | Analytics / Reporting |
| 5 | **Welcome Sequence** | Webhook trigger | 15 | Email / Drip |
| 6 | **Affiliate Commission** | Webhook trigger | 13 | Affiliate / Revenue |
| 7 | **Membership Sync** | Stripe webhook | 13 | Membership / Stripe |
| 8 | **Churn Alert** | CRON @6am | 12 | Retention / Alert |

---

## Workflow 1: Script Generator

**File:** `01-script-generator.json`
**Purpose:** Generates 60-second short-form video scripts using AI with MindFrame's brand voice.

### Trigger
```
POST /webhook/mindframe/script-generator
Body: {
  "hook_id": "uuid-of-viral-hook",
  "template_id": "uuid-of-content-template"
}
```

### Flow
```
Webhook → Fetch Hook from DB → Fetch Template from DB → 
Merge → OpenAI GPT-4 (brand-voice script) → Parse JSON output → 
Insert into content_scripts → Increment hook counter → Log
```

### Testing Steps
```bash
# 1. Activate workflow in n8n
# 2. Get a hook_id and template_id from the database
curl -X POST https://n8n.mindframe.ai/webhook/mindframe/script-generator \
  -H "Content-Type: application/json" \
  -d '{"hook_id": "<hook-uuid>", "template_id": "<template-uuid>"}'
# 3. Verify: SELECT * FROM content_scripts ORDER BY created_at DESC LIMIT 1;
# 4. Verify: SELECT * FROM viral_hooks WHERE id = '<hook-uuid>';
```

---

## Workflow 2: Lead Magnet Delivery

**File:** `02-lead-magnet-delivery.json`
**Purpose:** Captures new leads from the landing page, adds to Beehiiv, tags them, and delivers the 5-Minute Daily System.

### Trigger
```
POST /webhook/mindframe/lead-magnet
Body: {
  "email": "user@example.com",
  "name": "User Name",
  "source": "landing_page",
  "source_video_id": "optional-video-uuid",
  "double_opt_in": false,
  "ip": "optional-ip-address"
}
```

### Flow
```
Webhook → Validate email → Check for duplicate → 
If new: Insert subscriber → Create in Beehiiv → 
Apply source tag → Apply lead magnet tag → 
Send welcome email → Log
```

### Testing Steps
```bash
# 1. Activate workflow
# 2. Send test lead
curl -X POST https://n8n.mindframe.ai/webhook/mindframe/lead-magnet \
  -H "Content-Type: application/json" \
  -d '{"email": "test@mindframe.ai", "source": "landing_page"}'
# 3. Verify: SELECT * FROM email_subscribers ORDER BY created_at DESC;
# 4. Check Beehiiv dashboard for subscriber creation
```

---

## Workflow 3: Purchase Handler (Stripe)

**File:** `03-purchase-handler.json`
**Purpose:** Processes Stripe checkout completions, creates purchase records, grants access, and triggers onboarding.

### Trigger
Stripe webhook → `https://n8n.mindframe.ai/webhook/mindframe/stripe-purchase`

Configure in Stripe Dashboard: Settings → Webhooks → Add endpoint

### Events Handled
- `checkout.session.completed` — One-time purchases
- `checkout.session.async_payment_succeeded` — Async payments
- `customer.subscription.created` — New subscriptions (routes to workflow 07)

### Testing Steps
```bash
# 1. Activate workflow
# 2. In Stripe Dashboard: Create a test checkout session
# 3. Use Stripe test card: 4242 4242 4242 4242
# 4. Verify: SELECT * FROM purchases ORDER BY created_at DESC;
# 5. Verify: SELECT * FROM email_subscriber_tags WHERE subscriber_id = '<id>';
```

---

## Workflow 4: Daily Metrics Rollup

**File:** `04-daily-metrics-rollup.json`
**Purpose:** Runs at midnight to aggregate daily KPIs into `analytics_daily_metrics` and sends an admin email summary.

### Schedule
CRON: `0 0 * * *` (every day at midnight UTC)

### Flow
```
CRON → Aggregate funnel_events, purchases, subscribers, content, 
        workflows for yesterday → UPSERT into daily_metrics → 
        Update video daily totals → Log → Send admin email
```

### Key Metrics Calculated
- Revenue (tripwire, membership, automation packages)
- New subscribers and total subscriber count
- Videos published
- Content views and engagement
- Funnel conversion counts (each stage)
- Workflow success/failure counts

### Testing Steps
```bash
# 1. Activate workflow
# 2. Manually execute in n8n (click "Execute Workflow")
# 3. Verify: SELECT * FROM analytics_daily_metrics ORDER BY metric_date DESC;
# 4. Check admin email for summary
```

---

## Workflow 5: Welcome Sequence (5-Day Drip)

**File:** `05-welcome-sequence.json`
**Purpose:** Sends a 5-day email sequence to new leads/customers using Beehiiv's triggered campaigns.

### Trigger
```
POST /webhook/mindframe/welcome-sequence
Body: {
  "email": "user@example.com",
  "subscriber_id": "uuid",
  "trigger_type": "lead_magnet",   // or "purchase"
  "full_name": "User Name"
}
```

### Schedule
| Day | Email | Subject |
|-----|-------|---------|
| 1 | Immediate | 📥 [Download] Your 5-Minute Daily System |
| 2 | +24h | Why your to-do list is lying to you |
| 3 | +48h | How we do 4 hours of work in 1 hour |
| 4 | +72h | From "Burnt Out" to "Flow State" |
| 5 | +96h | Ready to go Pro? (Limited Opportunity) |

### Testing Steps
```bash
# 1. Create test campaigns in Beehiiv with the 5 subject lines
# 2. Set WELCOME_DAY1-5_CAMPAIGN_ID env vars
# 3. Trigger manually:
curl -X POST https://n8n.mindframe.ai/webhook/mindframe/welcome-sequence \
  -H "Content-Type: application/json" \
  -d '{"email": "test@mindframe.ai", "subscriber_id": "<existing-uuid>", "trigger_type": "lead_magnet", "full_name": "Test"}'
# 4. Check Beehiiv for sent campaigns
# 5. Verify: SELECT * FROM email_subscriber_tags WHERE tag_id IN (SELECT id FROM email_tags WHERE slug LIKE 'welcome%');
```

---

## Workflow 6: Affiliate Commission Processor

**File:** `06-affiliate-commission.json`
**Purpose:** Calculates and records affiliate commissions when a purchase is made via an affiliate link.

### Trigger
```
POST /webhook/mindframe/affiliate-commission
Body: {
  "purchase_id": "uuid",
  "affiliate_id": "uuid",
  "referral_code": "MINDFRAME-ABC123",
  "amount_cents": 2700,
  "product_type": "tripwire",
  "commission_pct": 40,
  "customer_email": "buyer@example.com",
  "is_recurring": false
}
```

### Commission Structure
| Product Type | Base Rate | Premium Tier | Elite Tier |
|-------------|-----------|---------------|------------|
| Digital Products | 40% | 44% (+10%) | 50% (+25%) |
| Membership ($19/mo) | 30% recurring | 33% recurring | 37.5% recurring |
| Automation Packages | 20% | 22% | 25% |

### Testing Steps
```bash
# 1. Ensure affiliate exists in affiliates table
# 2. Trigger manually:
curl -X POST https://n8n.mindframe.ai/webhook/mindframe/affiliate-commission \
  -H "Content-Type: application/json" \
  -d '{"purchase_id": "<uuid>", "affiliate_id": "<uuid>", "amount_cents": 2700, "product_type": "tripwire", "customer_email": "buyer@test.com"}'
# 3. Verify: SELECT * FROM affiliate_commissions ORDER BY created_at DESC;
# 4. Verify: SELECT * FROM affiliates WHERE id = '<id>';
```

---

## Workflow 7: Membership Sync (Stripe)

**File:** `07-membership-sync.json`
**Purpose:** Keeps the memberships table in sync with Stripe subscription lifecycle events.

### Trigger
Stripe webhook → `https://n8n.mindframe.ai/webhook/mindframe/membership-sync`

Configure in Stripe Dashboard: Settings → Webhooks → Add endpoint

### Events Handled
| Stripe Event | Action |
|-------------|--------|
| `customer.subscription.created` | Create membership, set member_since |
| `customer.subscription.updated` | Update period_end, cancel_at_period_end |
| `customer.subscription.deleted` | Set status=canceled, ended_at |

### Flow
```
Webhook → Parse Stripe event → Find/Create Profile → 
Upsert memberships row → Update profile.is_member → 
Log membership_events → Send welcome/update email → Log
```

### Testing Steps
```bash
# 1. In Stripe Dashboard, create a test subscription product ($19/month)
# 2. Use Stripe test card to subscribe
# 3. Verify: SELECT * FROM memberships ORDER BY created_at DESC;
# 4. Verify: SELECT id, email, is_member, member_since FROM profiles WHERE is_member = TRUE;
# 5. Verify: SELECT * FROM membership_events ORDER BY created_at DESC;
```

---

## Workflow 8: Churn Alert & Re-engagement

**File:** `08-churn-alert.json`
**Purpose:** Proactively identifies at-risk members and alerts admin of payment failures.

### Schedule
CRON: `0 6 * * *` (every day at 6am UTC)

### Three Checkpoints

**1. Expiring Soon (5 days)**
- Queries memberships ending within 5 days
- Sends reminder email via Beehiiv
- Tags subscriber as `churn-risk-expiring`

**2. Past Due / Failed Payments**
- Queries members in `past_due` or `incomplete` status
- Sends admin alert with affected member list

**3. Recently Churned (24 hours)**
- Queries members canceled in the last 24h
- Logs churn data to automation logs for analysis

### Testing Steps
```bash
# 1. Create a test membership expiring in the next 5 days
#    (You can manually set current_period_end in the DB for testing)
# 2. Execute workflow manually
# 3. Check beehiiv for reminder emails sent
# 4. Check admin email for past-due alert
# 5. Verify: SELECT * FROM email_subscriber_tags WHERE tag_id IN 
#    (SELECT id FROM email_tags WHERE slug = 'churn-risk-expiring');
```

---

## Webhook URL Table

| Workflow | Webhook Path | External Service |
|----------|-------------|-----------------|
| 01 - Script Generator | `/webhook/mindframe/script-generator` | Internal / Manual |
| 02 - Lead Magnet | `/webhook/mindframe/lead-magnet` | Landing Page (Framer) |
| 03 - Purchase Handler | `/webhook/mindframe/stripe-purchase` | Stripe Dashboard |
| 05 - Welcome Sequence | `/webhook/mindframe/welcome-sequence` | Internal (called by Workflows 2, 3) |
| 06 - Affiliate Commission | `/webhook/mindframe/affiliate-commission` | Internal (called by Workflow 3) |
| 07 - Membership Sync | `/webhook/mindframe/membership-sync` | Stripe Dashboard |

**Full webhook URL format:** `https://<your-n8n-domain>/webhook/<path>`

---

## Error Handling

All workflows log to `automation_execution_logs` with:
- `workflow_id` — Links to `automation_workflows` registry
- `status` — `success`, `failed`, or `running`
- `error_message` — Descriptive error text
- `input_data` — Request payload
- `output_data` — Response/result

### Alert Thresholds
- **Single failure:** Logged to DB for review
- **3+ failures in 1 hour:** Triggers admin email (workflow self-healing)
- **50% failure rate:** Manual check required

### Retry Logic
- n8n built-in: each node can retry up to 3 times with exponential backoff
- Webhook workflows: Stripe/Beehiiv retry webhooks automatically for 3 days

---

## Workflow Dependencies

```
Workflow 2 (Lead Magnet) ──calls──> Workflow 5 (Welcome Sequence)

Workflow 3 (Purchase Handler) ──calls──> Workflow 5 (Welcome Sequence)
                                      ──calls──> Workflow 6 (Affiliate Commission)

Workflow 7 (Membership Sync) ──called by──> Stripe (independent trigger)
```

No workflow has a hard dependency on another being active — they can be deployed incrementally.

---

## Troubleshooting

### "Workflow failed — HTTP 401"
**Cause:** Beehiiv API key expired or invalid.
**Fix:** Regenerate API key in Beehiiv Settings → API → Regenerate. Update in n8n credentials.

### "PostgreSQL insert returned no data"
**Cause:** Column mismatch in the INSERT node — schema may have changed.
**Fix:** Open the Postgres node and click "Refresh Schema" to sync columns.

### "Webhook not receiving requests"
**Cause:** n8n instance behind firewall or webhook URL misconfigured.
**Fix:** 
```bash
# Test n8n is publicly reachable
curl -I https://<your-n8n-domain>/healthz
# Should return HTTP 200
```

### "Welcome sequence emails not sending"
**Cause:** Campaign IDs not set in env vars, or campaigns not created in Beehiiv.
**Fix:** Create 5 campaigns in Beehiiv → copy IDs → set `WELCOME_DAY1-5_CAMPAIGN_ID`.

---

*For DB schema details: see `/home/team/shared/engineering/database-architecture.md`*
*For infrastructure setup: see `/home/team/shared/engineering/deployment-plan.md`*