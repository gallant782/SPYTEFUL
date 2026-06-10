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