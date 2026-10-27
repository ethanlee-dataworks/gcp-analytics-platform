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
-- 3-4. Session traffic sources over all 92 days, and how session counts compare to session_start events.
-- A session is user_pseudo_id + ga_session_id. Its source / medium is the first non-null value in the session.
WITH events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    event_name,
    event_timestamp,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source') AS source,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium') AS medium
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
sessions AS (
  SELECT
    user_pseudo_id,
    ga_session_id,
    COUNTIF(event_name = 'session_start') AS session_starts,
    ARRAY_AGG(source IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS source,
    ARRAY_AGG(medium IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS medium
  FROM events
  GROUP BY user_pseudo_id, ga_session_id
)
SELECT
  IFNULL(source, '(null)') AS source,
  IFNULL(medium, '(null)') AS medium,
  COUNT(*) AS sessions,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_sessions,
  COUNTIF(session_starts = 0) AS sessions_without_start,
  SUM(COUNT(*)) OVER () AS total_sessions,
  SUM(SUM(session_starts)) OVER () AS total_session_start_events
FROM sessions
GROUP BY source, medium
ORDER BY sessions DESC
LIMIT 30
