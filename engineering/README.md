# MindFrame Database Architecture — README

## Overview

MindFrame's database is built on **Supabase (PostgreSQL 15+)** with 27 tables organized into 7 logical domains. The schema is designed for a faceless AI-powered self-improvement media brand with a complete content-to-revenue pipeline.

## Quick Start

```bash
# One command to create everything (run in Supabase SQL Editor):
# Paste the entire contents of schema.sql and execute
```

The file `/home/team/shared/engineering/schema.sql` is a single self-contained migration that creates all tables, indexes, RLS policies, and seeds 50 viral hooks.

## Schema Domains

| # | Domain | Tables | Purpose |
|---|--------|--------|---------|
| 1 | **Core & Auth** | `profiles`, `user_sessions` | User identity, auth integration, session tracking |
| 2 | **Content Pipeline** | `content_videos`, `content_scripts`, `content_templates`, `viral_hooks`, `content_publishing_queue` | Script generation, video publishing, hook performance, multi-platform scheduling |
| 3 | **Email Marketing** | `email_subscribers`, `email_tags`, `email_subscriber_tags`, `email_campaigns`, `email_campaign_logs` | Subscriber management, campaign automation, send/click/open tracking |
| 4 | **Commerce** | `digital_products`, `purchases`, `purchase_items`, `membership_plans`, `memberships`, `membership_events`, `automation_membership_blueprints` | Value ladder (free → $27 → $19/mo → $297), Stripe/Gumroad integration, subscription lifecycle |
| 5 | **Analytics** | `analytics_page_views`, `analytics_content_events`, `analytics_funnel_events`, `analytics_daily_metrics` | Content attribution, funnel conversion tracking, daily KPI rollups |
| 6 | **Affiliates** | `affiliates`, `affiliate_referrals`, `affiliate_commissions` | Partner program, referral tracking, commission management (one-time + recurring) |
| 7 | **Automation** | `automation_workflows`, `automation_execution_logs` | n8n workflow registry, execution monitoring, error tracking |

## Key Design Decisions

### Money as Integer Cents
All monetary values are stored as `INT` (cents) to avoid floating-point rounding errors.
- `price_cents`, `amount_cents`, `total_revenue_cents`
- Convert to dollars: `amount_cents / 100.0`

### Generated Columns
PostgreSQL `GENERATED ALWAYS AS ... STORED` columns compute derived values automatically:
- `profiles.duration_seconds` — from session start/end
- `purchases.net_revenue_cents` — amount minus fees
- `viral_hooks.performance_delta` — actual vs estimated score

### UUID Primary Keys
All tables use `UUID` primary keys with `gen_random_uuid()` for:
- Safe public-facing IDs (no sequential enumeration)
- Distributed ID generation (no contention)
- Consistent types across all foreign keys

### Partial Indexes
Several indexes use `WHERE` clauses to only index active/current rows:
```sql
CREATE INDEX idx_memberships_current_period ON memberships(current_period_end)
    WHERE status IN ('active', 'trialing');
```
This keeps index size small and query performance fast as the dataset grows.

### 3-Tier Row-Level Security
All 27 tables have RLS enforced with three policies:
| Role | Access | Used By |
|------|--------|---------|
| `service_role` | Full CRUD | Backend API, n8n automations |
| `authenticated` | Read own data | Logged-in users/customers |
| `anon` | Read public content | Website visitors |

### Funnel Attribution
The `analytics_funnel_events` table tracks the complete user journey from content view to purchase, linked through `source_video_id`:
```
content_view → profile_visit → landing_page_view → 
lead_magnet_download → tripwire_purchase → membership_purchased
```

## File Structure

```
/home/team/shared/engineering/
├── schema.sql                         # Single-file consolidated migration (run this!)
├── database-architecture.md           # Full architecture document (1,635 lines)
├── deployment-plan.md                 # 7-day deployment roadmap
└── sql/
    ├── 001_core.sql                   # Profiles, sessions, base tables
    ├── 002_content.sql                # Content pipeline tables
    ├── 003_email.sql                  # Email subscriber tables
    ├── 004_commerce.sql               # Commerce & membership tables
    ├── 005_analytics.sql              # Analytics & funnel tables
    ├── 006_affiliates.sql             # Affiliate tracking tables
    ├── 007_automation.sql             # Automation workflow tables
    ├── 008_indexes.sql                # Supplemental indexes
    ├── 009_rls_policies.sql           # Row-level security policies
    └── 010_seed_hooks.sql             # 50 viral hooks seed data
```

## Relationships Diagram (Text)

```
profiles ──┬── user_sessions (sessions per user)
           ├── email_subscribers (one-to-one optional)
           ├── purchases (purchase history)
           ├── memberships (active subscription)
           └── affiliates (affiliate profile, optional)

content_videos ──┬── viral_hooks (hook used)
                 ├── content_templates (template used)
                 ├── content_scripts (script used)
                 └── content_publishing_queue (multi-platform queue)

email_subscribers ──┬── email_subscriber_tags ──┬── email_tags
                    └── email_campaign_logs ────┬── email_campaigns

purchases ──┬── purchase_items ──┬── digital_products
            ├── affiliates (affiliate attribution)
            └── content_videos (source content)

memberships ──┬── membership_plans (tier definition)
              └── membership_events (lifecycle tracking)

affiliates ──┬── affiliate_referrals ──┬── affiliate_commissions
             │                         └── purchases
             └── profiles
```

## Monitoring Queries

```sql
-- Daily revenue snapshot
SELECT metric_date, total_revenue_cents / 100.0 AS revenue_dollars
FROM analytics_daily_metrics
WHERE metric_date >= NOW() - INTERVAL '30 days'
ORDER BY metric_date DESC;

-- Top performing hooks (live)
SELECT hook_text, category, estimated_performance, actual_performance
FROM viral_hooks
WHERE actual_performance IS NOT NULL
ORDER BY actual_performance DESC
LIMIT 20;

-- Automation health (last 24h)
SELECT w.name, 
       COUNT(*) FILTER (WHERE l.status = 'failed') AS failures,
       COUNT(*) FILTER (WHERE l.status = 'success') AS successes
FROM automation_workflows w
LEFT JOIN automation_execution_logs l ON l.workflow_id = w.id
WHERE l.started_at >= NOW() - INTERVAL '24 hours'
GROUP BY w.id, w.name;
```

## Cost Estimate (Supabase Free Tier)

| Resource | Limit | MindFrame Est. |
|----------|-------|----------------|
| Database | 500 MB | ~50 MB |
| Auth Users | 50,000 | ~5,000 |
| Bandwidth | 2 GB | ~500 MB |
| Edge Functions | 500K/mo | ~100K |

The schema is designed to run on Supabase's free tier for the first 90+ days of operation.

---

*See `/home/team/shared/engineering/database-architecture.md` for the full 1,635-line architecture document.*
*See `/home/team/shared/engineering/deployment-plan.md` for the 7-day rollout plan.*