#!/usr/bin/env bash
set -euo pipefail
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -d "./frontend/src" ]; then FRONTEND="$(pwd)/frontend"
elif [ -d "./src" ] && [ -f "./package.json" ]; then FRONTEND="$(pwd)"
elif [ -d "$HOME/Documents/AWS-Ticketing-System/frontend/src" ]; then FRONTEND="$HOME/Documents/AWS-Ticketing-System/frontend"
else echo "ERROR: Could not find frontend."; exit 1; fi

BACKUP="$FRONTEND/.patch-backups/aws-backend-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
for f in src/stores/support.js src/views/DashboardView.vue src/views/TicketsView.vue src/views/CreateTicketView.vue src/views/TicketDetailView.vue src/style.css; do
  if [ -f "$FRONTEND/$f" ]; then mkdir -p "$BACKUP/$(dirname "$f")"; cp "$FRONTEND/$f" "$BACKUP/$f"; fi
done
mkdir -p "$FRONTEND/src/services" "$FRONTEND/src/stores" "$FRONTEND/src/views"
cp "$PATCH_DIR/patch/src/services/api.js" "$FRONTEND/src/services/api.js"
cp "$PATCH_DIR/patch/src/stores/support.js" "$FRONTEND/src/stores/support.js"
cp "$PATCH_DIR/patch/src/views/"*.vue "$FRONTEND/src/views/"
if ! grep -q "AWS backend integration additions" "$FRONTEND/src/style.css"; then cat "$PATCH_DIR/patch/style-backend.css" >> "$FRONTEND/src/style.css"; fi
echo "Frontend AWS API patch applied."
echo "Backup: $BACKUP"
