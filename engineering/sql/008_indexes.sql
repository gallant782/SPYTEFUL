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