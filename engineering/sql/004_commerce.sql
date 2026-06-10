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