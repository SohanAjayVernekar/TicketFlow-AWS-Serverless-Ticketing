TicketFlow Final Submission Patch

Adds:
- polished README.md
- architecture documentation with Mermaid diagrams
- AWS resource documentation
- final test checklist
- screenshot checklist
- 5–7 minute demo script
- safe frontend/.env.example
- build-submission.sh

The submission builder intentionally excludes:
- .env.local
- .cognito-resource-ids
- .backend-resource-ids
- node_modules
- .git
- .patch-backups
- build caches
- common key/credential files

It also checks for common AWS Access Key patterns before creating the final ZIP.

Apply:

  cd "$HOME/Documents/AWS-Ticketing-System"
  unzip -o ~/Downloads/AWS_Ticketing_Final_Submission_Patch.zip -d .
  chmod +x scripts/*.sh
  ./scripts/apply-final-submission.sh

After final testing:

  ./scripts/build-submission.sh

Final ZIP:

  dist-submission/AWS-Ticketing-System-Submission.zip
