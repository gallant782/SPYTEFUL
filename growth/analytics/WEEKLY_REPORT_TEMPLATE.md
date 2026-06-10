# MindFrame | Weekly Growth Report
**Reporting Period:** [YYYY-MM-DD] to [YYYY-MM-DD]

---

## Executive Summary
*   **Total Revenue:** $[0.00]
*   **Total Leads:** [0]
*   **Top Channel:** [TikTok/IG/Shorts]
*   **System Status:** [Healthy/Warning/Critical]

---

## Section 1: Content Performance
*Goal: Track reach and hook effectiveness.*

| Metric | TikTok | Reels | YouTube Shorts | Total |
| :--- | :--- | :--- | :--- | :--- |
| **Views** | | | | |
| **Shares** | | | | |
| **Save Rate** | | | | |
| **Followers Gained**| | | | |

**Top 3 Hooks This Week:**
1. [Hook Name] - [Views] - [Engagement %]
2. [Hook Name] - [Views] - [Engagement %]
3. [Hook Name] - [Views] - [Engagement %]

> **SQL Tooling (Run in Supabase):**
> ```sql
> SELECT hook_name, sum(views) as total_views, (sum(likes)+sum(shares))/sum(views)::float as eng_rate 
> FROM content_stats 
> WHERE created_at > now() - interval '7 days' 
> GROUP BY 1 ORDER BY 2 DESC LIMIT 3;
> ```

---

## Section 2: Funnel Metrics
*Goal: Identify drop-off points in the conversion path.*

| Stage | Volume | Conversion % | Benchmark |
| :--- | :--- | :--- | :--- |
| **Content Views** | | - | - |
| **Profile Visits** | | [%] | 5% |
| **LP Visits** | | [%] | 60% of Profile |
| **Email Opt-ins** | | [%] | 20% of LP |
| **Product Views** | | [%] | 15% of Opt-ins |
| **Total Sales** | | [%] | 3% of LP |

**Funnel Health:** [Optimal / Leaking / Blocked]
*Notes:* [e.g., Profile visit rate is high but LP opt-in is low. Check LP copy.]

---

## Section 3: Revenue & LTV
*Goal: Measure financial sustainability.*

*   **Digital Products ($27 Vault):** $[0.00]
*   **Membership ($19/mo):** $[0.00]
*   **Affiliate Commissions:** $[0.00]
*   **Gross Revenue:** $[0.00]
*   **Customer Acquisition Cost (CAC):** $[0.00] (If paid ads used)
*   **Estimated LTV:** $[0.00]

---

## Section 4: Automation & Systems
*Goal: Ensure the "Faceless Engine" is running without manual friction.*

*   **n8n Workflow Success Rate:** [%]
*   **Lead Delivery Latency:** [< 30s]
*   **Database Uptime:** [99.9%]
*   **Errors Logged:** [List critical errors if any]

> **Health Query:**
> ```sql
> SELECT workflow_name, success_count, error_count 
> FROM automation_logs 
> WHERE execution_time > now() - interval '7 days';
> ```

---

## Section 5: Recommendations for Next Week
1. **Double Down:** [e.g., "Negative Bias" hooks are outperforming. Create 3 more in that style.]
2. **Fix:** [e.g., Opt-in form on mobile has a 2s delay. Optimize image sizes.]
3. **Experiment:** [e.g., Test a 24-hour flash sale for membership in the email nurture sequence.]
4. **Content Pivot:** [e.g., Sunday morning posts are underperforming; move to Sunday 8 PM.]
