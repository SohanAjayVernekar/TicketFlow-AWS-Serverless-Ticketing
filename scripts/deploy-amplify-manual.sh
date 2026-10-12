#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$PROJECT_ROOT/frontend"
COGNITO_FILE="$PROJECT_ROOT/.cognito-resource-ids"
BACKEND_FILE="$PROJECT_ROOT/.backend-resource-ids"
ENV_FILE="$FRONTEND/.env.local"

APP_NAME="TicketFlowFrontend"
BRANCH_NAME="main"

for cmd in aws npm zip curl python3; do
  command -v "$cmd" >/dev/null || { echo "ERROR: $cmd is required."; exit 1; }
done

aws sts get-caller-identity >/dev/null 2>&1 || {
  echo "ERROR: AWS CLI credentials are not working."
  exit 1
}

[ -f "$COGNITO_FILE" ] || { echo "ERROR: $COGNITO_FILE not found."; exit 1; }
[ -f "$BACKEND_FILE" ] || { echo "ERROR: $BACKEND_FILE not found."; exit 1; }
[ -f "$ENV_FILE" ] || { echo "ERROR: $ENV_FILE not found."; exit 1; }

# shellcheck disable=SC1090
source "$COGNITO_FILE"
# shellcheck disable=SC1090
source "$BACKEND_FILE"

REGION="${AWS_REGION:-ap-south-1}"

echo "Region: $REGION"
echo "Amplify app: $APP_NAME"
echo

SPA_RULE='[{"source":"</^[^.]+$|\\.(?!(css|gif|ico|jpg|jpeg|js|png|txt|svg|woff|woff2|ttf|map|json|webp)$)([^.]+$)/>","target":"/index.html","status":"200"}]'

APP_ID="$(aws amplify list-apps \
  --region "$REGION" \
  --query "apps[?name=='$APP_NAME'].appId | [0]" \
  --output text)"

if [ "$APP_ID" = "None" ] || [ -z "$APP_ID" ]; then
  echo "Creating Amplify app..."
  APP_ID="$(aws amplify create-app \
    --region "$REGION" \
    --name "$APP_NAME" \
    --platform WEB \
    --custom-rules "$SPA_RULE" \
    --query 'app.appId' \
    --output text)"
else
  echo "Using existing Amplify app: $APP_ID"
  aws amplify update-app \
    --region "$REGION" \
    --app-id "$APP_ID" \
    --custom-rules "$SPA_RULE" \
    >/dev/null
fi

EXISTING_BRANCH="$(aws amplify list-branches \
  --region "$REGION" \
  --app-id "$APP_ID" \
  --query "branches[?branchName=='$BRANCH_NAME'].branchName | [0]" \
  --output text)"

if [ "$EXISTING_BRANCH" = "None" ] || [ -z "$EXISTING_BRANCH" ]; then
  echo "Creating Amplify branch..."
  aws amplify create-branch \
    --region "$REGION" \
    --app-id "$APP_ID" \
    --branch-name "$BRANCH_NAME" \
    --no-enable-auto-build \
    >/dev/null
fi

echo "Building Vue production frontend..."
cd "$FRONTEND"
npm ci
npm run build

DEPLOY_ZIP="$(mktemp --suffix=.zip)"
(
  cd "$FRONTEND/dist"
  zip -qr "$DEPLOY_ZIP" .
)

echo "Creating Amplify deployment..."
DEPLOY_JSON="$(aws amplify create-deployment \
  --region "$REGION" \
  --app-id "$APP_ID" \
  --branch-name "$BRANCH_NAME" \
  --output json)"

readarray -t DEPLOY_VALUES < <(python3 - "$DEPLOY_JSON" <<'PY'
import json, sys
obj = json.loads(sys.argv[1])
print(obj['jobId'])
print(obj['zipUploadUrl'])
PY
)

JOB_ID="${DEPLOY_VALUES[0]}"
UPLOAD_URL="${DEPLOY_VALUES[1]}"

curl --fail --silent --show-error \
  --request PUT \
  --upload-file "$DEPLOY_ZIP" \
  "$UPLOAD_URL" \
  >/dev/null
rm -f "$DEPLOY_ZIP"

aws amplify start-deployment \
  --region "$REGION" \
  --app-id "$APP_ID" \
  --branch-name "$BRANCH_NAME" \
  --job-id "$JOB_ID" \
  >/dev/null

echo "Deployment started: job $JOB_ID"

for attempt in $(seq 1 60); do
  STATUS="$(aws amplify get-job \
    --region "$REGION" \
    --app-id "$APP_ID" \
    --branch-name "$BRANCH_NAME" \
    --job-id "$JOB_ID" \
    --query 'job.summary.status' \
    --output text)"

  printf 'Deployment status: %s\n' "$STATUS"

  case "$STATUS" in
    SUCCEED)
      break
      ;;
    FAILED|CANCELLED)
      echo "ERROR: Amplify deployment ended with status $STATUS"
      exit 1
      ;;
  esac

  sleep 5
done

if [ "$STATUS" != "SUCCEED" ]; then
  echo "ERROR: Timed out waiting for Amplify deployment."
  exit 1
fi

DEFAULT_DOMAIN="$(aws amplify get-app \
  --region "$REGION" \
  --app-id "$APP_ID" \
  --query 'app.defaultDomain' \
  --output text)"

FRONTEND_ORIGIN="https://${BRANCH_NAME}.${DEFAULT_DOMAIN}"

echo
echo "Configuring Cognito, API Gateway, and S3 for the Amplify origin..."
chmod +x "$PROJECT_ROOT/scripts/configure-amplify-origin.sh"
"$PROJECT_ROOT/scripts/configure-amplify-origin.sh" "$FRONTEND_ORIGIN"

cat <<EOF

============================================================
TicketFlow is now hosted on AWS Amplify.
============================================================

Public frontend URL:
$FRONTEND_ORIGIN

Amplify App ID:
$APP_ID

You no longer need ngrok for the hosted frontend.

For future frontend changes, rerun:
  ./scripts/deploy-amplify-manual.sh
============================================================
EOF
