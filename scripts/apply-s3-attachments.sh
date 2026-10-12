#!/usr/bin/env bash
set -euo pipefail

PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -d "./frontend/src" ]; then
  FRONTEND="$(pwd)/frontend"
elif [ -d "./src" ] && [ -f "./package.json" ]; then
  FRONTEND="$(pwd)"
elif [ -d "$HOME/Documents/AWS-Ticketing-System/frontend/src" ]; then
  FRONTEND="$HOME/Documents/AWS-Ticketing-System/frontend"
else
  echo "ERROR: Could not find frontend."
  exit 1
fi

BACKUP="$FRONTEND/.patch-backups/s3-attachments-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

for f in \
  src/services/api.js \
  src/stores/support.js \
  src/views/CreateTicketView.vue \
  src/views/TicketDetailView.vue \
  src/style.css
do
  if [ -f "$FRONTEND/$f" ]; then
    mkdir -p "$BACKUP/$(dirname "$f")"
    cp "$FRONTEND/$f" "$BACKUP/$f"
  fi
done

cp "$PATCH_DIR/patch/src/services/api.js" "$FRONTEND/src/services/api.js"
cp "$PATCH_DIR/patch/src/stores/support.js" "$FRONTEND/src/stores/support.js"
cp "$PATCH_DIR/patch/src/views/CreateTicketView.vue" "$FRONTEND/src/views/CreateTicketView.vue"
cp "$PATCH_DIR/patch/src/views/TicketDetailView.vue" "$FRONTEND/src/views/TicketDetailView.vue"

if ! grep -q "S3 attachment stage" "$FRONTEND/src/style.css"; then
  cat "$PATCH_DIR/patch/s3-attachments.css" >> "$FRONTEND/src/style.css"
fi

cp "$PATCH_DIR/backend/lambda/index.js" "$PATCH_DIR/../backend/lambda/index.js" 2>/dev/null || true

PROJECT_ROOT="$(cd "$FRONTEND/.." && pwd)"
mkdir -p "$PROJECT_ROOT/backend/lambda"
cp "$PATCH_DIR/backend/lambda/index.js" "$PROJECT_ROOT/backend/lambda/index.js"

echo
echo "S3 frontend + Lambda source patch applied."
echo "Backup: $BACKUP"
echo
echo "Now run:"
echo "  cd \"$PROJECT_ROOT\""
echo "  ./scripts/provision-s3-attachments.sh"
