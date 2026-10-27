"""Generate a synthetic Google Ads daily campaign report for the GA4 sample period.

The GA4 sample has no ad spend, so this stands in for what Supermetrics would load
from the Google Ads API: one row per day x campaign. Traffic shape comes from the GA4
sample (docs/exploration.md); CPC, CTR and conversion rates are assumptions.

Usage: python scripts/gen_ad_spend.py  ->  data/google_ads_campaign_daily.csv
"""

import csv
import random
from datetime import date, timedelta
from pathlib import Path

START = date(2020, 11, 1)
END = date(2021, 1, 31)
OUTPUT = Path(__file__).resolve().parent.parent / "data" / "google_ads_campaign_daily.csv"

# Weekday clicks across all campaigns, before the daily multipliers.
# Tuned so the period averages a little above the ~83 google / cpc sessions a day in GA4.
BASE_WEEKDAY_CLICKS = 105
AVG_ORDER_VALUE = 70.0
NOISE = 0.2
SEED = 42

# Assumptions: share of clicks, cost per click, click-through rate, platform-reported
# conversions per click. Platform conversions are set to about 2.5x what GA4 sees.
CAMPAIGNS = [
    {"id": 1001, "name": "Search - Brand", "click_share": 0.40, "cpc": 0.25, "ctr": 0.08, "conv_rate": 0.022},
    {"id": 1002, "name": "Search - Apparel", "click_share": 0.35, "cpc": 0.55, "ctr": 0.03, "conv_rate": 0.010},
    {"id": 1003, "name": "Shopping - All Products", "click_share": 0.25, "cpc": 0.40, "ctr": 0.015, "conv_rate": 0.010},
]


def day_multiplier(d: date) -> float:
    """Traffic shape seen in GA4: weekend dip, pre-Christmas peak, holiday drop."""
    m = 0.6 if d.weekday() >= 5 else 1.0
    if date(2020, 11, 30) <= d <= date(2020, 12, 11):
        m *= 1.5
    elif date(2020, 12, 19) <= d <= date(2021, 1, 3):
        m *= 0.5
    return m


def jitter(rng: random.Random) -> float:
    return rng.uniform(1 - NOISE, 1 + NOISE)


def generate() -> list[dict]:
    rng = random.Random(SEED)
    rows = []
    d = START
    while d <= END:
        day_clicks = BASE_WEEKDAY_CLICKS * day_multiplier(d)
        for c in CAMPAIGNS:
            clicks = round(day_clicks * c["click_share"] * jitter(rng))
            conversions = clicks * c["conv_rate"] * jitter(rng)
            rows.append({
                "date": d.isoformat(),
                "campaign_id": c["id"],
                "campaign_name": c["name"],
                "impressions": round(clicks / c["ctr"] * jitter(rng)),
                "clicks": clicks,
                "cost": round(clicks * c["cpc"] * jitter(rng), 2),
                "conversions": round(conversions, 2),
                "conversion_value": round(conversions * AVG_ORDER_VALUE * jitter(rng), 2),
                "currency": "USD",
            })
        d += timedelta(days=1)
    return rows


def main() -> None:
    rows = generate()
    OUTPUT.parent.mkdir(exist_ok=True)
    with OUTPUT.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    clicks = sum(r["clicks"] for r in rows)
    cost = sum(r["cost"] for r in rows)
    conversions = sum(r["conversions"] for r in rows)
    value = sum(r["conversion_value"] for r in rows)
    print(f"{len(rows)} rows -> {OUTPUT}")
    print(f"clicks {clicks} ({clicks / 92:.0f}/day), cost ${cost:,.0f}, "
          f"conversions {conversions:.0f}, value ${value:,.0f}, platform ROAS {value / cost:.2f}")


if __name__ == "__main__":
    main()
