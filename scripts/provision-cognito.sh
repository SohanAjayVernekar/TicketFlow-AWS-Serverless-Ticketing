#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$PROJECT_ROOT/frontend"

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: AWS CLI is not installed."
  echo "Install AWS CLI v2 and run 'aws configure' first."
  exit 1
fi

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "ERROR: AWS CLI is not authenticated."
  echo "Run 'aws configure' (or configure your AWS credentials) first."
  exit 1
fi

REGION="${1:-${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}}"
REGION="${REGION:-ap-south-1}"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
SUFFIX="$(printf '%s-%s' "${ACCOUNT: -4}" "$(date +%s | tail -c 6)")"
DOMAIN_PREFIX="ticketflow-${SUFFIX}"
POOL_NAME="TicketFlowUsers"
CLIENT_NAME="TicketFlowWeb"

echo "Region: $REGION"
echo "Creating Cognito User Pool..."

POOL_ID="$(
  aws cognito-idp create-user-pool \
    --region "$REGION" \
    --pool-name "$POOL_NAME" \
    --username-attributes email \
    --auto-verified-attributes email \
    --query 'UserPool.Id' \
    --output text
)"

echo "User Pool: $POOL_ID"

echo "Creating hosted UI domain: $DOMAIN_PREFIX"
aws cognito-idp create-user-pool-domain \
  --region "$REGION" \
  --user-pool-id "$POOL_ID" \
  --domain "$DOMAIN_PREFIX" >/dev/null

echo "Creating app client..."
CLIENT_ID="$(
  aws cognito-idp create-user-pool-client \
    --region "$REGION" \
    --user-pool-id "$POOL_ID" \
    --client-name "$CLIENT_NAME" \
    --no-generate-secret \
    --supported-identity-providers COGNITO \
    --callback-urls "http://localhost:5173/auth/callback" \
    --logout-urls "http://localhost:5173/login" \
    --allowed-o-auth-flows code \
    --allowed-o-auth-scopes openid email profile \
    --allowed-o-auth-flows-user-pool-client \
    --query 'UserPoolClient.ClientId' \
    --output text
)"

echo "Creating groups..."
aws cognito-idp create-group --region "$REGION" --user-pool-id "$POOL_ID" --group-name Customers >/dev/null
aws cognito-idp create-group --region "$REGION" --user-pool-id "$POOL_ID" --group-name Agents >/dev/null

DOMAIN="https://${DOMAIN_PREFIX}.auth.${REGION}.amazoncognito.com"

cat > "$FRONTEND/.env.local" <<EOF
VITE_AWS_REGION=$REGION
VITE_COGNITO_USER_POOL_ID=$POOL_ID
VITE_COGNITO_CLIENT_ID=$CLIENT_ID
VITE_COGNITO_DOMAIN=$DOMAIN
EOF

cat > "$PROJECT_ROOT/.cognito-resource-ids" <<EOF
AWS_REGION=$REGION
COGNITO_USER_POOL_ID=$POOL_ID
COGNITO_CLIENT_ID=$CLIENT_ID
COGNITO_DOMAIN=$DOMAIN
EOF

echo
echo "Cognito created successfully."
echo
echo "User Pool ID: $POOL_ID"
echo "App Client ID: $CLIENT_ID"
echo "Hosted UI: $DOMAIN"
echo
echo "frontend/.env.local has been written automatically."
echo
echo "Next:"
echo "  1. cd \"$FRONTEND\""
echo "  2. npm run dev"
echo "  3. Open http://localhost:5173"
echo "  4. Sign up through Cognito Hosted UI."
echo
echo "New sign-ups are treated as Customers by the frontend."
echo "To make a user an Agent:"
echo "  $PROJECT_ROOT/scripts/promote-agent.sh user@example.com"
