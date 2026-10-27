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
-- 3-1. Daily tables in the GA4 sample: rows and size per day, plus totals.
-- __TABLES__ is table metadata, so this reads no event data and costs nothing.
SELECT
  table_id,
  row_count,
  ROUND(size_bytes / POW(1024, 2), 1) AS size_mb,
  COUNT(*) OVER () AS total_tables,
  SUM(row_count) OVER () AS total_rows,
  ROUND(SUM(size_bytes) OVER () / POW(1024, 3), 2) AS total_gb
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.__TABLES__`
ORDER BY table_id
