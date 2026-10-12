# Final Test Checklist

Run this checklist before submission.

## Authentication

- [ ] `/login` opens successfully
- [ ] Customer Portal opens Cognito
- [ ] Agent Portal opens Cognito
- [ ] Customer can sign in
- [ ] Agent can sign in
- [ ] Customer account cannot gain Agent access just by choosing Agent Portal
- [ ] Sign out works

## Customer

- [ ] Customer dashboard loads
- [ ] Customer sees only their tickets
- [ ] Customer can create a ticket
- [ ] Title validation works
- [ ] Description validation works
- [ ] Customer can choose priority
- [ ] Customer can choose category
- [ ] Customer can add a comment
- [ ] Customer cannot change status
- [ ] Customer cannot change assignee
- [ ] Customer cannot open another Customer's ticket

## Agent

- [ ] Agent dashboard loads
- [ ] Agent sees full ticket queue
- [ ] Search works
- [ ] Status filter works
- [ ] Priority filter works
- [ ] Agent can open Customer ticket
- [ ] Agent can change status
- [ ] Agent can change priority
- [ ] Agent can change assignee
- [ ] Agent can add a comment
- [ ] Activity timeline updates

## DynamoDB

- [ ] New ticket remains after browser refresh
- [ ] Agent update remains after refresh
- [ ] Comments remain after refresh

## S3

- [ ] Customer can select attachment
- [ ] File larger than 10 MB is rejected by UI
- [ ] Upload reaches S3 successfully
- [ ] Ticket stores attachment
- [ ] Customer can download their attachment
- [ ] Agent can download Customer attachment
- [ ] S3 bucket is not public
- [ ] Download still works after page refresh

## Error handling

- [ ] Invalid login is handled
- [ ] API error is displayed without crashing page
- [ ] Create Ticket button does not submit twice while saving
- [ ] Agent Save button indicates saving state
- [ ] Comment button indicates saving state

## UI

- [ ] Customer dashboard is distinct from Agent dashboard
- [ ] Header role badge is correct
- [ ] Navigation works
- [ ] Mobile/tablet layout remains usable
- [ ] No demo/debug messages remain
- [ ] No fake role switch remains

## Security / submission

- [ ] No AWS Secret Access Key in source files
- [ ] No Access Key committed to Git
- [ ] `.env.local` excluded from submission ZIP
- [ ] `.cognito-resource-ids` excluded
- [ ] `.backend-resource-ids` excluded
- [ ] `node_modules` excluded
- [ ] `.git` excluded
