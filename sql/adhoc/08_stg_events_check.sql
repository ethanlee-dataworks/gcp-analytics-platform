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
-- 5. Check stg_ga4_events against the source: nothing lost, keys filled, purchase IDs as in section 5.
SELECT
  (SELECT COUNT(*) FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`) AS source_rows,
  (SELECT COUNT(*) FROM `gcp-analytics-platform.ga4_staging.stg_ga4_events`) AS stg_rows,
  (SELECT COUNT(DISTINCT event_date) FROM `gcp-analytics-platform.ga4_staging.stg_ga4_events`) AS days,
  (SELECT COUNTIF(session_key IS NULL) FROM `gcp-analytics-platform.ga4_staging.stg_ga4_events`) AS events_without_session_key,
  (SELECT COUNTIF(transaction_id IS NOT NULL)
   FROM `gcp-analytics-platform.ga4_staging.stg_ga4_events`
   WHERE event_name = 'purchase') AS purchases_with_id
