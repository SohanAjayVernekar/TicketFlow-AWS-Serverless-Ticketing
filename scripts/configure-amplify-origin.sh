#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COGNITO_FILE="$PROJECT_ROOT/.cognito-resource-ids"
BACKEND_FILE="$PROJECT_ROOT/.backend-resource-ids"

if [ $# -ne 1 ]; then
  echo "Usage: $0 https://main.YOUR_APP_ID.amplifyapp.com"
  exit 1
fi

ORIGIN="${1%/}"

case "$ORIGIN" in
  https://*) ;;
  *) echo "ERROR: frontend origin must start with https://"; exit 1 ;;
esac

command -v aws >/dev/null || { echo "ERROR: AWS CLI is not installed."; exit 1; }
aws sts get-caller-identity >/dev/null 2>&1 || { echo "ERROR: AWS CLI credentials are not working."; exit 1; }
[ -f "$COGNITO_FILE" ] || { echo "ERROR: $COGNITO_FILE not found."; exit 1; }
[ -f "$BACKEND_FILE" ] || { echo "ERROR: $BACKEND_FILE not found."; exit 1; }

# shellcheck disable=SC1090
source "$COGNITO_FILE"
# shellcheck disable=SC1090
source "$BACKEND_FILE"

REGION="${AWS_REGION:-ap-south-1}"
API_ID="${HTTP_API_ID}"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${ATTACHMENTS_BUCKET:-ticketflow-${ACCOUNT}-${REGION}-attachments}"

CALLBACK_LOCAL="http://localhost:5173/auth/callback"
LOGOUT_LOCAL="http://localhost:5173/login"
CALLBACK_AWS="$ORIGIN/auth/callback"
LOGOUT_AWS="$ORIGIN/login"

printf '\n[1/3] Updating Cognito callback/sign-out URLs...\n'
aws cognito-idp update-user-pool-client \
  --region "$REGION" \
  --user-pool-id "$COGNITO_USER_POOL_ID" \
  --client-id "$COGNITO_CLIENT_ID" \
  --callback-urls "$CALLBACK_LOCAL" "$CALLBACK_AWS" \
  --logout-urls "$LOGOUT_LOCAL" "$LOGOUT_AWS" \
  >/dev/null

printf '[2/3] Updating API Gateway CORS...\n'
API_CORS="$(mktemp)"
cat > "$API_CORS" <<EOF
{
  "AllowOrigins": [
    "http://localhost:5173",
    "$ORIGIN"
  ],
  "AllowMethods": ["GET", "POST", "PUT", "OPTIONS"],
  "AllowHeaders": ["authorization", "content-type"]
}
EOF
aws apigatewayv2 update-api \
  --region "$REGION" \
  --api-id "$API_ID" \
  --cors-configuration "file://$API_CORS" \
  >/dev/null
rm -f "$API_CORS"

printf '[3/3] Updating S3 attachment CORS...\n'
S3_CORS="$(mktemp)"
cat > "$S3_CORS" <<EOF
{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "PUT", "HEAD"],
      "AllowedOrigins": [
        "http://localhost:5173",
        "$ORIGIN"
      ],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF
aws s3api put-bucket-cors \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --cors-configuration "file://$S3_CORS" \
  >/dev/null
rm -f "$S3_CORS"

cat <<EOF

TicketFlow AWS hosting origin configured successfully.

Frontend:       $ORIGIN
Cognito login:  $CALLBACK_AWS
Cognito logout: $LOGOUT_AWS
API Gateway:    $API_ID
S3 bucket:      $BUCKET

You can keep localhost for development; ngrok is no longer required for the hosted app.
EOF
