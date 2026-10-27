#!/usr/bin/env bash
# Load the synthetic Google Ads report into BigQuery, the way a connector would land it.
# Full reload: rerunning replaces the table, so the result is always the same.
#
# Usage: python scripts/gen_ad_spend.py && scripts/load_ad_spend.sh
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

DATASET="raw_google_ads"
TABLE="campaign_daily"
CSV="data/google_ads_campaign_daily.csv"
SCHEMA="date:DATE,campaign_id:INT64,campaign_name:STRING,impressions:INT64,clicks:INT64,cost:NUMERIC,conversions:FLOAT64,conversion_value:NUMERIC,currency:STRING"

# Create the dataset once, in the same location as the GA4 sample so they can be joined.
if ! bq show --project_id="$GCP_PROJECT_ID" "$DATASET" >/dev/null 2>&1; then
  bq mk --project_id="$GCP_PROJECT_ID" --location="$BQ_LOCATION" \
    --description="Synthetic Google Ads campaign report (stands in for a Supermetrics load)" \
    --dataset "$DATASET"
fi

bq load --project_id="$GCP_PROJECT_ID" --location="$BQ_LOCATION" \
  --replace \
  --source_format=CSV --skip_leading_rows=1 \
  --time_partitioning_field=date --time_partitioning_type=DAY \
  "$DATASET.$TABLE" "$CSV" "$SCHEMA"

bq show --project_id="$GCP_PROJECT_ID" --format=prettyjson "$DATASET.$TABLE" \
  | grep -E '"numRows"|"type": "DAY"'
