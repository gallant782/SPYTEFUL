# MindFrame | Conversion Tracking Specification

This document outlines the tracking infrastructure required to measure the efficiency of the MindFrame content-to-commerce funnel.

## 1. Tracking Infrastructure
All landing pages must include the following snippets before the closing `</head>` tag.

### Google Analytics 4 (GA4)
**Purpose:** Overall traffic analysis and audience demographics.
```html
<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>
```

### PostHog (Product Analytics)
**Purpose:** Event-based tracking and session recordings for funnel optimization.
```javascript
<script>
    !function(t,e){var o,n,p,r;e.__sv||(window.posthog=e,e._i=[],e.init=function(i,s,a){function g(t,e){var o=e.split(".");2==o.length&&(t=t[o[0]],e=o[1]),t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)))}}(p=t.createElement("script")).type="text/javascript",p.async=!0,p.src=s.api_host+"/static/array.js",(r=t.getElementsByTagName("script")[0]).parentNode.insertBefore(p,r);var u=e;for(void 0!==a?u=e[a]=[]:a="posthog",u.people=u.people||[],u.toString=function(t){var e="posthog";return"posthog"!==a&&(e+="."+a),t||(e+=" (stub)"),e},u.people.toString=function(){return u.toString(1)+".people (stub)"},o="capture identify alias people.set people.set_once set_config register register_once unregister opt_out_capturing has_opted_out_capturing opt_in_capturing reset isFeatureEnabled onFeatureFlags getFeatureFlag getFeatureFlagPayload reloadFeatureFlags group updateEarlyAccessFeatureEnrollment getEarlyAccessFeatures onSessionId".split(" "),n=0;n<o.length;n++)g(u,o[n]);e._i.push([i,s,a])},e.__sv=1.0)}(document,window.posthog||[]);
    posthog.init('<ph_project_api_key>',{api_host:'https://app.posthog.com'})
</script>
```

## 2. UTM Parameter Strategy
Every link in social bios, captions, and emails **MUST** use UTM parameters.

| Parameter | Value Example | Description |
| :--- | :--- | :--- |
| `utm_source` | `tiktok`, `instagram`, `youtube`, `email` | The platform source |
| `utm_medium` | `short_video`, `bio_link`, `newsletter` | The format |
| `utm_campaign` | `batch_01_productivity`, `launch_vault` | The specific campaign/batch |
| `utm_content` | `hook_negative_bias`, `button_hero` | The specific piece of content or element |

**Example TikTok Bio Link:**
`mindframe.ai/vault?utm_source=tiktok&utm_medium=bio_link&utm_campaign=batch_01&utm_content=profile`

---

## 3. Event Tracking Matrix

| Event Name | Trigger | Properties |
| :--- | :--- | :--- |
| `lead_capture` | Form submission on `/` | `lead_source`, `lead_magnet_id` |
| `product_view` | Page load on `/product` | `product_id`, `price` |
| `add_to_cart` | Click "Buy Now" | `product_id`, `currency` |
| `purchase_complete`| Successful checkout | `revenue`, `transaction_id`, `product_list` |
| `membership_start` | Successful Stripe sub | `plan_id`, `mrr_value` |

### Implementation Snippet (JavaScript)
```javascript
// Generic event capture
function trackMindFrameEvent(eventName, properties) {
    if (window.posthog) {
        posthog.capture(eventName, properties);
    }
    if (window.gtag) {
        gtag('event', eventName, properties);
    }
}

// Example: Email Sign up
document.querySelector('#optin-form').addEventListener('submit', () => {
    trackMindFrameEvent('lead_capture', {
        lead_magnet: '5_min_daily_system',
        source: new URLSearchParams(window.location.search).get('utm_source')
    });
});
```

## 4. Facebook Pixel (Meta)
To be added when scaling via paid acquisition.
```html
<!-- Meta Pixel Code -->
<script>
!function(f,b,e,v,n,t,s)
{if(f.fbq)return;n=f.fbq=function(){n.callMethod?
n.callMethod.apply(n,arguments):n.queue.push(arguments)};
if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
n.queue=[];t=b.createElement(e);t.async=!0;
t.src=v;s=b.getElementsByTagName(e)[0];
s.parentNode.insertBefore(t,s)}(window, document,'script',
'https://connect.facebook.net/en_US/fbevents.js');
fbq('init', 'YOUR_PIXEL_ID');
fbq('track', 'PageView');
</script>
```
