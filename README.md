# MindFrame

**The Operating System for Your Mind.** A faceless AI-powered self-improvement and productivity media brand + digital product ecosystem. Every piece of content funnels viewers into a digital products ecosystem — courses, templates, prompt packs, and a membership community — creating recurring revenue with near-zero marginal cost. The entire content-to-checkout pipeline runs on AI agents and automations.

## Repository Structure

```
/
├── landing-pages/       # HTML landing pages for marketing campaigns
├── engineering/         # Technical infrastructure & automation
│   ├── deploy/          # Docker Compose, setup scripts, env template
│   ├── workflows/       # n8n workflow JSON exports (8 workflows)
│   ├── sql/             # 10 database migration files
│   ├── scripts/         # Launch & Supabase setup scripts
│   └── infrastructure/  # Deployment documentation
├── content/             # Content strategy, scripts, hooks, templates
│   ├── branding/        # Brand guide and visual identity
│   ├── hooks/           # 50 viral hooks database
│   ├── scripts/         # Script batches and production guides
│   ├── templates/       # Content template definitions
│   └── production/      # Production batches and asset manifest
├── growth/              # Marketing funnels, emails, analytics
│   ├── funnels/         # Funnel architecture maps
│   ├── emails/          # Email sequence copy
│   ├── lead-magnets/    # Lead magnet specs
│   ├── analytics/       # Dashboard and monitoring
│   ├── landing-page/    # Landing page HTML files
│   └── 30-day launch plan
└── products/            # Product specs and packages
```

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/gallant782/SPYTEFUL.git

# 2. Configure environment
cp engineering/.env.example .env
vim .env  # Fill in API keys

# 3. Deploy the full stack
./engineering/deploy/deploy.sh
```

## Infrastructure Stack

| Component | Technology |
|-----------|-----------|
| Database | Supabase (PostgreSQL 15) |
| Automation | n8n (self-hosted, Docker) |
| Payments | Stripe + Gumroad |
| Email | Beehiiv / ConvertKit |
| AI Scripts | OpenAI GPT-4 |
| Voiceover | ElevenLabs |
| Auth | Supabase Auth |
| Deploy | Docker Compose + Supabase CLI |

## 8 n8n Workflows

| # | Workflow | Trigger |
|---|----------|---------|
| 1 | Script Generator | Webhook (hook_id + template_id) |
| 2 | Lead Magnet Delivery | Landing page form submit |
| 3 | Purchase Handler | Stripe checkout.session.completed |
| 4 | Daily Metrics Rollup | CRON @midnight |
| 5 | Welcome Sequence | Webhook (5-day email drip) |
| 6 | Affiliate Commission | Purchase with affiliate_id |
| 7 | Membership Sync | Stripe subscription lifecycle |
| 8 | Churn Alert | CRON @6am |

## Revenue Model

| Stream | Model | Target |
|--------|-------|--------|
| Digital products | One-time via Gumroad | $2K–$4K/mo |
| Premium membership | $19/mo subscription | $3K–$5K/mo |
| Affiliate revenue | Commission-based | $1K–$2K/mo |
| Sponsorships | Per-post | $1K–$3K/mo |
| AI automation packages | $97–$297 one-time | $1K–$2K/mo |

**Total Target: $8,000–$16,000/mo**

---

*Built by the MindFrame team.*