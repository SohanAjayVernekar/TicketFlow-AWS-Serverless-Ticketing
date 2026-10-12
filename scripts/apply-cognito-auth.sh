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

BACKUP="$FRONTEND/.patch-backups/cognito-auth-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

for f in src/router/index.js src/stores/support.js src/components/AppShell.vue src/style.css; do
  if [ -f "$FRONTEND/$f" ]; then
    mkdir -p "$BACKUP/$(dirname "$f")"
    cp "$FRONTEND/$f" "$BACKUP/$f"
  fi
done

cd "$FRONTEND"
echo "Installing OIDC client..."
npm install oidc-client-ts

mkdir -p src/auth src/views src/router src/stores src/components

cp "$PATCH_DIR/patch/src/auth/cognito.js" src/auth/cognito.js
cp "$PATCH_DIR/patch/src/views/LoginView.vue" src/views/LoginView.vue
cp "$PATCH_DIR/patch/src/views/AuthCallbackView.vue" src/views/AuthCallbackView.vue
cp "$PATCH_DIR/patch/src/router/index.js" src/router/index.js
cp "$PATCH_DIR/patch/src/stores/support.js" src/stores/support.js
cp "$PATCH_DIR/patch/src/components/AppShell.vue" src/components/AppShell.vue

if ! grep -q "Cognito authentication additions" src/style.css; then
  cat "$PATCH_DIR/patch/src/style-auth.css" >> src/style.css
fi

if [ ! -f .env.local ]; then
  cp "$PATCH_DIR/patch/.env.example" .env.example
  echo
  echo "Cognito frontend patch applied, but .env.local does not exist yet."
  echo "Run ../scripts/provision-cognito.sh from the project root to create Cognito and write .env.local."
else
  echo "Existing .env.local preserved."
fi

echo
echo "Patch applied."
echo "Backup: $BACKUP"
