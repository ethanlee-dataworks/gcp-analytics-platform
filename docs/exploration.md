# GA4 sample exploration

What I checked in `bigquery-public-data.ga4_obfuscated_sample_ecommerce` before designing the models and the synthetic ad spend. Queries are in [`sql/adhoc/`](../sql/adhoc/).

## 1. Tables and size ([01_tables.sql](../sql/adhoc/01_tables.sql))

- 92 daily tables, 2020-11-01 to 2021-01-31, none missing. Total 3.34 GB.
- Weekly pattern: weekends drop to about 60% of weekdays (e.g. 2020-11-07 Sat 34k rows vs weekdays around 50k).
- The peak is not Black Friday (11-27, 54k rows). It runs from Cyber Monday (11-30) to about 12-11, with the max on 12-08 (92k rows), likely orders before Christmas shipping cut-offs.
- Holiday drop from 12-19, lowest 12-24 to 01-03 (about 22k rows), back to normal by mid January.

**Decisions**

- Synthetic ad spend follows the same shape: higher on weekdays, a budget boost in early December, lower over the holidays.
- A full scan is at most 3.34 GB, far inside the 1 TB monthly free tier. Models still use incremental loads, as they would for a real client.
- Assertion candidate: every day in the range has a table.

## 2. Events ([02_event_names.sql](../sql/adhoc/02_event_names.sql))

- The full e-commerce funnel is tagged. By users: `view_item` 61k → `add_to_cart` 12.5k → `begin_checkout` 9.7k → `add_payment_info` 5.8k → `purchase` 4.4k. About 7% of product viewers buy.
- Purchases are rare: 5,692 `purchase` events in 92 days, about 62 a day. With Paid Search at about 2% of sessions, paid-search purchases will be only a few a day.
- `session_start` is about 3,860 a day, lower than the ~5,000 sessions a day counted earlier by session key. To check in section 4.
- About 95% of users have a `first_visit` in the period, so almost everyone is new (cookie-based IDs make returning users look new too).
- Tagging gap: `select_item` (click on a product in a list) has 31k events, but `view_item_list` (the list impression before it) has only 71.

**Decisions**

- Synthetic ad spend is sized to a few paid conversions a day, so CPA and ROAS stay realistic.
- Check `purchase` duplicates by `transaction_id` before counting orders (section 5).
- Count sessions by `user_pseudo_id` + `ga_session_id`, not by `session_start` events, once section 4 confirms the gap.
- Item-list metrics are left out of the models because `view_item_list` is barely tagged.

## 3. Event parameters ([03_event_params.sql](../sql/adhoc/03_event_params.sql), one week)

- `ga_session_id` (int) is on every event, so it is a reliable session key together with `user_pseudo_id`.
- `source`, `medium`, `campaign` (string) are on only about 34% of events and never on `session_start` or `first_visit`.
- Some keys mix value types: `value` and `tax` are split between int and double, and `session_engaged` between string and int. Reading one type silently drops rows.
- `gclid` exists on 7,463 events but every value is null (obfuscated), so ad clicks cannot be matched to sessions one by one.
- `clean_event = gtm.js`, `all_data` and `debug_mode` are custom keys set in GTM. `debug_mode` on most events would be a red flag in a real property (test traffic mixed in).
- `transaction_id` (string) is on `purchase` only.

**Decisions**

- Session traffic source = first non-null `source` / `medium` / `campaign` in the session, by `event_timestamp`.
- Staging reads mixed-type keys with `COALESCE` across value types.
- Ad spend joins GA4 at date × source / medium, not at click level.
- Custom GTM keys stay out of the models.

## 4. Session traffic sources ([04_session_sources.sql](../sql/adhoc/04_session_sources.sql))

- 360,129 sessions by `user_pseudo_id` + `ga_session_id` vs 354,970 `session_start` events: a 1.4% gap, about 3,900 sessions a day. The earlier "~5,000 a day" came from two peak days (11-30, 12-01).
- Self-referral: `shop.googlemerchandisestore.com / referral` is 14.6% of sessions, and holds the most sessions without `session_start` (2,447). Sessions restart when users move between the store's own subdomains. In a real property this is fixed with GA4 "unwanted referrals".
- No source information for about 35% of sessions: `(null)` 26%, `<Other>` 7% (obfuscated), `(data deleted)` 1.8%.
- `google / cpc` is 2.1% of sessions, about 83 a day.
- `googleads.g.doubleclick.net / referral` (122 sessions) is display ad clicks landing as referral.
- Facebook appears only as `l.facebook.com` / `m.facebook.com` referral (173 sessions), with no paid medium. Untagged Meta ads look like this.

**Decisions**

- Sessions are counted by session key. The `session_start` gap is small and noted, not fixed.
- Channel rules: `organic` → Organic Search, `google / cpc` → Paid Search, `referral` → Referral, `(direct) / (none)` → Direct, `email` → Email, `affiliate` → Affiliates, `(null)` / `<Other>` / `(data deleted)` → Unassigned.
- Self-referral handling (own channel or Direct) is decided in the session model.
- Synthetic Google Ads spend is sized to about 83 GA4 sessions a day. Meta clicks arrive in GA4 as facebook referral or Unassigned, matching what the real data shows.

## 5. Purchase quality ([05_purchase_quality.sql](../sql/adhoc/05_purchase_quality.sql))

- 906 of 5,692 `purchase` events (16%) have no transaction ID: 883 `(not set)` and 23 null. `(not set)` means the site did not pass the ID to the data layer, a tagging issue.
- Events with an ID: 4,786 events for 4,451 transactions. 326 transactions were recorded more than once.
- Revenue: $308,200 (with ID, deduplicated) + $31,817 (without ID) = $340,017. Summing raw events gives $362,165, which overstates revenue by 6.5%.
- Purchases without an ID average about $35, half of those with one (about $69). The ID seems to go missing on one checkout path. Recorded, not investigated.
- `ecommerce.purchase_revenue_in_usd` and the `value` param agree within 0.01%, and no purchase lacks revenue.

**Decisions**

- Orders = one row per transaction ID (first event kept), plus each purchase without an ID counted as its own order.
- Revenue comes from `ecommerce.purchase_revenue_in_usd`, which has no mixed types.
- Assertion: transaction IDs are unique in the orders model.

## 6. Revenue by channel ([06_channel_revenue.sql](../sql/adhoc/06_channel_revenue.sql))

A draft of the session model with the rules above. Orders match section 5 (5,357). Revenue is $339,457, $560 below section 5 because duplicated purchases sometimes carry different revenue: section 5 took the max, this query keeps the first event.

| Channel | Sessions | Share | Orders | Revenue | Rev share | Conv. rate |
|---|---:|---:|---:|---:|---:|---:|
| Unassigned | 126,325 | 35.1% | 357 | $21,266 | 6.3% | 0.28% |
| Organic Search | 103,039 | 28.6% | 1,840 | $109,005 | 32.1% | 1.79% |
| Self-referral | 56,492 | 15.7% | 1,606 | $109,676 | 32.3% | 2.84% |
| Direct | 37,786 | 10.5% | 337 | $22,643 | 6.7% | 0.89% |
| Referral | 27,289 | 7.6% | 1,144 | $71,927 | 21.2% | 4.19% |
| Paid Search | 7,672 | 2.1% | 48 | $3,114 | 0.9% | 0.63% |
| Affiliates | 1,329 | 0.4% | 2 | $167 | 0.0% | 0.15% |
| Email | 197 | 0.1% | 23 | $1,659 | 0.5% | 11.68% |

- Self-referral takes a third of revenue with a high conversion rate. Sessions break at checkout, so purchases are credited to the store itself instead of the real source. Reported as is, every real channel looks about a third worse.
- Paid Search converts at 0.63%, under half the average, for $3,114 in 92 days.
- Unassigned sessions are a third of traffic but convert poorly.

**Decisions**

- Self-referral sessions inherit the channel of the same user's previous session, or Direct if there is none (the same effect as GA4 unwanted referrals). An `is_self_referral` flag keeps the original so before and after can be compared.
- Duplicated purchases keep the first event's revenue.
- Synthetic ad data covers Google Ads only. GA4 has no paid social traffic, so Meta data would have nothing to join to.
