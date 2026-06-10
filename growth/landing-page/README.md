# MindFrame Landing Pages Deployment Guide

This directory contains the production-ready HTML/CSS landing pages for MindFrame.

## Files
- `index.html`: Lead Generation landing page for the "5-Minute Daily System" (Lead Magnet).
- `product.html`: Sales page for "The Productivity Vault" ($27 Product).

## Design Specs
- **Color Palette:**
  - Background: Black (#000000) / Charcoal (#121212)
  - Accent: Neon Lime (#39FF14)
  - Text: White (#FFFFFF)
- **Typography:** Montserrat (via Google Fonts).
- **Framework:** Tailwind CSS (CDN).

## Deployment Instructions

### 1. Vercel (Recommended)
1. Install Vercel CLI: `npm i -g vercel`.
2. Run `vercel` in this directory.
3. Follow prompts to deploy.

### 2. Framer (High-Fidelity Spec)
Use these HTML files as a structural and copy reference for building custom Framer components. The Tailwind classes translate directly to Framer's layout properties.

### 3. Email Integration
The form in `index.html` is ready for integration. 
- **Beehiiv:** Replace the `<form action="#">` with your Beehiiv publication subscribe URL.
- **ConvertKit:** Replace the form action with `https://app.convertkit.com/forms/[YOUR_FORM_ID]/subscriptions`.

## Updates
For any copy or design changes, please update `LANDING_PAGE_SPEC.md` first before modifying these files to maintain consistency.
