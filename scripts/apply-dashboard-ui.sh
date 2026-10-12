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
  echo "Run this script from your AWS-Ticketing-System folder or frontend folder."
  exit 1
fi

echo "Frontend detected at: $FRONTEND"

BACKUP="$FRONTEND/.patch-backups/dashboard-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

for f in src/App.vue src/style.css src/main.js; do
  if [ -f "$FRONTEND/$f" ]; then
    mkdir -p "$BACKUP/$(dirname "$f")"
    cp "$FRONTEND/$f" "$BACKUP/$f"
  fi
done

echo "Installing dashboard icon dependency..."
cd "$FRONTEND"
npm install lucide-vue-next

echo "Applying dashboard UI..."
cp "$PATCH_DIR/patch/src/App.vue" "$FRONTEND/src/App.vue"
cp "$PATCH_DIR/patch/src/style.css" "$FRONTEND/src/style.css"
cp "$PATCH_DIR/patch/src/main.js" "$FRONTEND/src/main.js"

echo
echo "Dashboard patch applied successfully."
echo "Backup saved to: $BACKUP"
echo
echo "Now run:"
echo "  cd \"$FRONTEND\""
echo "  npm run dev"
