/* @datacloud.settings
{
  "version": 1,
  "service": "BIG_QUERY",
  "connectionInfo": {
    "billingProjectId": "INHERIT"
  },
  "dialect": "GOOGLE_SQL"
}
*/
-- 3-5b. Sessions, orders and revenue by channel over all 92 days, using the rules from sections 4 and 5.
-- This is a draft of the session model: if the numbers look right here, they move into Dataform.
WITH events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    event_name,
    event_timestamp,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source') AS source,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium') AS medium,
    ecommerce.transaction_id AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS revenue_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
-- Section 5: keep the first event per transaction ID, keep every purchase without an ID.
orders AS (
  SELECT user_pseudo_id, ga_session_id, revenue_usd
  FROM events
  WHERE event_name = 'purchase'
  QUALIFY transaction_id IS NULL
    OR transaction_id = '(not set)'
    OR ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY event_timestamp) = 1
),
session_orders AS (
  SELECT user_pseudo_id, ga_session_id, COUNT(*) AS orders, SUM(revenue_usd) AS revenue_usd
  FROM orders
  GROUP BY user_pseudo_id, ga_session_id
),
sessions AS (
  SELECT
    user_pseudo_id,
    ga_session_id,
    ARRAY_AGG(source IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS source,
    ARRAY_AGG(medium IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS medium
  FROM events
  GROUP BY user_pseudo_id, ga_session_id
),
-- Section 4: channel rules. Self-referral stays visible as its own channel for now.
sessions_with_channel AS (
  SELECT
    s.*,
    CASE
      WHEN s.medium = 'organic' THEN 'Organic Search'
      WHEN s.medium = 'cpc' THEN 'Paid Search'
      WHEN s.medium = 'referral'
        AND s.source IN ('shop.googlemerchandisestore.com', 'googlemerchandisestore.com') THEN 'Self-referral'
      WHEN s.medium = 'referral' THEN 'Referral'
      WHEN s.source = '(direct)' AND s.medium = '(none)' THEN 'Direct'
      WHEN s.medium = 'email' THEN 'Email'
      WHEN s.medium = 'affiliate' THEN 'Affiliates'
      ELSE 'Unassigned'
    END AS channel,
    IFNULL(o.orders, 0) AS orders,
    IFNULL(o.revenue_usd, 0) AS revenue_usd
  FROM sessions AS s
  LEFT JOIN session_orders AS o USING (user_pseudo_id, ga_session_id)
)
SELECT
  channel,
  COUNT(*) AS sessions,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_sessions,
  SUM(orders) AS orders,
  ROUND(SUM(revenue_usd)) AS revenue_usd,
  ROUND(100 * SUM(revenue_usd) / SUM(SUM(revenue_usd)) OVER (), 1) AS pct_revenue,
  ROUND(100 * SUM(orders) / COUNT(*), 2) AS conversion_rate_pct,
  ROUND(SUM(revenue_usd) / NULLIF(SUM(orders), 0), 1) AS avg_order_value,
  ROUND(SUM(revenue_usd) / 92) AS revenue_per_day
FROM sessions_with_channel
GROUP BY channel
ORDER BY sessions DESC
