# Screenshot Checklist

Capture these screenshots for your report, presentation, or internship submission.

## Required

1. **Role-based TicketFlow login**
   - Customer Portal
   - Agent Portal

2. **Amazon Cognito Hosted UI**
   - Sign-in screen
   - Do not show passwords or secrets

3. **Customer dashboard**
   - Customer role badge visible
   - Ticket counters visible

4. **Create Ticket**
   - Title
   - Description
   - Priority
   - Category
   - Attachment

5. **Customer ticket detail**
   - Open status
   - Customer comment
   - Attachment

6. **Agent dashboard**
   - Agent role badge visible
   - Support queue metrics

7. **Agent ticket detail**
   - Status selector
   - Priority selector
   - Assignee selector

8. **Agent update**
   - Status `In Progress`
   - Assigned Agent
   - Agent comment

9. **Activity timeline**
   - Ticket creation
   - Comment event
   - Status/assignment event

10. **S3 attachment**
    - Attachment shown on ticket
    - Download button

## AWS console evidence

11. **Cognito User Pool**
    - Groups section showing `Agents` and/or project groups
    - Do not expose sensitive user data unnecessarily

12. **API Gateway**
    - Routes list

13. **Lambda**
    - Function overview

14. **DynamoDB**
    - TicketFlow tables

15. **S3**
    - Project attachment bucket
    - Show Block Public Access enabled

## Avoid in screenshots

Never include:

- AWS Secret Access Key
- Session token
- Password
- Full credential file
- Browser developer tools containing Authorization tokens
