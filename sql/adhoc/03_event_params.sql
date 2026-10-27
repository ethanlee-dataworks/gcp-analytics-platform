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
-- 3-3. Which keys live in event_params, which value type each uses, and on which events.
-- event_params is the heaviest column, so this reads one week (2020-12-01 to 12-07) only.
SELECT
  ep.key,
  COUNT(*) AS events_with_key,
  COUNTIF(ep.value.string_value IS NOT NULL) AS as_string,
  COUNTIF(ep.value.int_value IS NOT NULL) AS as_int,
  COUNTIF(ep.value.double_value IS NOT NULL OR ep.value.float_value IS NOT NULL) AS as_number,
  COUNT(DISTINCT event_name) AS n_event_names,
  STRING_AGG(DISTINCT event_name ORDER BY event_name) AS event_names,
  ANY_VALUE(COALESCE(ep.value.string_value, CAST(ep.value.int_value AS STRING))) AS example
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
  UNNEST(event_params) AS ep
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20201207'
GROUP BY ep.key
ORDER BY events_with_key DESC
