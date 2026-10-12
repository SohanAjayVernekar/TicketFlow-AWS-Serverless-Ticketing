#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCE_FILE="$PROJECT_ROOT/.cognito-resource-ids"

if [ $# -lt 1 ]; then
  echo "Usage: $0 user@example.com"
  exit 1
fi

if [ ! -f "$RESOURCE_FILE" ]; then
  echo "ERROR: $RESOURCE_FILE not found."
  echo "Run scripts/provision-cognito.sh first."
  exit 1
fi

# shellcheck disable=SC1090
source "$RESOURCE_FILE"

EMAIL="$1"

USERNAME="$(
  aws cognito-idp list-users \
    --region "$AWS_REGION" \
    --user-pool-id "$COGNITO_USER_POOL_ID" \
    --filter "email = \"$EMAIL\"" \
    --query 'Users[0].Username' \
    --output text
)"

if [ -z "$USERNAME" ] || [ "$USERNAME" = "None" ]; then
  echo "No Cognito user found with email: $EMAIL"
  echo "Have the user sign up first."
  exit 1
fi

aws cognito-idp admin-add-user-to-group \
  --region "$AWS_REGION" \
  --user-pool-id "$COGNITO_USER_POOL_ID" \
  --username "$USERNAME" \
  --group-name Agents

echo "Added $EMAIL to Agents."
echo "Sign out and sign back in so the new cognito:groups claim is included in the token."
