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

BACKUP="$FRONTEND/.patch-backups/role-login-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

for f in src/auth/cognito.js src/views/LoginView.vue src/views/AuthCallbackView.vue src/style.css; do
  if [ -f "$FRONTEND/$f" ]; then
    mkdir -p "$BACKUP/$(dirname "$f")"
    cp "$FRONTEND/$f" "$BACKUP/$f"
  fi
done

mkdir -p "$FRONTEND/src/auth" "$FRONTEND/src/views"

cp "$PATCH_DIR/patch/src/auth/cognito.js" "$FRONTEND/src/auth/cognito.js"
cp "$PATCH_DIR/patch/src/views/LoginView.vue" "$FRONTEND/src/views/LoginView.vue"
cp "$PATCH_DIR/patch/src/views/AuthCallbackView.vue" "$FRONTEND/src/views/AuthCallbackView.vue"

if ! grep -q "Role-based login portal" "$FRONTEND/src/style.css"; then
  cat "$PATCH_DIR/patch/login-role.css" >> "$FRONTEND/src/style.css"
fi

echo
echo "Role-based login portal applied."
echo "Backup: $BACKUP"
echo
echo "Customer portal -> only non-Agent Cognito users"
echo "Agent portal    -> only users in Cognito Agents group"
echo
echo "To also restyle the AWS Cognito credential pages, run:"
echo "  ./scripts/apply-cognito-classic-branding.sh"
echo
echo "Then restart Vite."
