AWS Ticketing System - Real S3 Attachments Patch

This is the real attachment stage.

Architecture:

Vue
  -> POST /tickets/presigned-url
  -> Lambda creates a short-lived signed S3 PUT URL
  -> Browser uploads file DIRECTLY to private S3
  -> POST /tickets stores attachmentKey + attachmentName in DynamoDB

When Customer or Agent opens a ticket:
  -> GET /tickets/{ticketId}
  -> Lambda checks role / ownership
  -> Lambda creates a short-lived signed S3 GET URL
  -> Download button uses that temporary URL

Security:
- Bucket public access is fully blocked.
- Upload endpoint requires Cognito JWT.
- Customer ticket creation only accepts attachment keys under that user's Cognito sub prefix.
- Customer download access still depends on ticket ownership.
- Agent can view/download attachments for all tickets.
- Signed URLs expire after 15 minutes.
- UI accepts attachments up to 10 MB.

Apply:

  cd "$HOME/Documents/AWS-Ticketing-System"
  unzip -o ~/Downloads/AWS_Ticketing_S3_Attachments_Patch.zip -d .
  chmod +x scripts/*.sh

  ./scripts/apply-s3-attachments.sh
  ./scripts/provision-s3-attachments.sh

Then restart Vite:

  cd frontend
  npm run dev

Test:
1. Sign in as Customer.
2. Create a ticket.
3. Select a small PDF/image/text file.
4. Submit.
5. Watch:
   Preparing secure upload...
   Uploading attachment to S3...
   Creating ticket...
6. Open the new ticket.
7. Click Download.
8. Sign in as Agent.
9. Open the same customer ticket.
10. Confirm Agent can also download it.

The bucket remains private. Do not make it public.
