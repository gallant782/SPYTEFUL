-- ============================================================
-- MindFrame Database Schema — Migration 001: Core Tables
-- ============================================================
-- Run order: 001_core.sql first
-- Requires: uuid-ossp extension (CREATE EXTENSION IF NOT EXISTS "uuid-ossp";)

BEGIN;

-- Utility: updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- Profiles (extends Supabase Auth)
-- ============================
CREATE TABLE profiles (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_id     UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    email       TEXT UNIQUE NOT NULL,
    full_name   TEXT,
    avatar_url  TEXT,

    email_opt_in    BOOLEAN DEFAULT TRUE,
    marketing_consent_granted_at TIMESTAMPTZ,
    marketing_consent_ip         INET,

    is_member           BOOLEAN DEFAULT FALSE,
    member_since        TIMESTAMPTZ,
    stripe_customer_id  TEXT UNIQUE,

    referred_by     UUID REFERENCES profiles(id) ON DELETE SET NULL,
    referral_code   TEXT UNIQUE,

    metadata        JSONB DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_profiles_auth_id ON profiles(auth_id);
CREATE INDEX idx_profiles_referral_code ON profiles(referral_code);

-- ============================
-- User Sessions
-- ============================
CREATE TABLE user_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    session_token   TEXT NOT NULL,

    user_agent      TEXT,
    ip_address      INET,
    referrer_url    TEXT,
    landing_page    TEXT,

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

-- ============================
-- Email Tags (used across email, content, and membership)
-- ============================
CREATE TABLE email_tags (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL UNIQUE,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,
    color           TEXT DEFAULT '#6366f1',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================
-- Membership Plans
-- ============================
CREATE TABLE membership_plans (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name            TEXT NOT NULL,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,

    price_cents     INT NOT NULL CHECK (price_cents > 0),
    currency        TEXT NOT NULL DEFAULT 'usd',
    interval        TEXT NOT NULL CHECK (interval IN ('month', 'year')),

    stripe_price_id     TEXT,
    stripe_product_id   TEXT,

    features        JSONB DEFAULT '[]'::jsonb,
    is_active       BOOLEAN DEFAULT TRUE,
    sort_order      INT DEFAULT 0,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_membership_plans_updated_at
    BEFORE UPDATE ON membership_plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================
-- Digital Products
-- ============================
CREATE TABLE digital_products (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name            TEXT NOT NULL,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,

    price_cents     INT NOT NULL CHECK (price_cents >= 0),
    currency        TEXT NOT NULL DEFAULT 'usd',
    compare_at_price_cents INT,

    product_type    TEXT NOT NULL
                    CHECK (product_type IN ('lead_magnet', 'tripwire', 'membership', 'automation_package', 'bundle')),

    file_urls       JSONB DEFAULT '[]'::jsonb,
    gumroad_product_id  TEXT,
    stripe_price_id     TEXT,

    affiliate_commission_pct DECIMAL(5,2) DEFAULT 0.00,

    inventory_count     INT,
    inventory_remaining INT,

    is_active       BOOLEAN DEFAULT TRUE,
    is_featured     BOOLEAN DEFAULT FALSE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_digital_products_updated_at
    BEFORE UPDATE ON digital_products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_digital_products_type ON digital_products(product_type);
CREATE INDEX idx_digital_products_active ON digital_products(is_active) WHERE is_active = TRUE;

COMMIT;

-- ============================================================
-- 002_content.sql
-- ============================================================
-- ============================================================
-- MindFrame Database Schema — Migration 002: Content Tables
-- ============================================================

BEGIN;

-- ============================
-- Content Templates (10 script templates)
-- ============================
CREATE TABLE content_templates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name            TEXT NOT NULL UNIQUE,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,

    hook_format         TEXT NOT NULL,
    point_1_framework   TEXT NOT NULL,
    point_2_framework   TEXT NOT NULL,
    point_3_framework   TEXT NOT NULL,
    cta_framework       TEXT NOT NULL,

    category        TEXT NOT NULL,
    primary_trigger TEXT,

    avg_performance     DECIMAL(3,1) DEFAULT 0.0,
    times_used          INT DEFAULT 0,
    is_active           BOOLEAN DEFAULT TRUE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_content_templates_updated_at
    BEFORE UPDATE ON content_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================
-- Viral Hooks Database
-- ============================
CREATE TABLE viral_hooks (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    hook_text           TEXT NOT NULL,
    category            TEXT NOT NULL,
    trigger_type        TEXT NOT NULL,

    estimated_performance   DECIMAL(3,1) NOT NULL CHECK (estimated_performance >= 0 AND estimated_performance <= 10),
    actual_performance      DECIMAL(3,1),
    performance_delta       DECIMAL(4,2) GENERATED ALWAYS AS (
        CASE WHEN actual_performance IS NOT NULL 
             THEN actual_performance - estimated_performance 
             ELSE NULL 
        END
    ) STORED,

    times_used          INT DEFAULT 0,
    last_used_at        TIMESTAMPTZ,

    variant_group       TEXT,
    winning_variant_id  UUID REFERENCES viral_hooks(id) ON DELETE SET NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE viral_hooks ADD CONSTRAINT uq_viral_hooks_text UNIQUE (hook_text);

CREATE TRIGGER trg_viral_hooks_updated_at
    BEFORE UPDATE ON viral_hooks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_viral_hooks_category ON viral_hooks(category);
CREATE INDEX idx_viral_hooks_trigger_type ON viral_hooks(trigger_type);
CREATE INDEX idx_viral_hooks_performance ON viral_hooks(estimated_performance DESC);
CREATE INDEX idx_viral_hooks_actual_performance ON viral_hooks(actual_performance DESC NULLS LAST);

-- ============================
-- Content Scripts
-- ============================
CREATE TABLE content_scripts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    title           TEXT NOT NULL,
    hook_text       TEXT NOT NULL,
    body_text       TEXT NOT NULL,
    cta_text        TEXT,

    ai_prompt       TEXT,
    ai_temperature  DECIMAL(3,2) DEFAULT 0.7,
    ai_model        TEXT DEFAULT 'gpt-4',
    tokens_used     INT,

    version         INT NOT NULL DEFAULT 1,
    previous_version_id UUID REFERENCES content_scripts(id) ON DELETE SET NULL,

    tags            TEXT[] DEFAULT '{}',
    category        TEXT,
    estimated_performance DECIMAL(3,1),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_content_scripts_updated_at
    BEFORE UPDATE ON content_scripts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_content_scripts_category ON content_scripts(category);
CREATE INDEX idx_content_scripts_tags ON content_scripts USING GIN(tags);

-- ============================
-- Content Videos
-- ============================
CREATE TABLE content_videos (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    title           TEXT NOT NULL,
    slug            TEXT UNIQUE NOT NULL,
    hook_id         UUID REFERENCES viral_hooks(id) ON DELETE SET NULL,
    template_id     UUID REFERENCES content_templates(id) ON DELETE SET NULL,

    script_id       UUID REFERENCES content_scripts(id) ON DELETE SET NULL,
    script_text     TEXT NOT NULL,
    word_count      INT,

    platforms       TEXT[] NOT NULL DEFAULT '{}',
    published_at    TIMESTAMPTZ,
    scheduled_for   TIMESTAMPTZ,

    video_url       TEXT,
    thumbnail_url   TEXT,
    s3_storage_path TEXT,
    duration_seconds INT,

    ai_model        TEXT DEFAULT 'elevenlabs',
    ai_voice_id     TEXT,

    status          TEXT NOT NULL DEFAULT 'draft' 
                    CHECK (status IN ('draft', 'rendering', 'scheduled', 'published', 'failed', 'archived')),

    total_views         BIGINT DEFAULT 0,
    total_likes         BIGINT DEFAULT 0,
    total_shares        BIGINT DEFAULT 0,
    total_comments      BIGINT DEFAULT 0,
    total_saves         BIGINT DEFAULT 0,
    avg_watch_seconds   DECIMAL(5,2),

    cta_type        TEXT,
    cta_url         TEXT,
    cta_clicks      BIGINT DEFAULT 0,

    seo_tags        TEXT[],
    seo_description TEXT,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_content_videos_updated_at
    BEFORE UPDATE ON content_videos
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_content_videos_status ON content_videos(status);
CREATE INDEX idx_content_videos_published_at ON content_videos(published_at);
CREATE INDEX idx_content_videos_hook_id ON content_videos(hook_id);
CREATE INDEX idx_content_videos_platforms ON content_videos USING GIN(platforms);

-- Partial index for recent published videos
CREATE INDEX idx_videos_recent ON content_videos(published_at DESC) 
    WHERE status = 'published' AND published_at > NOW() - INTERVAL '30 days';

-- ============================
-- Content Publishing Queue
-- ============================
CREATE TABLE content_publishing_queue (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id        UUID NOT NULL REFERENCES content_videos(id) ON DELETE CASCADE,

    platform        TEXT NOT NULL CHECK (platform IN ('tiktok', 'instagram', 'youtube')),
    scheduled_for   TIMESTAMPTZ NOT NULL,
    published_at    TIMESTAMPTZ,

    status          TEXT NOT NULL DEFAULT 'queued'
                    CHECK (status IN ('queued', 'processing', 'published', 'failed', 'skipped')),

    platform_post_id    TEXT,
    platform_url        TEXT,

    error_message   TEXT,
    retry_count     INT DEFAULT 0,
    max_retries     INT DEFAULT 3,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_publishing_queue_updated_at
    BEFORE UPDATE ON content_publishing_queue
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_publishing_queue_status ON content_publishing_queue(status);
CREATE INDEX idx_publishing_queue_scheduled ON content_publishing_queue(scheduled_for)
    WHERE status = 'queued';

COMMIT;
-- ============================================================
-- 003_email.sql
-- ============================================================
-- ============================================================
-- MindFrame Database Schema — Migration 003: Email Tables
-- ============================================================

BEGIN;

-- ============================
-- Email Subscribers
-- ============================
CREATE TABLE email_subscribers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    email           TEXT UNIQUE NOT NULL,
    profile_id      UUID REFERENCES profiles(id) ON DELETE SET NULL,

    source          TEXT NOT NULL
                    CHECK (source IN ('lead_magnet', 'purchase', 'tripwire', 'landing_page', 'manual', 'referral')),
    source_url      TEXT,
    source_video_id UUID REFERENCES content_videos(id) ON DELETE SET NULL,

    status          TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'unsubscribed', 'bounced', 'spam')),
    unsubscribed_at TIMESTAMPTZ,
    bounce_reason   TEXT,

    last_opened_at      TIMESTAMPTZ,
    last_clicked_at     TIMESTAMPTZ,
    total_opens         INT DEFAULT 0,
    total_clicks        INT DEFAULT 0,
    total_emails_sent   INT DEFAULT 0,

    has_purchased       BOOLEAN DEFAULT FALSE,
    lifetime_value      DECIMAL(10,2) DEFAULT 0.00,

    beehiiv_subscriber_id  TEXT,
    convertkit_subscriber_id TEXT,

    double_opt_in_confirmed BOOLEAN DEFAULT FALSE,
    consent_ip              INET,
    consent_timestamp       TIMESTAMPTZ,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_email_subscribers_updated_at
    BEFORE UPDATE ON email_subscribers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_email_subscribers_status ON email_subscribers(status);
CREATE INDEX idx_email_subscribers_source ON email_subscribers(source);
CREATE INDEX idx_email_subscribers_profile_id ON email_subscribers(profile_id);
CREATE INDEX idx_email_subscribers_created_at ON email_subscribers(created_at);
CREATE INDEX idx_subscribers_active ON email_subscribers(created_at) WHERE status = 'active';

-- ============================
-- Email Subscriber Tags (junction)
-- ============================
CREATE TABLE email_subscriber_tags (
    subscriber_id   UUID NOT NULL REFERENCES email_subscribers(id) ON DELETE CASCADE,
    tag_id          UUID NOT NULL REFERENCES email_tags(id) ON DELETE CASCADE,
    applied_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (subscriber_id, tag_id)
);

CREATE INDEX idx_subscriber_tags_tag_id ON email_subscriber_tags(tag_id);

-- ============================
-- Email Campaigns
-- ============================
CREATE TABLE email_campaigns (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name            TEXT NOT NULL,
    sequence_name   TEXT NOT NULL,
    step_number     INT NOT NULL,
    subject         TEXT NOT NULL,
    preview_text    TEXT,

    body_html       TEXT,
    body_text       TEXT,

    target_tags     UUID[] DEFAULT '{}',
    exclude_tags    UUID[] DEFAULT '{}',

    delay_hours     INT DEFAULT 0,
    send_at         TIMESTAMPTZ,
    status          TEXT NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft', 'active', 'sending', 'completed', 'paused', 'archived')),

    total_sent      INT DEFAULT 0,
    total_opens     INT DEFAULT 0,
    total_clicks    INT DEFAULT 0,
    total_unsubs    INT DEFAULT 0,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_email_campaigns_updated_at
    BEFORE UPDATE ON email_campaigns
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_email_campaigns_sequence ON email_campaigns(sequence_name, step_number);
CREATE INDEX idx_email_campaigns_status ON email_campaigns(status);

-- ============================
-- Email Campaign Logs (individual send events)
-- ============================
CREATE TABLE email_campaign_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id     UUID NOT NULL REFERENCES email_campaigns(id) ON DELETE CASCADE,
    subscriber_id   UUID NOT NULL REFERENCES email_subscribers(id) ON DELETE CASCADE,

    sent_at         TIMESTAMPTZ,
    delivered_at    TIMESTAMPTZ,
    opened_at       TIMESTAMPTZ,
    clicked_at      TIMESTAMPTZ,
    unsubscribed_at TIMESTAMPTZ,

    open_count      INT DEFAULT 0,
    click_count     INT DEFAULT 0,
    last_open_at    TIMESTAMPTZ,
    last_click_at   TIMESTAMPTZ,

    clicked_links   JSONB DEFAULT '[]'::jsonb,

    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'sent', 'delivered', 'opened', 'clicked', 'bounced', 'failed', 'unsubscribed')),
    error_message   TEXT,

    message_id      TEXT,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_campaign_logs_campaign ON email_campaign_logs(campaign_id);
CREATE INDEX idx_campaign_logs_subscriber ON email_campaign_logs(subscriber_id);
CREATE INDEX idx_campaign_logs_status ON email_campaign_logs(status);
CREATE INDEX idx_campaign_logs_sent_at ON email_campaign_logs(sent_at);

COMMIT;
-- ============================================================
-- 004_commerce.sql
-- ============================================================
-- ============================================================
-- MindFrame Database Schema — Migration 004: Commerce Tables
-- ============================================================

BEGIN;

-- ============================
-- Purchases
-- ============================
CREATE TABLE purchases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    product_id      UUID NOT NULL REFERENCES digital_products(id) ON DELETE RESTRICT,
    profile_id      UUID REFERENCES profiles(id) ON DELETE SET NULL,
    subscriber_id   UUID REFERENCES email_subscribers(id) ON DELETE SET NULL,

    customer_email      TEXT NOT NULL,
    customer_name       TEXT,

    amount_cents        INT NOT NULL,
    currency            TEXT NOT NULL DEFAULT 'usd',
    fee_cents           INT DEFAULT 0,
    net_revenue_cents   INT GENERATED ALWAYS AS (amount_cents - fee_cents) STORED,

    processor           TEXT NOT NULL DEFAULT 'stripe'
                        CHECK (processor IN ('stripe', 'gumroad', 'paypal')),
    processor_charge_id TEXT,
    processor_payment_intent TEXT,

    status              TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'completed', 'refunded', 'partially_refunded', 'failed', 'disputed')),
    refunded_at         TIMESTAMPTZ,
    refund_amount_cents INT,

    affiliate_id     UUID REFERENCES affiliates(id) ON DELETE SET NULL,
    affiliate_commission_cents INT DEFAULT 0,

    source_video_id  UUID REFERENCES content_videos(id) ON DELETE SET NULL,
    source_url       TEXT,
    utm_source       TEXT,
    utm_medium       TEXT,
    utm_campaign     TEXT,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_purchases_updated_at
    BEFORE UPDATE ON purchases
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_purchases_product_id ON purchases(product_id);
CREATE INDEX idx_purchases_profile_id ON purchases(profile_id);
CREATE INDEX idx_purchases_status ON purchases(status);
CREATE INDEX idx_purchases_created_at ON purchases(created_at);
CREATE INDEX idx_purchases_affiliate_id ON purchases(affiliate_id);
CREATE INDEX idx_purchases_utm ON purchases(utm_source, utm_medium, utm_campaign);

-- ============================
-- Purchase Items (for bundles)
-- ============================
CREATE TABLE purchase_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_id     UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES digital_products(id) ON DELETE RESTRICT,

    quantity        INT NOT NULL DEFAULT 1,
    unit_price_cents INT NOT NULL,
    total_cents     INT GENERATED ALWAYS AS (quantity * unit_price_cents) STORED,

    download_url    TEXT,
    download_count  INT DEFAULT 0,
    access_granted  BOOLEAN DEFAULT FALSE,
    access_granted_at TIMESTAMPTZ,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_purchase_items_purchase_id ON purchase_items(purchase_id);

-- ============================
-- Memberships
-- ============================
CREATE TABLE memberships (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    profile_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    plan_id         UUID NOT NULL REFERENCES membership_plans(id) ON DELETE RESTRICT,

    stripe_subscription_id  TEXT UNIQUE,
    stripe_customer_id      TEXT,

    status          TEXT NOT NULL DEFAULT 'trialing'
                    CHECK (status IN ('trialing', 'active', 'past_due', 'canceled', 'incomplete', 'incomplete_expired')),

    current_period_start    TIMESTAMPTZ NOT NULL,
    current_period_end      TIMESTAMPTZ NOT NULL,
    trial_start             TIMESTAMPTZ,
    trial_end               TIMESTAMPTZ,
    canceled_at             TIMESTAMPTZ,
    ended_at                TIMESTAMPTZ,

    cancel_at_period_end    BOOLEAN DEFAULT FALSE,
    cancellation_reason     TEXT,
    cancellation_reason_detail TEXT,

    price_cents_at_subscription INT NOT NULL,

    referral_count          INT DEFAULT 0,
    lifetime_value_cents    INT DEFAULT 0,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_memberships_updated_at
    BEFORE UPDATE ON memberships
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_memberships_profile_id ON memberships(profile_id);
CREATE INDEX idx_memberships_status ON memberships(status);
CREATE INDEX idx_memberships_current_period ON memberships(current_period_end)
    WHERE status IN ('active', 'trialing');

-- ============================
-- Membership Events (lifecycle tracking)
-- ============================
CREATE TABLE membership_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    membership_id   UUID NOT NULL REFERENCES memberships(id) ON DELETE CASCADE,
    profile_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    event_type      TEXT NOT NULL
                    CHECK (event_type IN ('created', 'renewed', 'upgraded', 'downgraded',
                                          'canceled', 'reactivated', 'expired', 'payment_failed')),

    previous_plan_id    UUID REFERENCES membership_plans(id),
    new_plan_id         UUID REFERENCES membership_plans(id),
    previous_price      INT,
    new_price           INT,

    metadata        JSONB DEFAULT '{}'::jsonb,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_membership_events_membership ON membership_events(membership_id);
CREATE INDEX idx_membership_events_type ON membership_events(event_type);
CREATE INDEX idx_membership_events_created ON membership_events(created_at);

-- ============================
-- Automation Blueprints (Premium member vault)
-- ============================
CREATE TABLE automation_membership_blueprints (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name            TEXT NOT NULL,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,

    platform        TEXT NOT NULL CHECK (platform IN ('n8n', 'make', 'zapier')),
    category        TEXT NOT NULL
                    CHECK (category IN ('content_automation', 'email_automation', 'lead_generation',
                                        'data_processing', 'social_media', 'productivity',
                                        'ai_prompts', 'analytics', 'custom')),

    blueprint_json  JSONB NOT NULL,
    preview_image_url TEXT,
    difficulty       TEXT CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),

    estimated_setup_minutes INT,
    tools_required   TEXT[] DEFAULT '{}',
    is_featured     BOOLEAN DEFAULT FALSE,

    download_count  INT DEFAULT 0,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_blueprints_updated_at
    BEFORE UPDATE ON automation_membership_blueprints
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_blueprints_category ON automation_membership_blueprints(category);
CREATE INDEX idx_blueprints_platform ON automation_membership_blueprints(platform);

COMMIT;
-- ============================================================
-- 005_analytics.sql
-- ============================================================
-- ============================================================
-- MindFrame Database Schema — Migration 005: Analytics Tables
-- ============================================================

BEGIN;

-- ============================
-- Analytics: Page Views
-- ============================
CREATE TABLE analytics_page_views (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    profile_id      UUID REFERENCES profiles(id) ON DELETE SET NULL,
    session_id      UUID REFERENCES user_sessions(id) ON DELETE SET NULL,

    url             TEXT NOT NULL,
    path            TEXT NOT NULL,
    referrer_url    TEXT,

    utm_source      TEXT,
    utm_medium      TEXT,
    utm_campaign    TEXT,
    utm_content     TEXT,
    utm_term        TEXT,

    user_agent      TEXT,
    device_type     TEXT,
    browser         TEXT,
    os              TEXT,
    ip_address      INET,
    country         TEXT,

    page_load_ms    INT,
    time_on_page_seconds INT,

    viewed_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_page_views_path ON analytics_page_views(path);
CREATE INDEX idx_page_views_viewed_at ON analytics_page_views(viewed_at);
CREATE INDEX idx_page_views_utm ON analytics_page_views(utm_source, utm_medium, utm_campaign);
CREATE INDEX idx_page_views_profile ON analytics_page_views(profile_id);

-- ============================
-- Analytics: Content Events (daily per-platform snapshots)
-- ============================
CREATE TABLE analytics_content_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    video_id        UUID NOT NULL REFERENCES content_videos(id) ON DELETE CASCADE,
    platform        TEXT NOT NULL CHECK (platform IN ('tiktok', 'instagram', 'youtube')),

    event_date      DATE NOT NULL,

    views           INT DEFAULT 0,
    likes           INT DEFAULT 0,
    shares          INT DEFAULT 0,
    comments        INT DEFAULT 0,
    saves           INT DEFAULT 0,
    avg_watch_seconds   DECIMAL(5,2),
    completion_rate     DECIMAL(5,4),
    follower_gain       INT DEFAULT 0,

    reach           INT,
    impressions     INT,
    from_fyp         INT,
    from_profile    INT,
    from_search     INT,
    from_hashtags   INT,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(video_id, platform, event_date)
);

CREATE INDEX idx_content_events_video ON analytics_content_events(video_id);
CREATE INDEX idx_content_events_date ON analytics_content_events(event_date);
CREATE INDEX idx_content_events_platform ON analytics_content_events(platform, event_date);

-- ============================
-- Analytics: Funnel Events
-- ============================
CREATE TABLE analytics_funnel_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    profile_id      UUID REFERENCES profiles(id) ON DELETE SET NULL,
    anonymous_id    TEXT,
    session_id      UUID REFERENCES user_sessions(id) ON DELETE SET NULL,

    stage           TEXT NOT NULL
                    CHECK (stage IN (
                        'content_view', 'profile_visit', 'landing_page_view',
                        'lead_magnet_download', 'tripwire_view', 'tripwire_purchase',
                        'membership_view', 'membership_started', 'membership_purchased',
                        'automation_package_view', 'automation_package_purchase',
                        'affiliate_signup', 'referral_click'
                    )),

    source_video_id UUID REFERENCES content_videos(id) ON DELETE SET NULL,
    source_url      TEXT,
    referrer_url    TEXT,
    utm_source      TEXT,
    utm_medium      TEXT,
    utm_campaign    TEXT,

    revenue_cents   INT DEFAULT 0,
    time_to_convert_seconds INT,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_funnel_events_stage ON analytics_funnel_events(stage, created_at);
CREATE INDEX idx_funnel_events_profile ON analytics_funnel_events(profile_id);
CREATE INDEX idx_funnel_events_source_video ON analytics_funnel_events(source_video_id);
CREATE INDEX idx_funnel_events_created ON analytics_funnel_events(created_at);

-- ============================
-- Analytics: Daily Metrics Rollup
-- ============================
CREATE TABLE analytics_daily_metrics (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_date     DATE NOT NULL UNIQUE,

    -- Content metrics
    videos_published    INT DEFAULT 0,
    total_content_views BIGINT DEFAULT 0,
    total_engagement    BIGINT DEFAULT 0,

    -- Growth
    new_followers       INT DEFAULT 0,
    total_followers     BIGINT DEFAULT 0,

    -- Funnel
    profile_visits      INT DEFAULT 0,
    landing_page_views  INT DEFAULT 0,
    new_subscribers     INT DEFAULT 0,
    total_subscribers   INT DEFAULT 0,

    -- Revenue breakdown (stored in cents)
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

    -- Automation health
    workflows_run       INT DEFAULT 0,
    workflows_failed    INT DEFAULT 0,
    automation_uptime_pct DECIMAL(5,2),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Partial index for dashboard (last 90 days)
CREATE INDEX idx_daily_metrics_recent ON analytics_daily_metrics(metric_date DESC)
    WHERE metric_date > NOW() - INTERVAL '90 days';

COMMIT;
-- ============================================================
-- 006_affiliates.sql
-- ============================================================
-- ============================================================
-- MindFrame Database Schema — Migration 006: Affiliate Tables
-- ============================================================

BEGIN;

-- ============================
-- Affiliates
-- ============================
CREATE TABLE affiliates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    profile_id      UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    email           TEXT NOT NULL,
    full_name       TEXT NOT NULL,
    paypal_email    TEXT,
    wise_email      TEXT,

    referral_code       TEXT UNIQUE NOT NULL,
    referral_link       TEXT NOT NULL,
    cookie_days         INT DEFAULT 60,

    commission_pct      DECIMAL(5,2) NOT NULL DEFAULT 30.00,
    lifetime_value_share BOOLEAN DEFAULT FALSE,

    tier            TEXT NOT NULL DEFAULT 'standard'
                    CHECK (tier IN ('standard', 'premium', 'elite')),
    total_earned_cents  INT DEFAULT 0,
    total_paid_cents    INT DEFAULT 0,
    pending_cents       INT DEFAULT 0,

    is_active       BOOLEAN DEFAULT TRUE,
    approved_at     TIMESTAMPTZ,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_affiliates_updated_at
    BEFORE UPDATE ON affiliates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_affiliates_referral_code ON affiliates(referral_code);
CREATE INDEX idx_affiliates_tier ON affiliates(tier);
CREATE INDEX idx_affiliates_is_active ON affiliates(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_affiliates_active_codes ON affiliates(referral_code) WHERE is_active = TRUE;

-- ============================
-- Affiliate Referrals
-- ============================
CREATE TABLE affiliate_referrals (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    affiliate_id    UUID NOT NULL REFERENCES affiliates(id) ON DELETE CASCADE,
    referred_email  TEXT NOT NULL,
    referred_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,

    source_url      TEXT,
    clicked_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    converted_at    TIMESTAMPTZ,

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

-- ============================
-- Affiliate Commissions
-- ============================
CREATE TABLE affiliate_commissions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    affiliate_id    UUID NOT NULL REFERENCES affiliates(id) ON DELETE CASCADE,
    referral_id     UUID REFERENCES affiliate_referrals(id) ON DELETE SET NULL,

    amount_cents        INT NOT NULL,
    currency            TEXT NOT NULL DEFAULT 'usd',
    commission_type     TEXT NOT NULL CHECK (commission_type IN ('one_time', 'recurring')),
    recurrence_number   INT,

    source_purchase_id  UUID REFERENCES purchases(id) ON DELETE SET NULL,
    source_membership_id UUID REFERENCES memberships(id) ON DELETE SET NULL,

    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'approved', 'paid', 'cancelled', 'refunded')),

    payout_id       TEXT,
    paid_at         TIMESTAMPTZ,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_affiliate_commissions_updated_at
    BEFORE UPDATE ON affiliate_commissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_affiliate_commissions_affiliate ON affiliate_commissions(affiliate_id);
CREATE INDEX idx_affiliate_commissions_status ON affiliate_commissions(status);
CREATE INDEX idx_affiliate_commissions_pending ON affiliate_commissions(status, created_at)
    WHERE status = 'pending';

COMMIT;
-- ============================================================
-- 007_automation.sql
-- ============================================================
-- ============================================================
-- MindFrame Database Schema — Migration 007: Automation Tables
-- ============================================================

BEGIN;

-- ============================
-- Automation Workflows Registry
-- ============================
CREATE TABLE automation_workflows (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name            TEXT NOT NULL,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,

    platform        TEXT NOT NULL CHECK (platform IN ('n8n', 'make', 'zapier', 'custom')),
    workflow_json   JSONB,
    external_id     TEXT,

    category        TEXT NOT NULL
                    CHECK (category IN (
                        'content_publishing', 'email_marketing', 'lead_capture',
                        'payment_processing', 'analytics', 'affiliate', 'community',
                        'monitoring', 'data_sync', 'onboarding', 'retention'
                    )),

    trigger_type    TEXT,
    cron_expression TEXT,

    is_active       BOOLEAN DEFAULT TRUE,
    last_run_at     TIMESTAMPTZ,
    last_run_status TEXT,

    alert_email     TEXT,
    max_retries     INT DEFAULT 3,

    version         INT DEFAULT 1,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_automation_workflows_updated_at
    BEFORE UPDATE ON automation_workflows
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_automation_workflows_category ON automation_workflows(category);
CREATE INDEX idx_automation_workflows_active ON automation_workflows(is_active) WHERE is_active = TRUE;

-- ============================
-- Automation Execution Logs
-- ============================
CREATE TABLE automation_execution_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    workflow_id     UUID NOT NULL REFERENCES automation_workflows(id) ON DELETE CASCADE,
    execution_id    TEXT,

    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,

    status          TEXT NOT NULL DEFAULT 'running'
                    CHECK (status IN ('running', 'success', 'failed', 'timeout', 'cancelled')),
    error_message   TEXT,
    error_stack     TEXT,

    input_data      JSONB,
    output_data     JSONB,

    trigger_source  TEXT,
    trigger_detail  JSONB DEFAULT '{}'::jsonb,

    -- Related entity IDs for linking
    related_video_id        UUID,
    related_subscriber_id   UUID,
    related_purchase_id     UUID,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_automation_logs_workflow ON automation_execution_logs(workflow_id);
CREATE INDEX idx_automation_logs_status ON automation_execution_logs(status);
CREATE INDEX idx_automation_logs_started ON automation_execution_logs(started_at);
CREATE INDEX idx_automation_logs_failed ON automation_execution_logs(workflow_id, started_at DESC)
    WHERE status = 'failed';

COMMIT;
-- ============================================================
-- 008_indexes.sql
-- ============================================================
-- ============================================================
-- MindFrame Database Schema — Migration 008: Indexes
-- ============================================================

BEGIN;

-- ============================
-- Additional indexes not covered in CREATE TABLE statements
-- ============================

-- Profiles
CREATE INDEX IF NOT EXISTS idx_profiles_members ON profiles(is_member) WHERE is_member = TRUE;
CREATE INDEX IF NOT EXISTS idx_profiles_created ON profiles(created_at);

-- Viral hooks
CREATE INDEX IF NOT EXISTS idx_viral_hooks_last_used ON viral_hooks(last_used_at DESC NULLS LAST);

-- Email subscribers
CREATE INDEX IF NOT EXISTS idx_subscribers_lifetime_value ON email_subscribers(lifetime_value DESC)
    WHERE status = 'active' AND has_purchased = TRUE;

-- Email campaigns
CREATE INDEX IF NOT EXISTS idx_campaigns_send_at ON email_campaigns(send_at)
    WHERE status = 'active' AND send_at IS NOT NULL;

-- Purchases
CREATE INDEX IF NOT EXISTS idx_purchases_customer ON purchases(customer_email);
CREATE INDEX IF NOT EXISTS idx_purchases_refund ON purchases(status, refunded_at)
    WHERE status IN ('refunded', 'partially_refunded');

-- Memberships
CREATE INDEX IF NOT EXISTS idx_memberships_cancel_at ON memberships(current_period_end)
    WHERE cancel_at_period_end = TRUE;
CREATE INDEX IF NOT EXISTS idx_memberships_churned ON memberships(ended_at DESC)
    WHERE ended_at IS NOT NULL;

-- Analytics
CREATE INDEX IF NOT EXISTS idx_funnel_events_anonymous ON analytics_funnel_events(anonymous_id)
    WHERE anonymous_id IS NOT NULL;

COMMIT;
-- ============================================================
-- 009_rls_policies.sql
-- ============================================================
-- ============================================================
-- MindFrame Database Schema — Migration 009: RLS Policies
-- ============================================================

-- ============================================================
-- WARNING: This migration requires Supabase with auth enabled.
-- Run AFTER the auth.users table exists.
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE viral_hooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_scripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_publishing_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_subscribers ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_subscriber_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_campaign_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE digital_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE membership_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE membership_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE automation_membership_blueprints ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_page_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_content_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_funnel_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_daily_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliates ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE automation_workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE automation_execution_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- ADMIN POLICIES (service_role - full access)
-- ============================================================
CREATE POLICY admin_all_profiles ON profiles FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_sessions ON user_sessions FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_templates ON content_templates FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_hooks ON viral_hooks FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_scripts ON content_scripts FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_videos ON content_videos FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_queue ON content_publishing_queue FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_subscribers ON email_subscribers FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_tags ON email_tags FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_subscriber_tags ON email_subscriber_tags FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_campaigns ON email_campaigns FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_campaign_logs ON email_campaign_logs FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_products ON digital_products FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_purchases ON purchases FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_purchase_items ON purchase_items FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_membership_plans ON membership_plans FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_memberships ON memberships FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_membership_events ON membership_events FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_blueprints ON automation_membership_blueprints FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_page_views ON analytics_page_views FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_content_events ON analytics_content_events FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_funnel_events ON analytics_funnel_events FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_daily_metrics ON analytics_daily_metrics FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_affiliates ON affiliates FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_affiliate_referrals ON affiliate_referrals FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_affiliate_commissions ON affiliate_commissions FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_workflows ON automation_workflows FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY admin_all_exec_logs ON automation_execution_logs FOR ALL USING (auth.role() = 'service_role');

-- ============================================================
-- ANON (PUBLIC) POLICIES — Read-only public content
-- ============================================================

-- Public: Anyone can read published videos and templates
CREATE POLICY anon_read_published_videos ON content_videos
    FOR SELECT USING (status = 'published');

CREATE POLICY anon_read_templates ON content_templates
    FOR SELECT USING (TRUE);

CREATE POLICY anon_read_hooks ON viral_hooks
    FOR SELECT USING (TRUE);

CREATE POLICY anon_read_products ON digital_products
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY anon_read_membership_plans ON membership_plans
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY anon_read_blueprints ON automation_membership_blueprints
    FOR SELECT USING (TRUE);

-- Public: Allow anonymous funnel event creation
CREATE POLICY anon_insert_funnel_events ON analytics_funnel_events
    FOR INSERT WITH CHECK (profile_id IS NULL);

-- ============================================================
-- AUTHENTICATED USER POLICIES
-- ============================================================

-- Users: own profile
CREATE POLICY user_read_own_profile ON profiles
    FOR SELECT USING (auth.uid() = auth_id);

CREATE POLICY user_update_own_profile ON profiles
    FOR UPDATE USING (auth.uid() = auth_id)
    WITH CHECK (auth.uid() = auth_id);

-- Users: own sessions
CREATE POLICY user_read_own_sessions ON user_sessions
    FOR SELECT USING (profile_id IN (
        SELECT id FROM profiles WHERE auth_id = auth.uid()
    ));

-- Users: own purchases
CREATE POLICY user_read_own_purchases ON purchases
    FOR SELECT USING (profile_id IN (
        SELECT id FROM profiles WHERE auth_id = auth.uid()
    ));

-- Users: own items
CREATE POLICY user_read_own_purchase_items ON purchase_items
    FOR SELECT USING (purchase_id IN (
        SELECT id FROM purchases WHERE profile_id IN (
            SELECT id FROM profiles WHERE auth_id = auth.uid()
        )
    ));

-- Users: own membership
CREATE POLICY user_read_own_membership ON memberships
    FOR SELECT USING (profile_id IN (
        SELECT id FROM profiles WHERE auth_id = auth.uid()
    ));

-- Users: own membership events
CREATE POLICY user_read_own_membership_events ON membership_events
    FOR SELECT USING (profile_id IN (
        SELECT id FROM profiles WHERE auth_id = auth.uid()
    ));

-- Users: own affiliate profile
CREATE POLICY user_read_own_affiliate ON affiliates
    FOR SELECT USING (profile_id IN (
        SELECT id FROM profiles WHERE auth_id = auth.uid()
    ));

-- Users: own referrals
CREATE POLICY user_read_own_referrals ON affiliate_referrals
    FOR SELECT USING (affiliate_id IN (
        SELECT id FROM affiliates WHERE profile_id IN (
            SELECT id FROM profiles WHERE auth_id = auth.uid()
        )
    ));

-- Users: own commissions
CREATE POLICY user_read_own_commissions ON affiliate_commissions
    FOR SELECT USING (affiliate_id IN (
        SELECT id FROM affiliates WHERE profile_id IN (
            SELECT id FROM profiles WHERE auth_id = auth.uid()
        )
    ));

-- Authenticated: can create funnel events tied to their profile
CREATE POLICY user_insert_funnel_events ON analytics_funnel_events
    FOR INSERT WITH CHECK (
        profile_id IN (SELECT id FROM profiles WHERE auth_id = auth.uid())
    );

-- Authenticated: can insert page views
CREATE POLICY user_insert_page_views ON analytics_page_views
    FOR INSERT WITH CHECK (
        profile_id IN (SELECT id FROM profiles WHERE auth_id = auth.uid())
        OR profile_id IS NULL
    );
-- ============================================================
-- 010_seed_hooks.sql
-- ============================================================
-- ============================================================
-- MindFrame Database Schema — Seed Data: Viral Hooks
-- ============================================================
-- Source: /home/team/shared/content/HOOKS_DATABASE.json (50 hooks)

BEGIN;

INSERT INTO viral_hooks (hook_text, category, trigger_type, estimated_performance) VALUES
('Stop wasting your mornings on other people''s priorities.', 'Discipline', 'Loss Aversion', 9.2),
('Your comfort zone is a slow-motion suicide.', 'Mindset', 'Fear/Urgency', 9.5),
('The reason you''re burnt out isn''t work—it''s your lack of boundaries.', 'Health', 'Insight', 8.8),
('99% of people are doing ''deep work'' completely wrong.', 'Productivity', 'Contrarian', 9.1),
('You''re not lazy; you''re just overstimulated.', 'Health', 'Reassurance/Insight', 8.7),
('The person you want to become doesn''t have your current habits.', 'Mindset', 'Identity Shift', 9.0),
('How a Stoic handles a toxic workplace.', 'Mindset', 'Authority/Stoicism', 8.5),
('The productivity system of the top 0.1%.', 'Productivity', 'Exclusivity', 9.3),
('Stop acting like you have 1,000 years to live.', 'Mindset', 'Urgency', 9.4),
('Protect your attention like your life depends on it.', 'Discipline', 'High Stakes', 8.9),
('The hidden cost of ''one more video''.', 'Productivity', 'Curiosity', 8.6),
('Why your brain craves distraction (and how to fix it).', 'Productivity', 'Problem/Solution', 8.9),
('The dark side of ''hustle culture'' nobody talks about.', 'Mindset', 'Mystery', 8.8),
('One habit that will make you unrecognizable in 6 months.', 'Mindset', 'Transformation', 9.6),
('The ''Dopamine Detox'' secret that actually works.', 'Health', 'Authority', 9.0),
('Consistency is overrated. Intensity is what matters.', 'Discipline', 'Contrarian', 9.2),
('Stop reading books. Start implementing them.', 'Productivity', 'Contrarian', 9.1),
('Your ''to-do'' list is actually a ''distraction'' list.', 'Productivity', 'Insight', 8.7),
('The best way to get more done is to do less.', 'Productivity', 'Paradox', 8.9),
('Motivation is a myth. Only systems remain.', 'Discipline', 'Core Belief', 9.3),
('Rich people don''t have better luck; they have better systems.', 'Money', 'Comparison', 9.0),
('The ''Asymmetric Bet'' that will change your financial life.', 'Money', 'Curiosity/Greed', 9.2),
('Stop saving money. Start buying time.', 'Money', 'Contrarian', 9.4),
('Your circle is either a net or a cage.', 'Relationships', 'Metaphor', 8.8),
('How to spot a low-value person in 30 seconds.', 'Relationships', 'Social Proof', 9.5),
('The law of detachment: Why wanting less gets you more.', 'Mindset', 'Paradox', 8.7),
('You aren''t tired; you''re uninspired.', 'Mindset', 'Call-out', 8.9),
('The military secret to instant discipline.', 'Discipline', 'Authority', 9.1),
('Stop trading your health for wealth you''ll be too sick to enjoy.', 'Health', 'Tough Love', 9.3),
('The 5 AM club is a lie. Here''s what actually works.', 'Productivity', 'Pattern Interrupt', 9.5),
('If you don''t control your mind, someone else will.', 'Mindset', 'Fear', 9.2),
('The psychology of why you keep procrastinating.', 'Productivity', 'Educational', 8.6),
('High-performers don''t have willpower; they have environments.', 'Discipline', 'Insight', 9.0),
('The $10,000/hour skill you''re ignoring.', 'Money', 'Greed', 9.4),
('Stop arguing with people who haven''t done the work.', 'Relationships', 'Boundary', 9.1),
('The truth about multitasking: It''s just ''task switching''.', 'Productivity', 'Myth-busting', 8.5),
('Your phone is a tool or a weapon. You choose.', 'Discipline', 'Metaphor', 8.7),
('The most dangerous addiction is a comfortable salary.', 'Money', 'Tough Love', 9.6),
('Success is 10% strategy and 90% emotional control.', 'Mindset', 'Statistic', 8.8),
('The Stoic guide to handling rejection.', 'Mindset', 'Practicality', 8.4),
('Why being ''nice'' is keeping you weak.', 'Mindset', 'Contrarian', 9.5),
('The 80/20 rule of your social circle.', 'Relationships', 'System', 8.9),
('How to build an ''Anti-Fragile'' mindset.', 'Mindset', 'Niche Terminology', 9.0),
('The one word that destroys your productivity: ''Later''.', 'Productivity', 'Punchy', 8.7),
('Stop seeking approval from people you don''t even respect.', 'Relationships', 'Truth Bomb', 9.2),
('The ''Dark Room'' method for solving any problem.', 'Productivity', 'Mystery', 9.3),
('Why your brain is programmed to be average.', 'Mindset', 'Biological', 8.9),
('The financial advice 90% of people get wrong.', 'Money', 'Fear of Being Wrong', 9.1),
('Discipline isn''t a punishment; it''s the ultimate freedom.', 'Discipline', 'Reframing', 9.0),
('The world doesn''t care about your potential. Only your output.', 'Mindset', 'Harsh Reality', 9.7);

COMMIT;