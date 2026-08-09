# MindFrame Setup Guide — Launch in 30 Minutes

You only need three services to go live. No Docker, no database. Just these:

---

## 1. Deploy Landing Page (5 min)

Your landing page is `landing-page/index.html`. Deploy it to Vercel:

**Option A — Drag and drop (fastest):**
1. Go to [vercel.com](https://vercel.com) → New Project
2. Drag `landing-page/` folder onto the upload area
3. Click Deploy — that's it

**Option B — CLI:**
```bash
cd landing-page
npx vercel deploy --prod
```

Your site is now live at `https://your-project.vercel.app`. The page already has an email capture form wired to ConvertKit.

---

## 2. Import n8n Workflows (10 min)

The `workflows/` folder has 8 pre-built automations. Import them into n8n:

**Option A — n8n Cloud (recommended):**
1. Sign up at [n8n.cloud](https://n8n.cloud) — free tier works
2. Go to Workflows → Import from File
3. Import each JSON from `workflows/` one by one
4. Set your API credentials (Credentials tab in n8n):
   - OpenAI: for script generation
   - ElevenLabs: for voiceovers
   - ConvertKit: for email automation
   - Stripe: for payment handling

**Option B — Self-hosted:**
```bash
docker run -d --name n8n -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e N8N_ENCRYPTION_KEY=$(openssl rand -base64 32) \
  n8nio/n8n
```

Then open `http://localhost:5678` and import workflows.

**What each workflow does:**
| # | Workflow | Trigger | What it does |
|---|----------|---------|---------------|
| 01 | Script Generator | Manual / CRON | Generates video scripts via OpenAI + voiceovers via ElevenLabs |
| 02 | Lead Magnet Delivery | Webhook (ConvertKit) | Sends free PDF when someone opts in |
| 03 | Purchase Handler | Webhook (Stripe) | Processes Gumroad/Stripe purchases, delivers products |
| 04 | Daily Metrics Rollup | CRON (daily) | Pulls analytics from social platforms, emails summary |
| 05 | Welcome Sequence | Triggered by 02 | 5-day automated email drip via ConvertKit |
| 06 | Affiliate Commission | Webhook (Stripe) | Tracks and pays affiliate commissions |
| 07 | Membership Sync | Webhook (Stripe) | Manages member access, cancellations, upgrades |
| 08 | Churn Alert | CRON (daily) | Detects at-risk subscribers, triggers re-engagement |

---

## 3. Set Up Gumroad Products (15 min)

Create your product ladder on [Gumroad](https://gumroad.com):

### Product 1: Free Lead Magnet ($0)
- Upload a PDF or template as the product file
- Enable "Require email" — this builds your list
- Connect to ConvertKit in Gumroad Settings → Integrations

### Product 2: MindFrame Vault ($27)
- Bundle your best templates, prompt packs, and guides
- Add an upsell to Product 3

### Product 3: Pro Membership ($19/month)
- Set as recurring subscription
- Deliver monthly content drops (use workflow 07 to automate)

### Product 4: Automation Accelerator ($97–$297)
- Three pricing tiers (use variants)
- Include done-with-you n8n setup

### Product 5: Complete Bundle ($147)
- Bundle Products 2 + 3 (first month) + 4 Standard

**Key Gumroad settings:**
- Settings → Integrations → Add ConvertKit API key
- Map each product to a ConvertKit tag for automation

---

## Done!

Once these three are set up:
- Your landing page is live collecting emails
- n8n workflows are automating content creation and email delivery
- Gumroad is selling products and delivering automatically

Total setup time: ~30 minutes for a solo founder.
