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
-- 5. Channel before and after the self-referral correction, from int_sessions.
-- Totals must match 06_channel_revenue.sql: 5,357 orders, $339,457 revenue.
WITH before AS (
  SELECT original_channel AS channel, COUNT(*) AS sessions, SUM(orders) AS orders, SUM(revenue_usd) AS revenue_usd
  FROM `gcp-analytics-platform.intermediate.int_sessions`
  GROUP BY 1
),
after AS (
  SELECT channel, COUNT(*) AS sessions, SUM(orders) AS orders, SUM(revenue_usd) AS revenue_usd
  FROM `gcp-analytics-platform.intermediate.int_sessions`
  GROUP BY 1
)
SELECT
  channel,
  b.sessions AS sessions_before,
  a.sessions AS sessions_after,
  b.orders AS orders_before,
  a.orders AS orders_after,
  ROUND(b.revenue_usd) AS revenue_before,
  ROUND(a.revenue_usd) AS revenue_after,
  ROUND(100 * a.revenue_usd / SUM(a.revenue_usd) OVER (), 1) AS pct_revenue_after
FROM before AS b
FULL OUTER JOIN after AS a USING (channel)
ORDER BY revenue_after DESC
