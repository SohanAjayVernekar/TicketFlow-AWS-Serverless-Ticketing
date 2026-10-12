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
  echo "ERROR: Could not find the Vue frontend."
  echo "Run this from your AWS-Ticketing-System folder or frontend folder."
  exit 1
fi

echo "Frontend detected at: $FRONTEND"

BACKUP="$FRONTEND/.patch-backups/workflow-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

for f in src/App.vue src/main.js src/style.css; do
  if [ -f "$FRONTEND/$f" ]; then
    mkdir -p "$BACKUP/$(dirname "$f")"
    cp "$FRONTEND/$f" "$BACKUP/$f"
  fi
done

echo "Installing Vue Router and Pinia..."
cd "$FRONTEND"
npm install vue-router pinia lucide-vue-next

mkdir -p "$FRONTEND/src/router" "$FRONTEND/src/views" "$FRONTEND/src/data"

cp "$PATCH_DIR/patch/src/App.vue" "$FRONTEND/src/App.vue"
cp "$PATCH_DIR/patch/src/main.js" "$FRONTEND/src/main.js"
cp "$PATCH_DIR/patch/src/router/index.js" "$FRONTEND/src/router/index.js"
cp "$PATCH_DIR/patch/src/data/tickets.js" "$FRONTEND/src/data/tickets.js"
cp "$PATCH_DIR/patch/src/views/"*.vue "$FRONTEND/src/views/"

# Keep the existing dashboard theme and append workflow page styles.
if ! grep -q "Workflow pages" "$FRONTEND/src/style.css"; then
  cat "$PATCH_DIR/patch/src/workflow.css" >> "$FRONTEND/src/style.css"
else
  echo "Workflow CSS already exists; leaving style.css unchanged."
fi

echo
echo "Workflow patch applied successfully."
echo "Backup saved to: $BACKUP"
echo
echo "Run:"
echo "  cd \"$FRONTEND\""
echo "  npm run dev"
