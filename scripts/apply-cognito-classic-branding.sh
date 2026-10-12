#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCE_FILE="$PROJECT_ROOT/.cognito-resource-ids"
CSS_FILE="$PROJECT_ROOT/patch/cognito-classic.css"

if [ ! -f "$RESOURCE_FILE" ]; then
  echo "ERROR: $RESOURCE_FILE not found."
  echo "Run the Cognito provisioning script first."
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: AWS CLI is not installed."
  exit 1
fi

# shellcheck disable=SC1090
source "$RESOURCE_FILE"

echo "Applying TicketFlow styling to Cognito Hosted UI (classic)..."

aws cognito-idp set-ui-customization \
  --region "$AWS_REGION" \
  --user-pool-id "$COGNITO_USER_POOL_ID" \
  --client-id "$COGNITO_CLIENT_ID" \
  --css "file://$CSS_FILE" >/dev/null

echo
echo "Cognito classic Hosted UI branding applied."
echo "AWS notes that changes can take about a minute to appear."
echo "Refresh the sign-in/sign-up page after a short wait."
