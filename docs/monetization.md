# Monetization

Status: Working draft  
Last reviewed: 2026-08-24

## Recommendation

Use a generous free product with a clearly optional Pro tier. Do not use advertising. Offer monthly and annual subscriptions plus a lifetime purchase while the product remains predominantly local and has low recurring service costs.

Working price points for US testing:

- $4.99 monthly.
- $29.99 yearly.
- $59.99–$69.99 lifetime.
- Optional launch offer: $29.99–$39.99 founder lifetime, explicitly limited by time or quantity.

These are hypotheses, not final store prices. Localize by market and re-evaluate when infrastructure costs or feature scope change.

## Why this model fits

- A useful free radial planner creates the habit and demonstrates the interaction before asking for payment.
- A subscription can support continued platform work, compatibility, reminders, integrations, and sync.
- Lifetime matches user expectations for a focused utility and can finance early development.
- Keeping the core planning loop free avoids making the product feel like a demo or trapping user data behind payment.
- Ads would undermine calmness, privacy, visual space, and trust.

## Proposed entitlement boundary

### Free

- Unlimited basic tasks.
- Core Today polar clock.
- Dragging and resizing task arcs.
- Common recurrence patterns.
- Snooze, Extend, Do Now, Complete, Skip, and Undo.
- Basic list/timeline and calendar access.
- Short recent-history and basic completion insights.
- Local on-device storage.

### Pro

- External calendar integrations and multiple calendars.
- Widgets, Live Activities, watch surfaces, and advanced notification controls.
- Cross-device sync and backup, if offered.
- Advanced recurrence, reusable day templates, and apply-forward planning tools.
- Full history and deeper, supportive analytics.
- Extended clock customization, themes, and alternate app icons.
- Export, import, and shareable summaries.
- Future power-user scheduling assistance.

The exact boundary should follow user value and ongoing cost. Avoid arbitrary limits such as allowing only a tiny number of tasks; they block the moment when the core product becomes meaningful.

## Competitive price context

Observed US prices on 2026-08-24:

- Dialed: $3.99/month, $24.99/year, $34.99 lifetime.
- DayDial: free tier, $9/month, $49 lifetime.
- DayByDay: $0.99/month, $2.99/year, $8.99 lifetime.
- Weel: $7.99/month, $39.99/year.
- Structured: $6.99/month, $29.99/year, $99.99 lifetime.
- Tiimo: about $12/month or $54/year in the observed listing.
- Sunsama: $22/month or $204/year.
- Motion: starts around $19/month billed annually.

The recommended annual price sits near Structured, below ADHD-specialist and professional planning products, and above low-cost circular utilities. That position is credible only if the app adds adoption essentials such as import, reminders, widgets, backup, and polished onboarding.

See [Competitive analysis](competitive-analysis.md) for source links and product context.

## Lifetime-purchase policy

Lifetime is attractive while the app can operate without substantial hosted costs. Define it as access to the current app's Pro feature set and normal product updates, subject to platform terms; do not imply perpetual access to expensive third-party or AI services.

If hosted sync, collaboration, or model inference becomes meaningful, either:

- Include a reasonable service allowance and sell additional usage.
- Keep lifetime for local Pro features and introduce a separate services plan.
- Retire lifetime for new customers while honoring existing purchases.

Do not rely on lifetime revenue as a permanent operating model.

## Trial and paywall approach

- Let users understand the core radial interaction before presenting a paywall.
- Offer a 7- or 14-day Pro trial at the moment a high-value feature is requested.
- Explain the specific unlocked outcome, such as “See your calendars on the day ring,” rather than “Upgrade to Pro.”
- Preserve read access and user data after a trial ends.
- Allow purchase restoration and clear cancellation language.

Natural paywall moments include connecting a second calendar, adding a widget, enabling cross-device backup, opening longer history, or saving an advanced recurrence/template.

## Additional revenue options

- A voluntary tip jar can support early fans but should not be the primary model.
- A paid launch bundle could include lifetime Pro and a limited founder icon/theme without creating permanent product fragmentation.
- Family sharing may increase value if supported cleanly by the platform.
- Team plans and collaboration are out of scope unless real demand emerges; they would change the product and market substantially.

## Validation plan

1. Interview retained beta users about which missing capability would cause them to pay.
2. Use a non-binding preference screen to compare annual and lifetime interest before launch.
3. Test price presentation rather than many artificial feature bundles.
4. Measure conversion after actual value moments, not only at app open.
5. Revisit pricing after calendar integration, widgets, and backup are working reliably.

## Decision criteria

Keep the proposed model if it produces sustainable revenue without lowering activation or trust. Reconsider it if:

- Most retained users need Pro features simply to make the planner functional.
- Hosted costs create negative lifetime economics.
- Platform expectations strongly favor a one-time purchase for the implemented scope.
- Paid conversion depends on manipulative limits rather than differentiated value.

## Open questions

- Which Pro feature is the strongest honest conversion driver?
- Is lifetime necessary for launch conversion, or does it cannibalize annual revenue?
- Will calendar integration be free because it is an adoption prerequisite, with multiple calendars or advanced controls paid?
- Can sync rely on platform-owned infrastructure while preserving local-first economics and privacy?
- Should early supporters receive price protection as the feature set grows?
