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
-- 3-5a. Can purchase events be trusted as orders? Duplicates, missing IDs, and two revenue fields compared.
-- Revenue: the ecommerce struct (purchase_revenue_in_usd) vs the 'value' event param (int or double).
WITH purchases AS (
  SELECT
    ecommerce.transaction_id AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS revenue_usd,
    (SELECT COALESCE(value.double_value, value.float_value, value.int_value)
     FROM UNNEST(event_params) WHERE key = 'value') AS param_value
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
-- Events without an ID cannot be deduplicated, so they are kept apart and counted one by one.
with_id AS (
  SELECT * FROM purchases
  WHERE transaction_id IS NOT NULL AND transaction_id != '(not set)'
),
by_transaction AS (
  SELECT transaction_id, COUNT(*) AS events, MAX(revenue_usd) AS revenue_usd
  FROM with_id
  GROUP BY transaction_id
)
SELECT
  (SELECT COUNT(*) FROM purchases) AS purchase_events,
  (SELECT COUNTIF(transaction_id IS NULL) FROM purchases) AS events_id_null,
  (SELECT COUNTIF(transaction_id = '(not set)') FROM purchases) AS events_id_not_set,
  (SELECT COUNT(*) FROM by_transaction) AS distinct_transactions,
  (SELECT COUNTIF(events > 1) FROM by_transaction) AS transactions_with_duplicates,
  (SELECT ROUND(SUM(revenue_usd), 2) FROM purchases) AS revenue_all_events,
  (SELECT ROUND(SUM(revenue_usd), 2) FROM by_transaction) AS revenue_with_id_deduplicated,
  (SELECT ROUND(SUM(revenue_usd), 2) FROM purchases
   WHERE transaction_id IS NULL OR transaction_id = '(not set)') AS revenue_without_id,
  (SELECT ROUND(SUM(param_value), 2) FROM purchases) AS param_value_all_events
