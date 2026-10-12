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
  exit 1
fi

BACKUP="$FRONTEND/.patch-backups/functional-ui-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

for f in src/App.vue src/main.js src/style.css src/router/index.js; do
  if [ -f "$FRONTEND/$f" ]; then
    mkdir -p "$BACKUP/$(dirname "$f")"
    cp "$FRONTEND/$f" "$BACKUP/$f"
  fi
done

cd "$FRONTEND"
npm install vue-router pinia lucide-vue-next

mkdir -p src/router src/stores src/components src/views

cp "$PATCH_DIR/patch/src/App.vue" src/App.vue
cp "$PATCH_DIR/patch/src/main.js" src/main.js
cp "$PATCH_DIR/patch/src/style.css" src/style.css
cp "$PATCH_DIR/patch/src/router/index.js" src/router/index.js
cp "$PATCH_DIR/patch/src/stores/support.js" src/stores/support.js
cp "$PATCH_DIR/patch/src/components/AppShell.vue" src/components/AppShell.vue
cp "$PATCH_DIR/patch/src/views/"*.vue src/views/

echo
echo "Functional UI patch applied successfully."
echo "Backup: $BACKUP"
echo
echo "Run:"
echo "  cd \"$FRONTEND\""
echo "  npm run dev"
