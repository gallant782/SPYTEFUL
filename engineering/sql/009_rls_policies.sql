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