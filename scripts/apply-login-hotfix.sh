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

BACKUP="$FRONTEND/.patch-backups/login-hotfix-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

for f in src/auth/cognito.js src/views/LoginView.vue src/style.css; do
  if [ -f "$FRONTEND/$f" ]; then
    mkdir -p "$BACKUP/$(dirname "$f")"
    cp "$FRONTEND/$f" "$BACKUP/$f"
  fi
done

cp "$PATCH_DIR/patch/src/auth/cognito.js" "$FRONTEND/src/auth/cognito.js"
cp "$PATCH_DIR/patch/src/views/LoginView.vue" "$FRONTEND/src/views/LoginView.vue"

if ! grep -q "Role-login hotfix" "$FRONTEND/src/style.css"; then
  cat "$PATCH_DIR/patch/hotfix.css" >> "$FRONTEND/src/style.css"
fi

echo
echo "Login hotfix applied."
echo "Backup: $BACKUP"
echo
echo "IMPORTANT: stop the existing Vite process and start it again."
echo "  cd \"$FRONTEND\""
echo "  npm run dev"
