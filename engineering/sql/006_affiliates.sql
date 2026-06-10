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