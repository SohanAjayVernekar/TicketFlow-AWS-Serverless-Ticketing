#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$PROJECT_ROOT/frontend"
COGNITO_FILE="$PROJECT_ROOT/.cognito-resource-ids"

command -v aws >/dev/null || { echo "ERROR: AWS CLI is not installed."; exit 1; }
command -v zip >/dev/null || { echo "ERROR: zip is not installed. Run: sudo apt install -y zip"; exit 1; }
command -v npm >/dev/null || { echo "ERROR: npm is not installed."; exit 1; }
aws sts get-caller-identity >/dev/null 2>&1 || { echo "ERROR: AWS CLI credentials are not working."; exit 1; }
[ -f "$COGNITO_FILE" ] || { echo "ERROR: $COGNITO_FILE not found. Run Cognito provisioning first."; exit 1; }
# shellcheck disable=SC1090
source "$COGNITO_FILE"

REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
TICKETS_TABLE="TicketFlowTickets"
COMMENTS_TABLE="TicketFlowComments"
ROLE_NAME="TicketFlowLambdaRole"
FUNCTION_NAME="TicketFlowApi"
API_NAME="TicketFlowHttpApi"

echo "Region: $REGION"
echo "Creating DynamoDB resources..."

if ! aws dynamodb describe-table --region "$REGION" --table-name "$TICKETS_TABLE" >/dev/null 2>&1; then
  aws dynamodb create-table --region "$REGION" --table-name "$TICKETS_TABLE" \
    --attribute-definitions AttributeName=ticketId,AttributeType=S AttributeName=customerId,AttributeType=S AttributeName=createdAt,AttributeType=S \
    --key-schema AttributeName=ticketId,KeyType=HASH \
    --global-secondary-indexes '[{"IndexName":"customerId-createdAt-index","KeySchema":[{"AttributeName":"customerId","KeyType":"HASH"},{"AttributeName":"createdAt","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"},"ProvisionedThroughput":{"ReadCapacityUnits":1,"WriteCapacityUnits":1}}]' \
    --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 >/dev/null
  aws dynamodb wait table-exists --region "$REGION" --table-name "$TICKETS_TABLE"
fi

if ! aws dynamodb describe-table --region "$REGION" --table-name "$COMMENTS_TABLE" >/dev/null 2>&1; then
  aws dynamodb create-table --region "$REGION" --table-name "$COMMENTS_TABLE" \
    --attribute-definitions AttributeName=ticketId,AttributeType=S AttributeName=commentId,AttributeType=S \
    --key-schema AttributeName=ticketId,KeyType=HASH AttributeName=commentId,KeyType=RANGE \
    --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 >/dev/null
  aws dynamodb wait table-exists --region "$REGION" --table-name "$COMMENTS_TABLE"
fi

TRUST="$(mktemp)"
cat > "$TRUST" <<'JSON'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}
JSON
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document "file://$TRUST" >/dev/null
fi
rm -f "$TRUST"
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole >/dev/null

POLICY="$(mktemp)"
cat > "$POLICY" <<JSON
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["dynamodb:GetItem","dynamodb:PutItem","dynamodb:UpdateItem","dynamodb:Query","dynamodb:Scan"],"Resource":["arn:aws:dynamodb:${REGION}:${ACCOUNT}:table/${TICKETS_TABLE}","arn:aws:dynamodb:${REGION}:${ACCOUNT}:table/${TICKETS_TABLE}/index/*","arn:aws:dynamodb:${REGION}:${ACCOUNT}:table/${COMMENTS_TABLE}"]}]}
JSON
aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name TicketFlowDynamoAccess --policy-document "file://$POLICY" >/dev/null
rm -f "$POLICY"
ROLE_ARN="$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)"

BUILD="$PROJECT_ROOT/backend/.build"
rm -rf "$BUILD" && mkdir -p "$BUILD"
cp "$PROJECT_ROOT/backend/lambda/index.js" "$BUILD/index.js"
pushd "$BUILD" >/dev/null
cat > package.json <<'JSON'
{"name":"ticketflow-lambda","version":"1.0.0","private":true,"dependencies":{"@aws-sdk/client-dynamodb":"^3.0.0","@aws-sdk/lib-dynamodb":"^3.0.0"}}
JSON
npm install --omit=dev --silent
zip -qr function.zip index.js package.json node_modules
popd >/dev/null

if aws lambda get-function --region "$REGION" --function-name "$FUNCTION_NAME" >/dev/null 2>&1; then
  aws lambda update-function-code --region "$REGION" --function-name "$FUNCTION_NAME" --zip-file "fileb://$BUILD/function.zip" >/dev/null
  aws lambda wait function-updated --region "$REGION" --function-name "$FUNCTION_NAME"
  aws lambda update-function-configuration --region "$REGION" --function-name "$FUNCTION_NAME" --environment "Variables={TICKETS_TABLE=$TICKETS_TABLE,COMMENTS_TABLE=$COMMENTS_TABLE}" --timeout 10 --memory-size 256 >/dev/null
else
  echo "Waiting for IAM role propagation..."; sleep 8
  aws lambda create-function --region "$REGION" --function-name "$FUNCTION_NAME" --runtime nodejs20.x --handler index.handler --role "$ROLE_ARN" --zip-file "fileb://$BUILD/function.zip" --timeout 10 --memory-size 256 --environment "Variables={TICKETS_TABLE=$TICKETS_TABLE,COMMENTS_TABLE=$COMMENTS_TABLE}" >/dev/null
fi
LAMBDA_ARN="$(aws lambda get-function --region "$REGION" --function-name "$FUNCTION_NAME" --query 'Configuration.FunctionArn' --output text)"

API_ID="$(aws apigatewayv2 get-apis --region "$REGION" --query "Items[?Name=='$API_NAME'].ApiId | [0]" --output text)"
if [ "$API_ID" = "None" ] || [ -z "$API_ID" ]; then
  API_ID="$(aws apigatewayv2 create-api --region "$REGION" --name "$API_NAME" --protocol-type HTTP --cors-configuration 'AllowOrigins=http://localhost:5173,AllowMethods=GET,POST,PUT,OPTIONS,AllowHeaders=authorization,content-type' --query 'ApiId' --output text)"
fi

INTEGRATION_ID="$(aws apigatewayv2 get-integrations --region "$REGION" --api-id "$API_ID" --query 'Items[0].IntegrationId' --output text)"
if [ "$INTEGRATION_ID" = "None" ] || [ -z "$INTEGRATION_ID" ]; then
  INTEGRATION_ID="$(aws apigatewayv2 create-integration --region "$REGION" --api-id "$API_ID" --integration-type AWS_PROXY --integration-uri "$LAMBDA_ARN" --payload-format-version 2.0 --query 'IntegrationId' --output text)"
fi

ISSUER="https://cognito-idp.${REGION}.amazonaws.com/${COGNITO_USER_POOL_ID}"
AUTH_ID="$(aws apigatewayv2 get-authorizers --region "$REGION" --api-id "$API_ID" --query "Items[?Name=='TicketFlowCognitoJwt'].AuthorizerId | [0]" --output text)"
if [ "$AUTH_ID" = "None" ] || [ -z "$AUTH_ID" ]; then
  AUTH_ID="$(aws apigatewayv2 create-authorizer --region "$REGION" --api-id "$API_ID" --name TicketFlowCognitoJwt --authorizer-type JWT --identity-source '$request.header.Authorization' --jwt-configuration "Audience=$COGNITO_CLIENT_ID,Issuer=$ISSUER" --query 'AuthorizerId' --output text)"
fi

create_route(){
  local key="$1"
  local id
  id="$(aws apigatewayv2 get-routes --region "$REGION" --api-id "$API_ID" --query "Items[?RouteKey=='$key'].RouteId | [0]" --output text)"
  if [ "$id" = "None" ] || [ -z "$id" ]; then
    aws apigatewayv2 create-route --region "$REGION" --api-id "$API_ID" --route-key "$key" --target "integrations/$INTEGRATION_ID" --authorization-type JWT --authorizer-id "$AUTH_ID" >/dev/null
  fi
}
create_route 'GET /tickets'
create_route 'POST /tickets'
create_route 'GET /tickets/{ticketId}'
create_route 'PUT /tickets/{ticketId}'
create_route 'GET /tickets/{ticketId}/comments'
create_route 'POST /tickets/{ticketId}/comments'

STAGE="$(aws apigatewayv2 get-stages --region "$REGION" --api-id "$API_ID" --query "Items[?StageName=='\$default'].StageName | [0]" --output text)"
if [ "$STAGE" = "None" ] || [ -z "$STAGE" ]; then
  aws apigatewayv2 create-stage --region "$REGION" --api-id "$API_ID" --stage-name '$default' --auto-deploy >/dev/null
fi

aws lambda add-permission --region "$REGION" --function-name "$FUNCTION_NAME" --statement-id TicketFlowHttpApiInvoke --action lambda:InvokeFunction --principal apigateway.amazonaws.com --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT}:${API_ID}/*/*/*" >/dev/null 2>&1 || true

API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com"
ENV_FILE="$FRONTEND/.env.local"
touch "$ENV_FILE"
if grep -q '^VITE_API_BASE_URL=' "$ENV_FILE"; then sed -i "s|^VITE_API_BASE_URL=.*|VITE_API_BASE_URL=$API_URL|" "$ENV_FILE"; else printf '\nVITE_API_BASE_URL=%s\n' "$API_URL" >> "$ENV_FILE"; fi

cat > "$PROJECT_ROOT/.backend-resource-ids" <<EOF2
AWS_REGION=$REGION
TICKETS_TABLE=$TICKETS_TABLE
COMMENTS_TABLE=$COMMENTS_TABLE
LAMBDA_FUNCTION=$FUNCTION_NAME
HTTP_API_ID=$API_ID
HTTP_API_URL=$API_URL
EOF2

echo
echo "Backend provisioned successfully."
echo "API URL: $API_URL"
echo "Restart Vite now."
