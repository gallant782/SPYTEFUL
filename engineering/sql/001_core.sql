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