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
-- 5. Period totals from the ads mart: what Google Ads claims vs what GA4 sees.
-- Ratios are computed from the sums, never by averaging daily ratios.
SELECT
  COUNT(*) AS days,
  SUM(clicks) AS clicks,
  SUM(ga4_sessions) AS ga4_sessions,
  ROUND(SUM(cost_usd), 2) AS cost_usd,
  ROUND(SUM(platform_conversions), 1) AS platform_conversions,
  SUM(ga4_orders) AS ga4_orders,
  ROUND(SUM(platform_conversion_value_usd), 2) AS platform_revenue_usd,
  ROUND(SUM(ga4_revenue_usd), 2) AS ga4_revenue_usd,
  ROUND(SUM(platform_conversion_value_usd) / SUM(cost_usd), 2) AS platform_roas,
  ROUND(SUM(ga4_revenue_usd) / SUM(cost_usd), 2) AS ga4_roas,
  ROUND(SUM(ga4_revenue_usd_before_correction) / SUM(cost_usd), 2) AS ga4_roas_before_correction,
  ROUND(SUM(cost_usd) / SUM(platform_conversions), 2) AS platform_cpa,
  ROUND(SUM(cost_usd) / SUM(ga4_orders), 2) AS ga4_cpa
FROM `gcp-analytics-platform.marts.daily_google_ads_vs_ga4`
