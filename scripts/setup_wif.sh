#!/usr/bin/env bash
# Let GitHub Actions in this repo run Dataform on BigQuery without a key file.
#
# GitHub signs a short-lived OIDC token saying "this job runs in <repo>". Workload Identity
# Federation checks that token and lets the job act as the dataform-ci service account.
# Only this repo is accepted. Safe to rerun: each step skips what already exists.
#
# Usage: scripts/setup_wif.sh   (prints the values to store as GitHub Actions variables)
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

REPO="ethanlee-dataworks/gcp-analytics-platform"
SA_NAME="dataform-ci"
POOL="github"
PROVIDER="github-oidc"

PROJECT="$GCP_PROJECT_ID"
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')"
SA_EMAIL="$SA_NAME@$PROJECT.iam.gserviceaccount.com"

gcloud services enable iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com \
  --project="$PROJECT"

# Service account for CI, with only what Dataform needs: write tables and run queries.
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$SA_NAME" --project="$PROJECT" \
    --display-name="Dataform CI (GitHub Actions)"
fi
for role in roles/bigquery.dataEditor roles/bigquery.jobUser; do
  gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$SA_EMAIL" \
    --role="$role" --condition=None --quiet >/dev/null
done

# Pool and provider that trust GitHub's OIDC tokens, limited to this repo.
if ! gcloud iam workload-identity-pools describe "$POOL" --project="$PROJECT" --location=global >/dev/null 2>&1; then
  gcloud iam workload-identity-pools create "$POOL" --project="$PROJECT" --location=global \
    --display-name="GitHub Actions"
fi
if ! gcloud iam workload-identity-pools providers describe "$PROVIDER" --project="$PROJECT" \
  --location=global --workload-identity-pool="$POOL" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" --project="$PROJECT" \
    --location=global --workload-identity-pool="$POOL" \
    --display-name="GitHub OIDC" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository == '$REPO'"
fi

# Jobs from this repo may act as the service account.
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" --project="$PROJECT" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL/attribute.repository/$REPO" \
  --quiet >/dev/null

echo "GitHub Actions variables:"
echo "  GCP_PROJECT_ID=$PROJECT"
echo "  WIF_PROVIDER=projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL/providers/$PROVIDER"
echo "  WIF_SERVICE_ACCOUNT=$SA_EMAIL"
