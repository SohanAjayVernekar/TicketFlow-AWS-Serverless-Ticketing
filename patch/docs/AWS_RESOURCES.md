# AWS Resources

This project uses the following AWS resource types.

## Amazon Cognito

Purpose:

- User sign up/sign in
- Hosted UI
- JWT issuance
- Role group claims

Groups:

```text
Customers
Agents
```

Agent users are added to `Agents` by an administrator.

## API Gateway HTTP API

Protected routes:

```text
POST /tickets
GET  /tickets
GET  /tickets/{ticketId}
PUT  /tickets/{ticketId}
GET  /tickets/{ticketId}/comments
POST /tickets/{ticketId}/comments
POST /tickets/presigned-url
```

Authorization:

```text
JWT authorizer using the Cognito User Pool issuer and app client audience
```

## AWS Lambda

Runtime:

```text
Node.js 20
```

Responsibilities:

- Read authenticated Cognito claims
- Determine Customer vs Agent role
- Enforce ticket ownership
- Create/list/get/update tickets
- Create/list comments
- Generate S3 presigned upload/download URLs

## DynamoDB

Tables:

```text
TicketFlowTickets
TicketFlowComments
```

The tickets table includes a Customer lookup index:

```text
customerId-createdAt-index
```

## Amazon S3

Purpose:

- Private ticket attachments

Security:

- Block Public Access enabled
- Lambda role can access attachment objects
- Browser uses short-lived presigned URLs
- Direct S3 upload avoids sending binary files through Lambda

## IAM

Lambda execution role requires:

- CloudWatch logging
- DynamoDB read/write for project tables
- S3 `PutObject` and `GetObject` for the attachment prefix

## CloudWatch

Lambda logs are available in CloudWatch Logs and are useful when troubleshooting API failures.

## Local configuration files

The provisioning scripts can generate local resource-id files such as:

```text
.cognito-resource-ids
.backend-resource-ids
frontend/.env.local
```

These are local configuration artifacts and should **not** be included in a public repository or submission ZIP when they contain environment-specific identifiers or sensitive values.
