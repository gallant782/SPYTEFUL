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