# MindFrame Database Architecture

> **Author:** Systems Engineer
> **Date:** 2025-06-07
> **Target:** Supabase (PostgreSQL 15+)
> **Status:** v1.0 — Ready for implementation

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Schema: Auth & Users](#2-schema-auth--users)
3. [Schema: Content Library](#3-schema-content-library)
4. [Schema: Viral Hooks Database](#4-schema-viral-hooks-database)
5. [Schema: Email Subscribers](#5-schema-email-subscribers)
6. [Schema: Digital Products & Purchases](#6-schema-digital-products--purchases)
7. [Schema: Memberships](#7-schema-memberships)
8. [Schema: Analytics & Events](#8-schema-analytics--events)
9. [Schema: Affiliate Tracking](#9-schema-affiliate-tracking)
10. [Schema: Automation Logs](#10-schema-automation-logs)
11. [Indexes](#11-indexes)
12. [Row Level Security Policies](#12-row-level-security-policies)
13. [ER Diagram (Text)](#13-er-diagram-text)
14. [Deployment Notes](#14-deployment-notes)

---

## 1. Architecture Overview

### Naming Conventions
- All tables use **snake_case** plural names
- All primary keys are `uuid` type with `gen_random_uuid()` default
- All foreign keys reference the parent table's `id` column
- All tables include `created_at` and `updated_at` timestamps
- Junction tables use the pattern `{table1}_{table2}` (alphabetical order)

### Domain Groups
The schema is organized into 7 logical domains, each with its own schema prefix in comments:

| Domain | Prefix | Purpose |
|--------|--------|---------|
| Auth & Users | `auth_` | Supabase Auth + app profiles |
| Content | `content_` | Videos, scripts, templates, hooks |
| Email | `email_` | Subscribers, campaigns, sequences |
| Commerce | `commerce_` | Products, purchases, memberships |
| Analytics | `analytics_` | Events, conversions, page views |
| Affiliates | `affiliate_` | Partners, referrals, commissions |
| Automation | `automation_` | n8n workflows, execution logs |

### Trigger Pattern
All tables share this update trigger:

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

## 2. Schema: Auth & Users

### Table: `profiles`
Stores extended user profile data linked to Supabase Auth.

```sql
CREATE TABLE profiles (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_id     UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    email       TEXT UNIQUE NOT NULL,
    full_name   TEXT,
    avatar_url  TEXT,
    
    -- Marketing preferences
    email_opt_in    BOOLEAN DEFAULT TRUE,
    marketing_consent_granted_at TIMESTAMPTZ,
    marketing_consent_ip         INET,
    
    -- Subscription & membership status
    is_member           BOOLEAN DEFAULT FALSE,
    member_since        TIMESTAMPTZ,
    stripe_customer_id  TEXT UNIQUE,
    
    -- Referral tracking
    referred_by     UUID REFERENCES profiles(id) ON DELETE SET NULL,
    referral_code   TEXT UNIQUE,
    
    -- Metadata
    metadata        JSONB DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger
CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### Table: `user_sessions`
Tracks active sessions and device info for analytics.

```sql
CREATE TABLE user_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    session_token   TEXT NOT NULL,
    
    -- Device & context
    user_agent      TEXT,
    ip_address      INET,
    referrer_url    TEXT,
    landing_page    TEXT,
    
    -- Session metrics
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_active_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ,
    duration_seconds INT GENERATED ALWAYS AS (
        CASE WHEN ended_at IS NOT NULL 
             THEN EXTRACT(EPOCH FROM (ended_at - started_at))::INT 
             ELSE NULL 
        END
    ) STORED
);

CREATE INDEX idx_user_sessions_profile_id ON user_sessions(profile_id);
CREATE INDEX idx_user_sessions_started_at ON user_sessions(started_at);
```

---

## 3. Schema: Content Library

### Table: `content_videos`
Tracks every published video across all platforms.

```sql
CREATE TABLE content_videos (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Content identification
    title           TEXT NOT NULL,
    slug            TEXT UNIQUE NOT NULL,
    hook_id         UUID REFERENCES viral_hooks(id) ON DELETE SET NULL,
    template_id     UUID REFERENCES content_templates(id) ON DELETE SET NULL,
    
    -- Script details
    script_id       UUID REFERENCES content_scripts(id) ON DELETE SET NULL,
    script_text     TEXT NOT NULL,
    word_count      INT,
    
    -- Platform distribution
    platforms       TEXT[] NOT NULL DEFAULT '{}', -- {'tiktok', 'instagram', 'youtube'}
    published_at    TIMESTAMPTZ,
    scheduled_for   TIMESTAMPTZ,
    
    -- File references
    video_url       TEXT,
    thumbnail_url   TEXT,
    s3_storage_path TEXT,
    duration_seconds INT,
    
    -- AI generation metadata
    ai_model        TEXT DEFAULT 'elevenlabs',
    ai_voice_id     TEXT,
    
    -- Status
    status          TEXT NOT NULL DEFAULT 'draft' 
                    CHECK (status IN ('draft', 'rendering', 'scheduled', 'published', 'failed', 'archived')),
    
    -- Performance (updated by analytics pipeline)
    total_views         BIGINT DEFAULT 0,
    total_likes         BIGINT DEFAULT 0,
    total_shares        BIGINT DEFAULT 0,
    total_comments      BIGINT DEFAULT 0,
    total_saves         BIGINT DEFAULT 0,
    avg_watch_seconds   DECIMAL(5,2),
    
    -- CTA tracking
    cta_type        TEXT, -- 'link_in_bio', 'download', 'join', 'comment'
    cta_url         TEXT,
    cta_clicks      BIGINT DEFAULT 0,
    
    -- SEO metadata
    seo_tags        TEXT[],
    seo_description TEXT,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_content_videos_status ON content_videos(status);
CREATE INDEX idx_content_videos_published_at ON content_videos(published_at);
CREATE INDEX idx_content_videos_hook_id ON content_videos(hook_id);
CREATE INDEX idx_content_videos_platforms ON content_videos USING GIN(platforms);
```

### Table: `content_scripts`
Stores the script text and AI generation parameters.

```sql
CREATE TABLE content_scripts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Script content
    title           TEXT NOT NULL,
    hook_text       TEXT NOT NULL,
    body_text       TEXT NOT NULL,
    cta_text        TEXT,
    
    -- AI generation
    ai_prompt       TEXT,
    ai_temperature  DECIMAL(3,2) DEFAULT 0.7,
    ai_model        TEXT DEFAULT 'gpt-4',
    tokens_used     INT,
    
    -- Version control
    version         INT NOT NULL DEFAULT 1,
    previous_version_id UUID REFERENCES content_scripts(id) ON DELETE SET NULL,
    
    -- Metadata
    tags            TEXT[] DEFAULT '{}',
    category        TEXT, -- 'myth_busting', 'pain_point', 'how_to', 'transformation', etc.
    estimated_performance DECIMAL(3,1), -- 0.0-10.0
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_content_scripts_category ON content_scripts(category);
CREATE INDEX idx_content_scripts_tags ON content_scripts USING GIN(tags);
```

### Table: `content_templates`
Stores the 10 script templates (see CONTENT_TEMPLATES.md).

```sql
CREATE TABLE content_templates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name            TEXT NOT NULL UNIQUE,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,
    
    -- Template structure
    hook_format     TEXT NOT NULL, -- e.g., "Everyone tells you [X]. They're wrong."
    point_1_framework TEXT NOT NULL,
    point_2_framework TEXT NOT NULL,
    point_3_framework TEXT NOT NULL,
    cta_framework   TEXT NOT NULL,
    
    -- Category & triggers
    category        TEXT NOT NULL, -- 'myth_busting', 'pain_point', 'how_to', etc.
    primary_trigger TEXT, -- 'loss_aversion', 'curiosity', 'contrarian', etc.
    
    -- Performance
    avg_performance     DECIMAL(3,1) DEFAULT 0.0,
    times_used          INT DEFAULT 0,
    is_active           BOOLEAN DEFAULT TRUE,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Table: `viral_hooks`
Structured database of viral hooks (imported from HOOKS_DATABASE.json).

```sql
CREATE TABLE viral_hooks (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    hook_text           TEXT NOT NULL,
    category            TEXT NOT NULL, -- 'Discipline', 'Mindset', 'Productivity', 'Health', 'Money', 'Relationships'
    trigger_type        TEXT NOT NULL, -- 'Loss Aversion', 'Curiosity', 'Contrarian', 'Fear/Urgency', etc.
    
    -- Performance scoring
    estimated_performance   DECIMAL(3,1) NOT NULL CHECK (estimated_performance >= 0 AND estimated_performance <= 10),
    actual_performance      DECIMAL(3,1), -- Updated from real analytics
    performance_delta       DECIMAL(4,2) GENERATED ALWAYS AS (
        CASE WHEN actual_performance IS NOT NULL 
             THEN actual_performance - estimated_performance 
             ELSE NULL 
        END
    ) STORED,
    
    -- Usage tracking
    times_used          INT DEFAULT 0,
    last_used_at        TIMESTAMPTZ,
    
    -- A/B test variants
    variant_group       TEXT, -- 'A', 'B', or NULL if untested
    winning_variant_id  UUID REFERENCES viral_hooks(id) ON DELETE SET NULL,
    
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_viral_hooks_category ON viral_hooks(category);
CREATE INDEX idx_viral_hooks_trigger_type ON viral_hooks(trigger_type);
CREATE INDEX idx_viral_hooks_performance ON viral_hooks(estimated_performance DESC);
CREATE INDEX idx_viral_hooks_actual_performance ON viral_hooks(actual_performance DESC NULLS LAST);
```

### Table: `content_publishing_queue`
Queue for scheduled/pending video publications.

```sql
CREATE TABLE content_publishing_queue (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id        UUID NOT NULL REFERENCES content_videos(id) ON DELETE CASCADE,
    
    platform        TEXT NOT NULL CHECK (platform IN ('tiktok', 'instagram', 'youtube')),
    scheduled_for   TIMESTAMPTZ NOT NULL,
    published_at    TIMESTAMPTZ,
    
    status          TEXT NOT NULL DEFAULT 'queued'
                    CHECK (status IN ('queued', 'processing', 'published', 'failed', 'skipped')),
    
    -- Platform-specific IDs
    platform_post_id    TEXT,
    platform_url        TEXT,
    
    -- Error handling
    error_message   TEXT,
    retry_count     INT DEFAULT 0,
    max_retries     INT DEFAULT 3,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_publishing_queue_status ON content_publishing_queue(status);
CREATE INDEX idx_publishing_queue_scheduled ON content_publishing_queue(scheduled_for)
    WHERE status = 'queued';
```

---

## 4. Schema: Viral Hooks Database

*(Already defined in `viral_hooks` table above — this section documents the import pipeline.)*

### Hooks Import & Sync

The existing `HOOKS_DATABASE.json` (50 hooks) is the seed data. The import workflow:

1. **n8n webhook trigger** receives new hooks from Content Architect
2. **Duplicate detection** via `hook_text` UNIQUE constraint
3. **Category validation** against allowed categories
4. **Score normalization** (0-10 scale)

```sql
-- Additional constraint for hook uniqueness
ALTER TABLE viral_hooks ADD CONSTRAINT uq_viral_hooks_text UNIQUE (hook_text);
```

---

## 5. Schema: Email Subscribers

### Table: `email_subscribers`
Synced with Beehiiv/ConvertKit via webhook.

```sql
CREATE TABLE email_subscribers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    email           TEXT UNIQUE NOT NULL,
    profile_id      UUID REFERENCES profiles(id) ON DELETE SET NULL,
    
    -- Source tracking
    source          TEXT NOT NULL -- 'lead_magnet', 'purchase', 'tripwire', 'landing_page', 'manual'
                    CHECK (source IN ('lead_magnet', 'purchase', 'tripwire', 'landing_page', 'manual', 'referral')),
    source_url      TEXT, -- The page URL where they subscribed
    source_video_id UUID REFERENCES content_videos(id) ON DELETE SET NULL,
    
    -- Status
    status          TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'unsubscribed', 'bounced', 'spam')),
    unsubscribed_at TIMESTAMPTZ,
    bounce_reason   TEXT,
    
    -- Engagement metrics
    last_opened_at      TIMESTAMPTZ,
    last_clicked_at     TIMESTAMPTZ,
    total_opens         INT DEFAULT 0,
    total_clicks        INT DEFAULT 0,
    open_rate           DECIMAL(5,4) GENERATED ALWAYS AS (
        CASE WHEN total_opens > 0 THEN total_opens::DECIMAL / NULLIF(total_emails_sent, 0) ELSE 0 END
    ) STORED,
    total_emails_sent   INT DEFAULT 0,
    
    -- Purchase tracking
    has_purchased       BOOLEAN DEFAULT FALSE,
    lifetime_value      DECIMAL(10,2) DEFAULT 0.00,
    
    -- External IDs
    beehiiv_subscriber_id  TEXT,
    convertkit_subscriber_id TEXT,
    
    -- Consent
    double_opt_in_confirmed BOOLEAN DEFAULT FALSE,
    consent_ip              INET,
    consent_timestamp       TIMESTAMPTZ,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_email_subscribers_status ON email_subscribers(status);
CREATE INDEX idx_email_subscribers_source ON email_subscribers(source);
CREATE INDEX idx_email_subscribers_profile_id ON email_subscribers(profile_id);
CREATE INDEX idx_email_subscribers_created_at ON email_subscribers(created_at);
```

### Table: `email_tags`

```sql
CREATE TABLE email_tags (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL UNIQUE,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,
    color           TEXT DEFAULT '#6366f1',
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Table: `email_subscriber_tags`
Junction table — many-to-many between subscribers and tags.

```sql
CREATE TABLE email_subscriber_tags (
    subscriber_id   UUID NOT NULL REFERENCES email_subscribers(id) ON DELETE CASCADE,
    tag_id          UUID NOT NULL REFERENCES email_tags(id) ON DELETE CASCADE,
    applied_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (subscriber_id, tag_id)
);

CREATE INDEX idx_subscriber_tags_tag_id ON email_subscriber_tags(tag_id);
```

### Table: `email_campaigns`

```sql
CREATE TABLE email_campaigns (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name            TEXT NOT NULL,
    sequence_name   TEXT NOT NULL, -- 'welcome_5day', 'nurture_biweekly', 'sales_vault', 'reengagement', 'abandoned_cart'
    step_number     INT NOT NULL, -- Day 1, Day 2, etc. within the sequence
    subject         TEXT NOT NULL,
    preview_text    TEXT,
    
    -- Content
    body_html       TEXT,
    body_text       TEXT,
    
    -- Targeting
    target_tags     UUID[] DEFAULT '{}', -- Array of tag IDs to target
    exclude_tags    UUID[] DEFAULT '{}',
    
    -- Scheduling
    delay_hours     INT DEFAULT 0, -- Hours after previous email or trigger event
    send_at         TIMESTAMPTZ,
    status          TEXT NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft', 'active', 'sending', 'completed', 'paused', 'archived')),
    
    -- Performance
    total_sent      INT DEFAULT 0,
    total_opens     INT DEFAULT 0,
    total_clicks    INT DEFAULT 0,
    total_unsubs    INT DEFAULT 0,
    open_rate       DECIMAL(5,4) GENERATED ALWAYS AS (
        CASE WHEN total_sent > 0 THEN total_opens::DECIMAL / total_sent ELSE 0 END
    ) STORED,
    click_rate      DECIMAL(5,4) GENERATED ALWAYS AS (
        CASE WHEN total_opens > 0 THEN total_clicks::DECIMAL / total_opens ELSE 0 END
    ) STORED,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_email_campaigns_sequence ON email_campaigns(sequence_name, step_number);
CREATE INDEX idx_email_campaigns_status ON email_campaigns(status);
```

### Table: `email_campaign_logs`
Individual send events.

```sql
CREATE TABLE email_campaign_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id     UUID NOT NULL REFERENCES email_campaigns(id) ON DELETE CASCADE,
    subscriber_id   UUID NOT NULL REFERENCES email_subscribers(id) ON DELETE CASCADE,
    
    -- Delivery status
    sent_at         TIMESTAMPTZ,
    delivered_at    TIMESTAMPTZ,
    opened_at       TIMESTAMPTZ,
    clicked_at      TIMESTAMPTZ,
    unsubscribed_at TIMESTAMPTZ,
    
    -- Engagement detail
    open_count      INT DEFAULT 0,
    click_count     INT DEFAULT 0,
    last_open_at    TIMESTAMPTZ,
    last_click_at   TIMESTAMPTZ,
    
    -- Links clicked
    clicked_links   JSONB DEFAULT '[]'::jsonb, -- [{url: "...", timestamp: "..."}]
    
    -- Error tracking
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'sent', 'delivered', 'opened', 'clicked', 'bounced', 'failed', 'unsubscribed')),
    error_message   TEXT,
    
    -- External
    message_id      TEXT, -- ESP's message ID
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_campaign_logs_campaign ON email_campaign_logs(campaign_id);
CREATE INDEX idx_campaign_logs_subscriber ON email_campaign_logs(subscriber_id);
CREATE INDEX idx_campaign_logs_status ON email_campaign_logs(status);
CREATE INDEX idx_campaign_logs_sent_at ON email_campaign_logs(sent_at);
```

---

## 6. Schema: Digital Products & Purchases

### Table: `digital_products`

```sql
CREATE TABLE digital_products (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name            TEXT NOT NULL,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,
    
    -- Pricing
    price_cents     INT NOT NULL CHECK (price_cents >= 0),
    currency        TEXT NOT NULL DEFAULT 'usd',
    compare_at_price_cents INT, -- For showing "was $X"
    
    -- Product type (value ladder position)
    product_type    TEXT NOT NULL
                    CHECK (product_type IN ('lead_magnet', 'tripwire', 'membership', 'automation_package', 'bundle')),
    
    -- Digital assets
    file_urls       JSONB DEFAULT '[]'::jsonb, -- [{name: "PDF", url: "..."}]
    gumroad_product_id  TEXT,
    stripe_price_id     TEXT,
    
    -- Commission structure
    affiliate_commission_pct DECIMAL(5,2) DEFAULT 0.00, -- 40.00 = 40%
    
    -- Inventory (NULL = unlimited)
    inventory_count     INT,
    inventory_remaining INT,
    
    -- Status
    is_active       BOOLEAN DEFAULT TRUE,
    is_featured     BOOLEAN DEFAULT FALSE,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_digital_products_type ON digital_products(product_type);
CREATE INDEX idx_digital_products_active ON digital_products(is_active) WHERE is_active = TRUE;
```

### Table: `purchases`

```sql
CREATE TABLE purchases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    product_id      UUID NOT NULL REFERENCES digital_products(id) ON DELETE RESTRICT,
    profile_id      UUID REFERENCES profiles(id) ON DELETE SET NULL,
    subscriber_id   UUID REFERENCES email_subscribers(id) ON DELETE SET NULL,
    
    -- Customer info (for guest checkout)
    customer_email      TEXT NOT NULL,
    customer_name       TEXT,
    
    -- Transaction
    amount_cents        INT NOT NULL,
    currency            TEXT NOT NULL DEFAULT 'usd',
    fee_cents           INT DEFAULT 0,
    net_revenue_cents   INT GENERATED ALWAYS AS (amount_cents - fee_cents) STORED,
    
    -- Payment processor
    processor           TEXT NOT NULL DEFAULT 'stripe' CHECK (processor IN ('stripe', 'gumroad', 'paypal')),
    processor_charge_id TEXT,
    processor_payment_intent TEXT,
    
    -- Status
    status              TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'completed', 'refunded', 'partially_refunded', 'failed', 'disputed')),
    refunded_at         TIMESTAMPTZ,
    refund_amount_cents INT,
    
    -- Affiliate
    affiliate_id     UUID REFERENCES affiliates(id) ON DELETE SET NULL,
    affiliate_commission_cents INT DEFAULT 0,
    
    -- Funnel tracking
    source_video_id  UUID REFERENCES content_videos(id) ON DELETE SET NULL,
    source_url       TEXT,
    utm_source       TEXT,
    utm_medium       TEXT,
    utm_campaign     TEXT,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_purchases_product_id ON purchases(product_id);
CREATE INDEX idx_purchases_profile_id ON purchases(profile_id);
CREATE INDEX idx_purchases_status ON purchases(status);
CREATE INDEX idx_purchases_created_at ON purchases(created_at);
CREATE INDEX idx_purchases_affiliate_id ON purchases(affiliate_id);
CREATE INDEX idx_purchases_utm ON purchases(utm_source, utm_medium, utm_campaign);
```

### Table: `purchase_items`
For bundles — individual line items.

```sql
CREATE TABLE purchase_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_id     UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES digital_products(id) ON DELETE RESTRICT,
    
    quantity        INT NOT NULL DEFAULT 1,
    unit_price_cents INT NOT NULL,
    total_cents     INT GENERATED ALWAYS AS (quantity * unit_price_cents) STORED,
    
    -- Fulfillment
    download_url    TEXT,
    download_count  INT DEFAULT 0,
    access_granted  BOOLEAN DEFAULT FALSE,
    access_granted_at TIMESTAMPTZ,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_purchase_items_purchase_id ON purchase_items(purchase_id);
```

---

## 7. Schema: Memberships

### Table: `membership_plans`

```sql
CREATE TABLE membership_plans (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name            TEXT NOT NULL, -- 'Monthly', 'Annual'
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,
    
    -- Pricing
    price_cents     INT NOT NULL CHECK (price_cents > 0),
    currency        TEXT NOT NULL DEFAULT 'usd',
    interval        TEXT NOT NULL CHECK (interval IN ('month', 'year')),
    
    -- Stripe
    stripe_price_id     TEXT,
    stripe_product_id   TEXT,
    
    -- Perks
    features        JSONB DEFAULT '[]'::jsonb, -- ["Automation Vault Access", "Weekly Pulse", ... ]
    
    is_active       BOOLEAN DEFAULT TRUE,
    sort_order      INT DEFAULT 0,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Table: `memberships`

```sql
CREATE TABLE memberships (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    profile_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    plan_id         UUID NOT NULL REFERENCES membership_plans(id) ON DELETE RESTRICT,
    
    -- Billing
    stripe_subscription_id  TEXT UNIQUE,
    stripe_customer_id      TEXT,
    
    -- Status
    status          TEXT NOT NULL DEFAULT 'trialing'
                    CHECK (status IN ('trialing', 'active', 'past_due', 'canceled', 'incomplete', 'incomplete_expired')),
    
    -- Timing
    current_period_start    TIMESTAMPTZ NOT NULL,
    current_period_end      TIMESTAMPTZ NOT NULL,
    trial_start             TIMESTAMPTZ,
    trial_end               TIMESTAMPTZ,
    canceled_at             TIMESTAMPTZ,
    ended_at                TIMESTAMPTZ,
    
    -- Cancellation
    cancel_at_period_end    BOOLEAN DEFAULT FALSE,
    cancellation_reason     TEXT,
    cancellation_reason_detail TEXT,
    
    -- Pricing snapshot
    price_cents_at_subscription INT NOT NULL,
    
    -- Retention
    referral_count          INT DEFAULT 0,
    lifetime_value_cents    INT DEFAULT 0,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_memberships_profile_id ON memberships(profile_id);
CREATE INDEX idx_memberships_status ON memberships(status);
CREATE INDEX idx_memberships_current_period ON memberships(current_period_end);
```

### Table: `membership_events`
Tracks lifecycle events (signup, renewal, upgrade, downgrade, cancel, reactivate).

```sql
CREATE TABLE membership_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    membership_id   UUID NOT NULL REFERENCES memberships(id) ON DELETE CASCADE,
    profile_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    event_type      TEXT NOT NULL
                    CHECK (event_type IN ('created', 'renewed', 'upgraded', 'downgraded', 'canceled', 'reactivated', 'expired', 'payment_failed')),
    
    -- Snapshot at event time
    previous_plan_id    UUID REFERENCES membership_plans(id),
    new_plan_id         UUID REFERENCES membership_plans(id),
    previous_price      INT,
    new_price           INT,
    
    -- Metadata
    metadata        JSONB DEFAULT '{}'::jsonb,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_membership_events_membership ON membership_events(membership_id);
CREATE INDEX idx_membership_events_type ON membership_events(event_type);
CREATE INDEX idx_membership_events_created ON membership_events(created_at);
```

---

## 8. Schema: Analytics & Events

### Table: `analytics_page_views`
Page views across the MindFrame web properties.

```sql
CREATE TABLE analytics_page_views (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    profile_id      UUID REFERENCES profiles(id) ON DELETE SET NULL,
    session_id      UUID REFERENCES user_sessions(id) ON DELETE SET NULL,
    
    -- Page
    url             TEXT NOT NULL,
    path            TEXT NOT NULL,
    referrer_url    TEXT,
    
    -- UTM parameters
    utm_source      TEXT,
    utm_medium      TEXT,
    utm_campaign    TEXT,
    utm_content     TEXT,
    utm_term        TEXT,
    
    -- Device
    user_agent      TEXT,
    device_type     TEXT, -- 'mobile', 'tablet', 'desktop'
    browser         TEXT,
    os              TEXT,
    ip_address      INET,
    country         TEXT,
    
    -- Timing
    page_load_ms    INT,
    time_on_page_seconds INT,
    
    viewed_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_page_views_path ON analytics_page_views(path);
CREATE INDEX idx_page_views_viewed_at ON analytics_page_views(viewed_at);
CREATE INDEX idx_page_views_utm ON analytics_page_views(utm_source, utm_medium, utm_campaign);
CREATE INDEX idx_page_views_profile ON analytics_page_views(profile_id);
```

### Table: `analytics_content_events`
Content performance events per platform.

```sql
CREATE TABLE analytics_content_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    video_id        UUID NOT NULL REFERENCES content_videos(id) ON DELETE CASCADE,
    platform        TEXT NOT NULL CHECK (platform IN ('tiktok', 'instagram', 'youtube')),
    
    -- Time-series aggregate (daily snapshots)
    event_date      DATE NOT NULL,
    
    -- Metrics
    views           INT DEFAULT 0,
    likes           INT DEFAULT 0,
    shares          INT DEFAULT 0,
    comments        INT DEFAULT 0,
    saves           INT DEFAULT 0,
    avg_watch_seconds   DECIMAL(5,2),
    completion_rate     DECIMAL(5,4), -- % watched to end
    follower_gain       INT DEFAULT 0,
    
    -- Discovery
    reach           INT,
    impressions     INT,
    from_fyp        INT,         -- From For You Page / Explore tab
    from_profile    INT,
    from_search     INT,
    from_hashtags   INT,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(video_id, platform, event_date)
);

CREATE INDEX idx_content_events_video ON analytics_content_events(video_id);
CREATE INDEX idx_content_events_date ON analytics_content_events(event_date);
CREATE INDEX idx_content_events_platform ON analytics_content_events(platform, event_date);
```

### Table: `analytics_funnel_events`
Tracks user progression through the marketing funnel.

```sql
CREATE TABLE analytics_funnel_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    profile_id      UUID REFERENCES profiles(id) ON DELETE SET NULL,
    anonymous_id    TEXT, -- Fingerprint for non-logged-in users
    session_id      UUID REFERENCES user_sessions(id) ON DELETE SET NULL,
    
    -- Funnel stage
    stage           TEXT NOT NULL
                    CHECK (stage IN (
                        'content_view',        -- Viewed a video
                        'profile_visit',       -- Clicked through to profile
                        'landing_page_view',   -- Viewed landing page
                        'lead_magnet_download',-- Downloaded free lead magnet
                        'tripwire_view',       -- Viewed tripwire offer
                        'tripwire_purchase',   -- Purchased tripwire ($27)
                        'membership_view',     -- Viewed membership page
                        'membership_started',  -- Started checkout
                        'membership_purchased',-- Bought membership
                        'automation_package_view',
                        'automation_package_purchase',
                        'affiliate_signup',    -- Signed up as affiliate
                        'referral_click'       -- Clicked referral link
                    )),
    
    -- Source attribution
    source_video_id UUID REFERENCES content_videos(id) ON DELETE SET NULL,
    source_url      TEXT,
    referrer_url    TEXT,
    utm_source      TEXT,
    utm_medium      TEXT,
    utm_campaign    TEXT,
    
    -- Revenue
    revenue_cents   INT DEFAULT 0,
    
    -- Time
    time_to_convert_seconds INT, -- Time spent between stages
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_funnel_events_stage ON analytics_funnel_events(stage, created_at);
CREATE INDEX idx_funnel_events_profile ON analytics_funnel_events(profile_id);
CREATE INDEX idx_funnel_events_source_video ON analytics_funnel_events(source_video_id);
CREATE INDEX idx_funnel_events_created ON analytics_funnel_events(created_at);
```

### Table: `analytics_daily_metrics`
Rollup table for dashboard KPIs.

```sql
CREATE TABLE analytics_daily_metrics (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_date     DATE NOT NULL UNIQUE,
    
    -- Content metrics
    videos_published    INT DEFAULT 0,
    total_content_views BIGINT DEFAULT 0,
    total_engagement    BIGINT DEFAULT 0, -- likes + shares + comments + saves
    
    -- Growth metrics
    new_followers       INT DEFAULT 0,
    total_followers     BIGINT DEFAULT 0,
    
    -- Funnel metrics
    profile_visits      INT DEFAULT 0,
    landing_page_views  INT DEFAULT 0,
    new_subscribers     INT DEFAULT 0,
    total_subscribers   INT DEFAULT 0,
    
    -- Revenue metrics
    lead_magnet_downloads   INT DEFAULT 0,
    tripwire_sales          INT DEFAULT 0,
    tripwire_revenue_cents  INT DEFAULT 0,
    membership_new_sales    INT DEFAULT 0,
    membership_revenue_cents    INT DEFAULT 0,
    automation_package_sales    INT DEFAULT 0,
    automation_revenue_cents    INT DEFAULT 0,
    affiliate_payouts_cents     INT DEFAULT 0,
    total_revenue_cents         INT DEFAULT 0,
    
    -- Retention
    active_members      INT DEFAULT 0,
    churned_members     INT DEFAULT 0,
    churn_rate          DECIMAL(5,4),
    membership_churn_rate DECIMAL(5,4),
    
    -- Automation
    workflows_run       INT DEFAULT 0,
    workflows_failed    INT DEFAULT 0,
    automation_uptime_pct DECIMAL(5,2),
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## 9. Schema: Affiliate Tracking

### Table: `affiliates`

```sql
CREATE TABLE affiliates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    profile_id      UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    email           TEXT NOT NULL,
    full_name       TEXT NOT NULL,
    paypal_email    TEXT,
    wise_email      TEXT,
    
    -- Referral
    referral_code       TEXT UNIQUE NOT NULL,
    referral_link       TEXT NOT NULL, -- Full URL
    cookie_days         INT DEFAULT 60,
    
    -- Commission
    commission_pct      DECIMAL(5,2) NOT NULL DEFAULT 30.00,
    lifetime_value_share BOOLEAN DEFAULT FALSE,
    
    -- Tiers
    tier            TEXT NOT NULL DEFAULT 'standard'
                    CHECK (tier IN ('standard', 'premium', 'elite')),
    total_earned_cents  INT DEFAULT 0,
    total_paid_cents    INT DEFAULT 0,
    pending_cents       INT DEFAULT 0,
    
    -- Status
    is_active       BOOLEAN DEFAULT TRUE,
    approved_at     TIMESTAMPTZ,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_affiliates_referral_code ON affiliates(referral_code);
CREATE INDEX idx_affiliates_tier ON affiliates(tier);
CREATE INDEX idx_affiliates_is_active ON affiliates(is_active) WHERE is_active = TRUE;
```

### Table: `affiliate_referrals`

```sql
CREATE TABLE affiliate_referrals (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    affiliate_id    UUID NOT NULL REFERENCES affiliates(id) ON DELETE CASCADE,
    referred_email  TEXT NOT NULL,
    referred_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    
    -- Referral context
    source_url      TEXT,
    clicked_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    converted_at    TIMESTAMPTZ,
    
    -- Conversion tracking
    converted       BOOLEAN DEFAULT FALSE,
    purchase_id     UUID REFERENCES purchases(id) ON DELETE SET NULL,
    purchase_amount_cents INT,
    
    commission_cents    INT,
    commission_paid     BOOLEAN DEFAULT FALSE,
    commission_paid_at  TIMESTAMPTZ,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_affiliate_referrals_affiliate ON affiliate_referrals(affiliate_id);
CREATE INDEX idx_affiliate_referrals_converted ON affiliate_referrals(converted, converted_at);
```

### Table: `affiliate_commissions`

```sql
CREATE TABLE affiliate_commissions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    affiliate_id    UUID NOT NULL REFERENCES affiliates(id) ON DELETE CASCADE,
    referral_id     UUID REFERENCES affiliate_referrals(id) ON DELETE SET NULL,
    
    -- Commission breakdown
    amount_cents        INT NOT NULL,
    currency            TEXT NOT NULL DEFAULT 'usd',
    commission_type     TEXT NOT NULL CHECK (commission_type IN ('one_time', 'recurring')),
    recurrence_number   INT, -- Which month of recurring commission
    
    -- Source
    source_purchase_id  UUID REFERENCES purchases(id) ON DELETE SET NULL,
    source_membership_id UUID REFERENCES memberships(id) ON DELETE SET NULL,
    
    -- Status
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'approved', 'paid', 'cancelled', 'refunded')),
    
    -- Payment
    payout_id       TEXT, -- PayPal/Wise transaction ID
    paid_at         TIMESTAMPTZ,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_affiliate_commissions_affiliate ON affiliate_commissions(affiliate_id);
CREATE INDEX idx_affiliate_commissions_status ON affiliate_commissions(status);
CREATE INDEX idx_affiliate_commissions_pending ON affiliate_commissions(status, created_at)
    WHERE status = 'pending';
```

---

## 10. Schema: Automation Logs

### Table: `automation_workflows`
Registry of all n8n/Make/Zapier workflows.

```sql
CREATE TABLE automation_workflows (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name            TEXT NOT NULL,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,
    
    -- Platform
    platform        TEXT NOT NULL CHECK (platform IN ('n8n', 'make', 'zapier', 'custom')),
    workflow_json   JSONB, -- Full n8n export JSON for easy reimport
    external_id     TEXT, -- n8n workflow ID, Make scenario ID, etc.
    
    -- Classification
    category        TEXT NOT NULL
                    CHECK (category IN (
                        'content_publishing', 'email_marketing', 'lead_capture', 
                        'payment_processing', 'analytics', 'affiliate', 'community',
                        'monitoring', 'data_sync', 'onboarding', 'retention'
                    )),
    
    -- Triggers
    trigger_type    TEXT, -- 'webhook', 'cron', 'event', 'manual'
    cron_expression TEXT, -- For cron-triggered workflows
    
    -- Status
    is_active       BOOLEAN DEFAULT TRUE,
    last_run_at     TIMESTAMPTZ,
    last_run_status TEXT, -- 'success', 'failed', 'running'
    
    -- Monitoring
    alert_email     TEXT, -- Send alert if this workflow fails
    max_retries     INT DEFAULT 3,
    
    -- Version
    version         INT DEFAULT 1,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_automation_workflows_category ON automation_workflows(category);
CREATE INDEX idx_automation_workflows_active ON automation_workflows(is_active) WHERE is_active = TRUE;
```

### Table: `automation_execution_logs`
Execution records for every workflow run.

```sql
CREATE TABLE automation_execution_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    workflow_id     UUID NOT NULL REFERENCES automation_workflows(id) ON DELETE CASCADE,
    execution_id    TEXT, -- n8n execution ID
    
    -- Timing
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,
    duration_ms     INT GENERATED ALWAYS AS (
        CASE WHEN completed_at IS NOT NULL 
             THEN EXTRACT(EPOCH FROM (completed_at - started_at))::INT * 1000 
             ELSE NULL 
        END
    ) STORED,
    
    -- Result
    status          TEXT NOT NULL DEFAULT 'running'
                    CHECK (status IN ('running', 'success', 'failed', 'timeout', 'cancelled')),
    error_message   TEXT,
    error_stack     TEXT,
    
    -- Payload
    input_data      JSONB,
    output_data     JSONB,
    
    -- Trigger
    trigger_source  TEXT, -- 'webhook', 'cron', 'manual', 'sub-workflow'
    trigger_detail  JSONB DEFAULT '{}'::jsonb,
    
    -- Related entities (for linking to affected records)
    related_video_id    UUID,
    related_subscriber_id UUID,
    related_purchase_id UUID,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_automation_logs_workflow ON automation_execution_logs(workflow_id);
CREATE INDEX idx_automation_logs_status ON automation_execution_logs(status);
CREATE INDEX idx_automation_logs_started ON automation_execution_logs(started_at);
CREATE INDEX idx_automation_logs_failed ON automation_execution_logs(workflow_id, started_at DESC)
    WHERE status = 'failed';
```

### Table: `automation_membership_blueprints`
Curated n8n/Make blueprints for Premium members (from the Automation Vault).

```sql
CREATE TABLE automation_membership_blueprints (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name            TEXT NOT NULL,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,
    
    -- Platform
    platform        TEXT NOT NULL CHECK (platform IN ('n8n', 'make', 'zapier')),
    
    -- Category
    category        TEXT NOT NULL
                    CHECK (category IN (
                        'content_automation', 'email_automation', 'lead_generation',
                        'data_processing', 'social_media', 'productivity', 'ai_prompts',
                        'analytics', 'custom'
                    )),
    
    -- File
    blueprint_json  JSONB NOT NULL, -- Exportable workflow JSON
    preview_image_url TEXT,
    difficulty       TEXT CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
    
    -- Metadata
    estimated_setup_minutes INT,
    tools_required   TEXT[] DEFAULT '{}', -- ['openai', 'slack', 'notion', ...]
    is_featured     BOOLEAN DEFAULT FALSE,
    
    -- Usage
    download_count  INT DEFAULT 0,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_blueprints_category ON automation_membership_blueprints(category);
CREATE INDEX idx_blueprints_platform ON automation_membership_blueprints(platform);
```

---

## 11. Indexes

### Summary of Custom Indexes

| Table | Index Name | Columns | Purpose |
|-------|-----------|---------|---------|
| `profiles` | `idx_profiles_auth_id` | `auth_id` | Auth lookup |
| `profiles` | `idx_profiles_referral_code` | `referral_code` | Referral link lookups |
| `user_sessions` | `idx_user_sessions_profile_id` | `profile_id` | User session queries |
| `user_sessions` | `idx_user_sessions_started_at` | `started_at` | Time-series queries |
| `content_videos` | `idx_content_videos_status` | `status` | Filter by status |
| `content_videos` | `idx_content_videos_published_at` | `published_at` | Publishing schedule |
| `content_videos` | `idx_content_videos_hook_id` | `hook_id` | Hook performance lookup |
| `content_videos` | `idx_content_videos_platforms` | GIN(`platforms`) | Cross-platform search |
| `viral_hooks` | `idx_viral_hooks_category` | `category` | Filter by category |
| `viral_hooks` | `idx_viral_hooks_trigger_type` | `trigger_type` | Trigger analysis |
| `viral_hooks` | `idx_viral_hooks_performance` | `estimated_performance DESC` | Top hooks query |
| `viral_hooks` | `idx_viral_hooks_actual_performance` | `actual_performance DESC NULLS LAST` | Real performance ranking |
| `email_subscribers` | `idx_email_subscribers_status` | `status` | Active/inactive filtering |
| `email_subscribers` | `idx_email_subscribers_source` | `source` | Source attribution |
| `email_campaign_logs` | `idx_campaign_logs_campaign` | `campaign_id` | Campaign aggregates |
| `email_campaign_logs` | `idx_campaign_logs_subscriber` | `subscriber_id` | Per-subscriber history |
| `purchases` | `idx_purchases_affiliate_id` | `affiliate_id` | Affiliate sales lookup |
| `purchases` | `idx_purchases_utm` | `utm_source, utm_medium, utm_campaign` | Campaign attribution |
| `analytics_content_events` | `idx_content_events_video` | `video_id` | Per-video analytics |
| `analytics_content_events` | `idx_content_events_date` | `event_date` | Date-range queries |
| `analytics_funnel_events` | `idx_funnel_events_source_video` | `source_video_id` | Content-to-conversion |
| `affiliate_commissions` | `idx_affiliate_commissions_pending` | `status, created_at` WHERE pending | Payout queue |
| `automation_execution_logs` | `idx_automation_logs_failed` | `workflow_id, started_at DESC` WHERE failed | Error monitoring |

### Partial Indexes (PostgreSQL)

```sql
-- Only index active subscribers (much smaller index)
CREATE INDEX idx_subscribers_active ON email_subscribers(created_at) WHERE status = 'active';

-- Index only active affiliates for rapid code lookup
CREATE INDEX idx_affiliates_active_codes ON affiliates(referral_code) WHERE is_active = TRUE;

-- Index only recently published videos for trend queries
CREATE INDEX idx_videos_recent ON content_videos(published_at DESC) 
    WHERE status = 'published' AND published_at > NOW() - INTERVAL '30 days';

-- Index daily metrics for dashboard queries
CREATE INDEX idx_daily_metrics_recent ON analytics_daily_metrics(metric_date DESC) 
    WHERE metric_date > NOW() - INTERVAL '90 days';
```

---

## 12. Row Level Security Policies

### Supabase RLS Strategy

MindFrame uses Supabase Row Level Security with three access tiers:

| Role | Access | Used By |
|------|--------|---------|
| `admin` | Full CRUD on all tables | MindFrame team (internal) |
| `authenticated` | Read own data, write with limits | Logged-in users (customers/members) |
| `anon` | Read public content only | Website visitors, landing pages |

### Enable RLS on All Tables

```sql
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_scripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE viral_hooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_subscribers ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_page_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_content_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_funnel_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliates ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE automation_workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE automation_execution_logs ENABLE ROW LEVEL SECURITY;
```

### Admin Policies

```sql
-- Admin sees all rows
CREATE POLICY admin_all ON profiles
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY admin_all ON content_videos
    FOR ALL USING (auth.role() = 'service_role');

-- ... (apply same pattern to all tables)
```

### Content Policies (Anon + Authenticated)

```sql
-- Public: anyone can read published videos
CREATE POLICY anon_read_published ON content_videos
    FOR SELECT USING (status = 'published');

-- Public: anyone can read viral hooks
CREATE POLICY anon_read_hooks ON viral_hooks
    FOR SELECT USING (TRUE);

-- Public: anyone can read templates
CREATE POLICY anon_read_templates ON content_templates
    FOR SELECT USING (TRUE);
```

### User Data Policies

```sql
-- Users can only read their own profile
CREATE POLICY user_own_profile ON profiles
    FOR SELECT USING (auth.uid() = auth_id);

-- Users can read their own purchases
CREATE POLICY user_own_purchases ON purchases
    FOR SELECT USING (profile_id = auth.uid() AND 
        auth.uid() IS NOT NULL);

-- Users can read their own membership
CREATE POLICY user_own_membership ON memberships
    FOR SELECT USING (profile_id = auth.uid());

-- Users can read their own affiliate data
CREATE POLICY user_own_affiliate ON affiliates
    FOR SELECT USING (profile_id = auth.uid());
```

### Submission Policies

```sql
-- Authenticated users can create funnel events for themselves
CREATE POLICY user_insert_funnel ON analytics_funnel_events
    FOR INSERT WITH CHECK (
        profile_id = auth.uid() OR 
        (profile_id IS NULL AND auth.role() = 'anon')
    );
```

---

## 13. ER Diagram (Text)

```
┌─────────────────────┐       ┌──────────────────────┐
│      profiles       │       │   content_videos     │
├─────────────────────┤       ├──────────────────────┤
│ id (PK)             │──┐    │ id (PK)              │
│ auth_id (UQ,FK)     │  │    │ hook_id (FK) ────────┼──┐
│ email               │  │    │ template_id (FK) ────┼─┐│
│ stripe_customer_id  │  │    │ script_id (FK) ──────┼┐││
│ referred_by (FK) ───┼──┤    │ ...                  ││││
│ referral_code       │  │    │ platform_urls        ││││
│ is_member           │  │    └──────────────────────┘│││
│ created_at          │  │                            │││
└─────────────────────┘  │    ┌──────────────────────┐ │││
                         │    │  content_scripts     │ │││
┌─────────────────────┐  │    ├──────────────────────┤ │││
│   email_subscribers │  │    │ id (PK)              │◄┘││
├─────────────────────┤  │    │ hook_text            │  ││
│ id (PK)             │  │    │ body_text            │  ││
│ email               │  │    │ category             │  ││
│ profile_id (FK) ────┼──┤    │ version              │  ││
│ source_video_id(FK)─┼──┼────┼──────────────────────┘  ││
│ status              │  │                              ││
│ beehiiv_id          │  │    ┌──────────────────────┐   ││
│ created_at          │  │    │   content_templates  │   ││
└─────────────────────┘  │    ├──────────────────────┤   ││
                         │    │ id (PK)              │◄──┘│
┌─────────────────────┐  │    │ name                 │    │
│    email_tags       │  │    │ hook_format          │    │
├─────────────────────┤  │    │ category             │    │
│ id (PK)             │  │    └──────────────────────┘    │
│ name                │  │                               │
└─────────┬───────────┘  │    ┌──────────────────────┐    │
          │              │    │     viral_hooks      │    │
┌─────────┴───────────┐  │    ├──────────────────────┤    │
│ email_subscriber_tags│  │    │ id (PK)              │◄───┘
├──────────────────────┤  │    │ hook_text            │
│ subscriber_id (FK) ──┼──┤    │ category             │
│ tag_id (FK)          │  │    │ trigger_type         │
└──────────────────────┘  │    │ estimated_performance│
                          │    │ actual_performance   │
┌──────────────────────┐  │    └──────────────────────┘
│   email_campaigns    │  │
├──────────────────────┤  │    ┌──────────────────────┐
│ id (PK)              │  │    │   user_sessions      │
│ sequence_name        │  │    ├──────────────────────┤
│ step_number          │  │    │ id (PK)              │
│ subject              │  │    │ profile_id (FK) ─────┼──┐
│ status               │  │    │ session_token        │  │
│ total_sent           │  │    │ ip_address           │  │
│ open_rate            │  │    │ started_at           │  │
└──────────┬───────────┘  │    └──────────────────────┘  │
           │              │                              │
┌──────────┴───────────┐  │    ┌──────────────────────┐  │
│ email_campaign_logs  │  │    │ digital_products     │  │
├──────────────────────┤  │    ├──────────────────────┤  │
│ id (PK)              │  │    │ id (PK)              │  │
│ campaign_id (FK) ────┼──┤    │ name                 │  │
│ subscriber_id (FK)───┼──┼─┐  │ product_type         │  │
│ status               │  │ │  │ price_cents          │  │
│ opened_at            │  │ │  │ gumroad_product_id   │  │
│ clicked_links        │  │ │  │ affiliate_comm_pct   │  │
└──────────────────────┘  │ │  └──────────┬───────────┘  │
                          │ │             │              │
┌──────────────────────┐  │ │  ┌──────────┴───────────┐  │
│      purchases       │  │ │  │     purchase_items   │  │
├──────────────────────┤  │ │  ├──────────────────────┤  │
│ id (PK)              │  │ │  │ id (PK)              │  │
│ product_id (FK) ─────┼──┼─┼──┤ purchase_id (FK)     │  │
│ profile_id (FK) ─────┼──┼─┼──┤ product_id (FK)      │  │
│ subscriber_id (FK)───┼──┤ │  │ quantity             │  │
│ affiliate_id (FK) ───┼──┼─┤  │ unit_price_cents     │  │
│ amount_cents         │  │ │  └──────────────────────┘  │
│ status               │  │ │                            │
│ source_video_id (FK)─┼──┼─┘                            │
│ utm_source           │  │                              │
│ created_at           │  │                              │
└──────────────────────┘  │    ┌──────────────────────┐  │
                          │    │   membership_plans   │  │
┌──────────────────────┐  │    ├──────────────────────┤  │
│     memberships      │  │    │ id (PK)              │  │
├──────────────────────┤  │    │ name                 │  │
│ id (PK)              │  │    │ price_cents          │  │
│ profile_id (FK) ─────┼──┤    │ interval             │  │
│ plan_id (FK) ────────┼──┼────│ stripe_price_id      │  │
│ stripe_subscription  │  │    │ features             │  │
│ status               │  │    └──────────────────────┘  │
│ current_period_end   │  │                              │
│ cancel_at_period_end │  │    ┌──────────────────────┐  │
└──────────────────────┘  │    │ membership_events   │  │
                          │    ├──────────────────────┤  │
┌──────────────────────┐  │    │ id (PK)              │  │
│  analytics_page_views│  │    │ membership_id (FK)───┼──┤
├──────────────────────┤  │    │ event_type          │  │
│ id (PK)              │  │    │ previous_plan_id     │  │
│ profile_id (FK) ─────┼──┤    │ new_plan_id          │  │
│ session_id (FK) ─────┼──┤    └──────────────────────┘  │
│ url                  │  │                              │
│ utm_source           │  │    ┌──────────────────────┐  │
│ viewed_at            │  │    │ analytics_funnel_ev  │  │
└──────────────────────┘  │    ├──────────────────────┤  │
                          │    │ id (PK)              │  │
┌──────────────────────┐  │    │ profile_id (FK) ─────┼──┤
│ analytics_content_ev │  │    │ session_id (FK) ─────┼──┤
├──────────────────────┤  │    │ stage                │  │
│ id (PK)              │  │    │ source_video_id(FK) ─┼──┤
│ video_id (FK) ───────┼──┤    │ revenue_cents        │  │
│ platform             │  │    │ time_to_convert      │  │
│ event_date           │  │    └──────────────────────┘  │
│ views, likes, shares │  │                              │
│ reach, impressions   │  │    ┌──────────────────────┐  │
│ from_fyp             │  │    │    affiliates        │  │
└──────────────────────┘  │    ├──────────────────────┤  │
                          │    │ id (PK)              │  │
┌──────────────────────┐  │    │ profile_id (FK) ─────┼──┤
│ automation_workflows │  │    │ referral_code        │  │
├──────────────────────┤  │    │ commission_pct       │  │
│ id (PK)              │  │    │ total_earned_cents   │  │
│ name                 │  │    └──────────┬───────────┘  │
│ platform             │  │               │             │
│ workflow_json        │  │    ┌──────────┴───────────┐  │
│ category             │  │    │  affiliate_referrals │  │
│ is_active            │  │    ├──────────────────────┤  │
└──────────┬───────────┘  │    │ id (PK)              │  │
           │              │    │ affiliate_id (FK) ───┼──┤
┌──────────┴───────────┐  │    │ referred_email       │  │
│ automation_exec_logs │  │    │ converted            │  │
├──────────────────────┤  │    │ purchase_id (FK) ────┼──┤
│ id (PK)              │  │    └──────────────────────┘  │
│ workflow_id (FK) ────┼──┤                              │
│ status               │  │    ┌──────────────────────┐  │
│ input_data           │  │    │ affiliate_commissions│  │
│ output_data          │  │    ├──────────────────────┤  │
│ error_message        │  │    │ id (PK)              │  │
│ started_at           │  │    │ affiliate_id (FK) ───┼──┤
└──────────────────────┘  │    │ referral_id (FK)     │  │
                          │    │ amount_cents         │  │
┌──────────────────────┐  │    │ status               │  │
│ analytics_daily_met  │  │    │ source_purchase_id   │  │
├──────────────────────┤  │    └──────────────────────┘  │
│ metric_date (PK)     │  │                              │
│ videos_published     │  │    ┌──────────────────────┐  │
│ total_content_views  │  │    │ automation_blueprints│  │
│ new_subscribers      │  │    ├──────────────────────┤  │
│ total_revenue_cents  │  │    │ id (PK)              │  │
│ active_members       │  │    │ name                 │  │
│ churn_rate           │  │    │ blueprint_json       │  │
│ workflows_run        │  │    │ category             │  │
│ automation_uptime_pct│  │    │ difficulty           │  │
└──────────────────────┘  │    └──────────────────────┘
```

---

## 14. Deployment Notes

### Supabase Setup Steps

1. **Create Supabase project** (free tier: 500MB database, 50K users)
2. **Enable required extensions:**
   ```sql
   CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
   CREATE EXTENSION IF NOT EXISTS "pgcrypto";
   CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
   ```

3. **Apply schema in order:**
   ```bash
   # Run from Supabase SQL editor or via CLI
   supabase/migrations/001_core_tables.sql
   supabase/migrations/002_content_tables.sql
   supabase/migrations/003_email_tables.sql
   supabase/migrations/004_commerce_tables.sql
   supabase/migrations/005_analytics_tables.sql
   supabase/migrations/006_affiliate_tables.sql
   supabase/migrations/007_automation_tables.sql
   supabase/migrations/008_indexes.sql
   supabase/migrations/009_rls_policies.sql
   ```

4. **Seed data:** Import `HOOKS_DATABASE.json` into `viral_hooks`

5. **Verify RLS:** Test each table with anon, authenticated, and service_role

### Cost Estimate (Supabase Free Tier)

| Resource | Free Tier Limit | MindFrame Est. |
|----------|----------------|----------------|
| Database | 500 MB | ~50 MB at launch |
| Auth users | 50,000 | ~5,000 first 90 days |
| Bandwidth | 2 GB | ~500 MB/month |
| Edge Functions | 500K invocations | ~100K/month |

### Migration Strategy

```sql
-- Example migration wrapper
BEGIN;
    -- Add new column
    ALTER TABLE content_videos 
        ADD COLUMN IF NOT EXISTS ai_generation_cost_cents INT DEFAULT 0;
    
    -- Backfill new column
    UPDATE content_videos 
        SET ai_generation_cost_cents = 0 
        WHERE ai_generation_cost_cents IS NULL;
    
    -- Add index
    CREATE INDEX IF NOT EXISTS idx_content_videos_ai_cost 
        ON content_videos(ai_generation_cost_cents);
COMMIT;
```

### Monitoring Queries

```sql
-- Daily revenue snapshot
SELECT metric_date, 
       total_revenue_cents / 100.0 AS total_revenue_dollars,
       tripwire_sales,
       membership_new_sales
FROM analytics_daily_metrics
WHERE metric_date >= NOW() - INTERVAL '30 days'
ORDER BY metric_date DESC;

-- Funnel conversion rates
SELECT 
    COUNT(*) FILTER (WHERE stage = 'content_view') AS content_views,
    COUNT(*) FILTER (WHERE stage = 'profile_visit') AS profile_visits,
    COUNT(*) FILTER (WHERE stage = 'lead_magnet_download') AS downloads,
    COUNT(*) FILTER (WHERE stage = 'tripwire_purchase') AS tripwire_sales,
    COUNT(*) FILTER (WHERE stage = 'membership_purchased') AS membership_sales
FROM analytics_funnel_events
WHERE created_at >= NOW() - INTERVAL '7 days';

-- Top performing hooks (live)
SELECT 
    hook_text,
    category,
    estimated_performance,
    actual_performance,
    times_used
FROM viral_hooks
WHERE actual_performance IS NOT NULL
ORDER BY actual_performance DESC
LIMIT 20;

-- Automation health check
SELECT 
    w.name,
    COUNT(*) FILTER (WHERE l.status = 'failed') AS failures,
    COUNT(*) FILTER (WHERE l.status = 'success') AS successes,
    ROUND(
        COUNT(*) FILTER (WHERE l.status = 'success')::DECIMAL / 
        NULLIF(COUNT(*), 0) * 100, 2
    ) AS success_rate
FROM automation_workflows w
LEFT JOIN automation_execution_logs l ON l.workflow_id = w.id
WHERE l.started_at >= NOW() - INTERVAL '24 hours'
GROUP BY w.id, w.name
ORDER BY success_rate ASC;
```

---

*End of Database Architecture Document. Ready for implementation.*
