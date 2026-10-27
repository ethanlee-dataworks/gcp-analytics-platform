#!/usr/bin/env bash
# Connect this GitHub repo to a GCP Dataform repository, so the code can be browsed,
# edited and committed from the Dataform console, and runs started there.
#
# GitHub stays the source of truth: console edits are pushed to GitHub as commits.
# Scheduled runs stay in GitHub Actions; no schedule is set up here, so nothing runs twice.
#
# Prerequisite: the secret dataform-github-token holds a fine-grained GitHub token
# (this repo only, Contents read and write). Safe to rerun.
#
# Usage: scripts/setup_dataform_repo.sh
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

REPO_URL="https://github.com/ethanlee-dataworks/gcp-analytics-platform.git"
REPO_ID="gcp-analytics-platform"
SECRET="dataform-github-token"

PROJECT="$GCP_PROJECT_ID"
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')"
SERVICE_AGENT="service-$PROJECT_NUMBER@gcp-sa-dataform.iam.gserviceaccount.com"
RUNNER_SA="dataform-ci@$PROJECT.iam.gserviceaccount.com"
API="https://dataform.googleapis.com/v1/projects/$PROJECT/locations/$GCP_REGION/repositories"

TOKEN="$(gcloud auth print-access-token)"

# Make sure the Dataform service agent exists (it is created lazily).
# Same as `gcloud beta services identity create`, without needing the beta component.
curl -sf -X POST -H "Authorization: Bearer $TOKEN" \
  "https://serviceusage.googleapis.com/v1beta1/projects/$PROJECT_NUMBER/services/dataform.googleapis.com:generateServiceIdentity" \
  >/dev/null

# The service agent reads the GitHub token...
gcloud secrets add-iam-policy-binding "$SECRET" --project="$PROJECT" \
  --member="serviceAccount:$SERVICE_AGENT" --role="roles/secretmanager.secretAccessor" --quiet >/dev/null

# ...and runs workflows as dataform-ci, the same identity GitHub Actions uses.
gcloud iam service-accounts add-iam-policy-binding "$RUNNER_SA" --project="$PROJECT" \
  --member="serviceAccount:$SERVICE_AGENT" --role="roles/iam.serviceAccountTokenCreator" --quiet >/dev/null

if curl -sf -H "Authorization: Bearer $TOKEN" "$API/$REPO_ID" >/dev/null; then
  echo "Dataform repository $REPO_ID already exists"
else
  curl -sf -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    "$API?repositoryId=$REPO_ID" \
    -d @- <<EOF
{
  "gitRemoteSettings": {
    "url": "$REPO_URL",
    "defaultBranch": "main",
    "authenticationTokenSecretVersion": "projects/$PROJECT/secrets/$SECRET/versions/latest"
  },
  "serviceAccount": "$RUNNER_SA"
}
EOF
  echo
fi

echo "Console: https://console.cloud.google.com/bigquery/dataform/locations/$GCP_REGION/repositories/$REPO_ID?project=$PROJECT"
