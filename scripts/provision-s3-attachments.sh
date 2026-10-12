#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_FILE="$PROJECT_ROOT/.backend-resource-ids"

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: AWS CLI is not installed."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm is not installed."
  exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "ERROR: zip is not installed."
  echo "Run: sudo apt install -y zip"
  exit 1
fi

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "ERROR: AWS CLI credentials are not working."
  exit 1
fi

if [ ! -f "$BACKEND_FILE" ]; then
  echo "ERROR: $BACKEND_FILE not found."
  echo "Run the backend provisioning stage first."
  exit 1
fi

# shellcheck disable=SC1090
source "$BACKEND_FILE"

REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"

TICKETS_TABLE="${TICKETS_TABLE:-TicketFlowTickets}"
COMMENTS_TABLE="${COMMENTS_TABLE:-TicketFlowComments}"
FUNCTION_NAME="${LAMBDA_FUNCTION:-TicketFlowApi}"
API_ID="${HTTP_API_ID}"
ROLE_NAME="TicketFlowLambdaRole"

BUCKET="ticketflow-${ACCOUNT}-${REGION}-attachments"

echo "Region: $REGION"
echo "Creating/updating private S3 attachment bucket..."

if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "S3 bucket exists: $BUCKET"
else
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket \
      --region "$REGION" \
      --bucket "$BUCKET" >/dev/null
  else
    aws s3api create-bucket \
      --region "$REGION" \
      --bucket "$BUCKET" \
      --create-bucket-configuration "LocationConstraint=$REGION" >/dev/null
  fi
  echo "Created: $BUCKET"
fi

aws s3api put-public-access-block \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  >/dev/null

CORS_FILE="$(mktemp)"
cat > "$CORS_FILE" <<'EOF'
{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "PUT", "HEAD"],
      "AllowedOrigins": ["http://localhost:5173"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF

aws s3api put-bucket-cors \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --cors-configuration "file://$CORS_FILE" >/dev/null
rm -f "$CORS_FILE"

echo "Updating Lambda IAM permissions..."

POLICY_FILE="$(mktemp)"
cat > "$POLICY_FILE" <<EOF
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Effect":"Allow",
      "Action":[
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource":[
        "arn:aws:dynamodb:${REGION}:${ACCOUNT}:table/${TICKETS_TABLE}",
        "arn:aws:dynamodb:${REGION}:${ACCOUNT}:table/${TICKETS_TABLE}/index/*",
        "arn:aws:dynamodb:${REGION}:${ACCOUNT}:table/${COMMENTS_TABLE}"
      ]
    },
    {
      "Effect":"Allow",
      "Action":[
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource":"arn:aws:s3:::${BUCKET}/attachments/*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name TicketFlowDynamoAccess \
  --policy-document "file://$POLICY_FILE" >/dev/null
rm -f "$POLICY_FILE"

echo "Building updated Lambda package..."

BUILD_DIR="$PROJECT_ROOT/backend/.build-s3"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cp "$PROJECT_ROOT/backend/lambda/index.js" "$BUILD_DIR/index.js"

pushd "$BUILD_DIR" >/dev/null
cat > package.json <<'EOF'
{
  "name":"ticketflow-lambda",
  "version":"1.0.0",
  "private":true,
  "dependencies":{
    "@aws-sdk/client-dynamodb":"^3.0.0",
    "@aws-sdk/lib-dynamodb":"^3.0.0",
    "@aws-sdk/client-s3":"^3.0.0",
    "@aws-sdk/s3-request-presigner":"^3.0.0"
  }
}
EOF

npm install --omit=dev --silent
zip -qr function.zip index.js package.json node_modules
popd >/dev/null

echo "Updating Lambda function code..."

aws lambda update-function-code \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --zip-file "fileb://$BUILD_DIR/function.zip" >/dev/null

aws lambda wait function-updated \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME"

aws lambda update-function-configuration \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --timeout 10 \
  --memory-size 256 \
  --environment "Variables={TICKETS_TABLE=$TICKETS_TABLE,COMMENTS_TABLE=$COMMENTS_TABLE,ATTACHMENTS_BUCKET=$BUCKET}" \
  >/dev/null

aws lambda wait function-updated \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME"

echo "Ensuring API route exists..."

INTEGRATION_ID="$(
  aws apigatewayv2 get-integrations \
    --region "$REGION" \
    --api-id "$API_ID" \
    --query 'Items[0].IntegrationId' \
    --output text
)"

AUTHORIZER_ID="$(
  aws apigatewayv2 get-authorizers \
    --region "$REGION" \
    --api-id "$API_ID" \
    --query "Items[?Name=='TicketFlowCognitoJwt'].AuthorizerId | [0]" \
    --output text
)"

EXISTING_ROUTE="$(
  aws apigatewayv2 get-routes \
    --region "$REGION" \
    --api-id "$API_ID" \
    --query "Items[?RouteKey=='POST /tickets/presigned-url'].RouteId | [0]" \
    --output text
)"

if [ "$EXISTING_ROUTE" = "None" ] || [ -z "$EXISTING_ROUTE" ]; then
  aws apigatewayv2 create-route \
    --region "$REGION" \
    --api-id "$API_ID" \
    --route-key 'POST /tickets/presigned-url' \
    --target "integrations/$INTEGRATION_ID" \
    --authorization-type JWT \
    --authorizer-id "$AUTHORIZER_ID" >/dev/null

  echo "Created: POST /tickets/presigned-url"
else
  echo "Route already exists: POST /tickets/presigned-url"
fi

if grep -q '^ATTACHMENTS_BUCKET=' "$BACKEND_FILE"; then
  sed -i "s|^ATTACHMENTS_BUCKET=.*|ATTACHMENTS_BUCKET=$BUCKET|" "$BACKEND_FILE"
else
  printf '\nATTACHMENTS_BUCKET=%s\n' "$BUCKET" >> "$BACKEND_FILE"
fi

echo
echo "S3 attachment backend provisioned successfully."
echo
echo "Bucket: $BUCKET"
echo "Public access: BLOCKED"
echo "Upload endpoint: POST /tickets/presigned-url"
echo "Maximum UI upload size: 10 MB"
echo
echo "Restart Vite after applying the frontend patch."
