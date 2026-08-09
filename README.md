# MindFrame

A faceless AI-powered self-improvement and productivity media brand. **Revenue target: $8,000–$16,000/mo.**

This repo contains everything you need to launch in under 30 minutes.

---

## What's Inside

```
mindframe-launch/
├── landing-page/        # index.html + product.html → deploy to Vercel
├── workflows/           # 8 n8n automation workflows → import into n8n
├── setup/               # Step-by-step launch guide
├── .env.example         # API keys you'll need (copy to .env)
└── README.md            # You are here
```

---

## Quick Launch (30 min)

### Step 1 — Deploy landing page (5 min)
Drag `landing-page/` onto [Vercel](https://vercel.com) or run `npx vercel deploy` inside the folder. Your sales page is live.

### Step 2 — Import workflows (10 min)
Sign up for [n8n.cloud](https://n8n.cloud) (free tier), import all 8 JSON files from `workflows/`, and plug in your API keys.

### Step 3 — Set up products (15 min)
Create your 5-tier product ladder on [Gumroad](https://gumroad.com): Free lead magnet → $27 Vault → $19/mo Membership → $97–$297 Accelerator → $147 Bundle.

**Detailed instructions:** See `setup/SETUP.md`

---

## The Automation Engine

| Workflow | What it automates |
|----------|-------------------|
| Script Generator | AI-written scripts + voiceovers, ready to post |
| Lead Magnet Delivery | Instant freebie delivery when someone opts in |
| Purchase Handler | Payment processing + product delivery |
| Daily Metrics Rollup | Automated analytics reports |
| Welcome Sequence | 5-day email drip for new subscribers |
| Affiliate Commission | Track + pay affiliate commissions |
| Membership Sync | Manage subscriptions, upgrades, cancellations |
| Churn Alert | Detect at-risk subscribers, trigger win-back |

---

## Revenue Streams

| Product | Price | Type |
|---------|-------|------|
| Lead Magnet | Free | Email capture |
| MindFrame Vault | $27 | One-time |
| Pro Membership | $19/mo | Recurring |
| Automation Accelerator | $97–$297 | One-time |
| Complete Bundle | $147 | One-time |

---

## API Keys Needed

Copy `.env.example` to `.env` and fill in:
- **Stripe** — publishable + secret keys (dashboard.stripe.com)
- **OpenAI** — API key for script generation
- **ElevenLabs** — API key for AI voiceovers
- **ConvertKit** — API key + secret for email automation
- **Gumroad** — access token for product delivery

---

## Content Strategy

Daily short-form videos (TikTok, Reels, Shorts) on psychology, productivity, and AI automation. Every video funnels viewers to the free lead magnet → product ladder. The n8n Script Generator workflow produces scripts and voiceovers on autopilot.

---

## Need the Full Engineering Stack?

This is the **launch repo** — minimal, deployable, no complexity. The full engineering repo with Docker Compose, Supabase migrations, SQL schema, and production deployment scripts lives at [`gallant782/SPYTEFUL`](https://github.com/gallant782/SPYTEFUL).
