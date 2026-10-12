# Demo Script

A short 5–7 minute demonstration.

## 1. Introduce the project

> TicketFlow is a serverless AWS support ticketing system built with Vue 3. It has separate Customer and Agent experiences, Cognito authentication, Lambda APIs, DynamoDB persistence, and private S3 attachments.

## 2. Show role-based login

Open:

```text
http://localhost:5173/login
```

Point out:

- Customer Portal
- Agent Portal
- Amazon Cognito handles the actual authentication
- Role access is verified from Cognito groups

## 3. Customer demonstration

Sign in with a Customer account.

Show:

- Customer dashboard
- My Tickets
- Active / Resolved / Awaiting Agent counts

Create a ticket:

```text
Title: Invoice PDF is not opening after download

Description:
I downloaded the invoice from my account, but the PDF file is not opening correctly. I tried downloading it again and also tested another browser, but the same issue occurs. Please check the generated invoice file and help me resolve this issue.

Priority: High
Category: Billing
```

Attach the sample PDF or another small test file.

Point out the upload stages:

```text
Preparing secure upload…
Uploading attachment to S3…
Creating ticket…
```

Open the created ticket.

Add Customer comment:

> I tried downloading the invoice again after refreshing the page, but the PDF still does not open. I have attached a sample file for reference.

## 4. Agent demonstration

Sign out.

Sign in through Agent Portal with a user in the Cognito `Agents` group.

Show:

- Agent dashboard
- Full support queue
- Active tickets
- Unassigned tickets
- Queue health

Open the Customer ticket.

Set:

```text
Status: In Progress
Priority: High
Assignee: Aarav Shah
```

Add Agent comment:

> I reviewed the attachment and the invoice issue. I am checking the generated PDF and download process to identify why the document is unreadable. I will update the ticket once the issue is resolved.

Save changes.

## 5. Attachment security

Click Download on the attachment.

Explain:

> The S3 bucket is private. Lambda first checks that the signed-in user can access the ticket and then returns a temporary presigned download URL.

## 6. Return to Customer

Sign out and return to the Customer account.

Show that the Customer can now see:

- `In Progress`
- Assigned Agent
- Agent reply
- Activity timeline

## 7. Explain the architecture

Use `docs/ARCHITECTURE.md`.

Short explanation:

> Vue authenticates through Cognito and sends the JWT to API Gateway. API Gateway validates the token and forwards the request to Lambda. Lambda applies role and ownership checks, stores ticket data in DynamoDB, and creates temporary S3 URLs for attachments.

## 8. Close

> This POC demonstrates a complete serverless Customer-to-Agent support workflow while keeping authentication, authorization, database storage, APIs, and file storage within AWS managed services.
