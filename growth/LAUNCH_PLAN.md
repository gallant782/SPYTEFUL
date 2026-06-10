# MindFrame Launch Playbook

## 7-Day Launch Plan (Day by Day)

**Day 1: Infrastructure Setup**
- [ ] Create Supabase project
- [ ] Run the SQL migrations from `/home/team/shared/engineering/sql/`
- [ ] Deploy n8n (Railway or Fly.io)
- [ ] Configure Stripe account and products
- [ ] Set up Gumroad for digital products

**Day 2: Landing Pages & Email**
- [ ] Deploy lead magnet landing page to Vercel
- [ ] Set up Beehiiv/ConvertKit account
- [ ] Import email sequences from `/home/team/shared/growth/EMAIL_SEQUENCES.md`
- [ ] Test lead capture flow end-to-end

**Day 3: Product Delivery**
- [ ] Set up Gumroad products (lead magnet, tripwire)
- [ ] Upload product files from `/home/team/shared/products/deliverables/`
- [ ] Test purchase flow end-to-end
- [ ] Configure automated delivery

**Day 4: Content Engine**
- [ ] Set up ElevenLabs voice (Adam/Antoni)
- [ ] Generate first 3 videos using script templates + sample scripts
- [ ] Create thumbnail templates in Canva
- [ ] Set up social media accounts (TikTok, IG, YT)

**Day 5: Automation Workflows**
- [ ] Deploy n8n workflows from `/home/team/shared/engineering/workflows/`
- [ ] Test script generator → voiceover pipeline
- [ ] Test lead magnet delivery automation
- [ ] Test purchase handler

**Day 6: Launch Prep**
- [ ] Schedule first 7 videos across platforms
- [ ] Set up affiliate program in Gumroad
- [ ] Create engagement response templates
- [ ] Final QA of all systems

**Day 7: LAUNCH**
- [ ] Post first video
- [ ] Monitor analytics dashboard
- [ ] Respond to first comments
- [ ] Begin content velocity cadence (1 video/day/platform)

## 30-Day Growth Targets
- Followers: 2,000+ total across platforms
- Email subscribers: 500+
- Revenue: $500+ (tripwire + early memberships)
- Content published: 30+ videos

## 90-Day Scaling Targets
- Followers: 20,000+
- Email subscribers: 5,000+
- Revenue: $5,000+/mo (targeting $10K)
- Content published: 90+ videos
- Membership churn: <8%
- Lead-to-tripwire conversion: >3%

## KPI Dashboard Setup
Include the SQL queries from `/home/team/shared/engineering/deployment-plan.md` that should be run daily:

**Daily revenue snapshot:**
```sql
SELECT metric_date,
       total_revenue_cents / 100.0 AS revenue_dollars,
       tripwire_sales,
       membership_new_sales,
       new_subscribers,
       churned_members
FROM analytics_daily_metrics
WHERE metric_date >= NOW() - INTERVAL '30 days'
ORDER BY metric_date DESC;
```

**Funnel conversion rates:**
```sql
SELECT 
    ROUND(SUM(new_subscribers)::DECIMAL / NULLIF(SUM(total_views), 0) * 100, 2) as view_to_lead_cr,
    ROUND(SUM(tripwire_sales)::DECIMAL / NULLIF(SUM(new_subscribers), 0) * 100, 2) as lead_to_tripwire_cr
FROM analytics_daily_metrics
WHERE metric_date >= NOW() - INTERVAL '30 days';
```

**Top performing hooks:**
```sql
SELECT h.hook_text, 
       SUM(v.views) as total_views, 
       SUM(v.likes) as total_likes,
       ROUND(AVG(v.engagement_rate), 2) as avg_engagement
FROM content_videos v
JOIN viral_hooks h ON v.hook_id = h.id
GROUP BY h.id, h.hook_text
ORDER BY total_views DESC
LIMIT 10;
```

**Automation health check:**
```sql
SELECT w.name,
       COUNT(*) FILTER (WHERE l.status = 'failed') AS failures,
       COUNT(*) FILTER (WHERE l.status = 'success') AS successes,
       ROUND(
           COUNT(*) FILTER (WHERE l.status = 'success')::DECIMAL /
           NULLIF(COUNT(*), 0) * 100, 2
       ) AS success_rate
FROM automation_workflows w
JOIN automation_execution_logs l ON l.workflow_id = w.id
WHERE l.started_at >= NOW() - INTERVAL '24 hours'
GROUP BY w.id, w.name
ORDER BY success_rate ASC;
```

## Daily Operating Procedures (<1 hour/day)
- Morning: Check analytics dashboard (5 min)
- Check automation logs for failures (5 min)
- Approve/queue AI-generated scripts (10 min)
- Schedule/post videos (10 min)
- Engage with top comments (10 min)
- Review weekly metrics and adjust (remaining time)
