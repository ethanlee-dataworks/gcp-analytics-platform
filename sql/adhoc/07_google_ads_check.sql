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
-- 4. Check the loaded synthetic Google Ads report: totals per campaign over the period.
SELECT
  campaign_name,
  COUNT(DISTINCT date) AS days,
  SUM(clicks) AS clicks,
  SUM(cost) AS cost,
  ROUND(SUM(conversions), 1) AS conversions,
  SUM(conversion_value) AS conversion_value,
  ROUND(SUM(cost) / SUM(clicks), 2) AS cpc,
  ROUND(SUM(conversion_value) / SUM(cost), 2) AS platform_roas
FROM `gcp-analytics-platform.raw_google_ads.campaign_daily`
GROUP BY campaign_name
ORDER BY cost DESC
