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

BACKUP="$FRONTEND/.patch-backups/role-dashboards-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

for f in src/views/DashboardView.vue src/components/AppShell.vue src/style.css; do
  if [ -f "$FRONTEND/$f" ]; then
    mkdir -p "$BACKUP/$(dirname "$f")"
    cp "$FRONTEND/$f" "$BACKUP/$f"
  fi
done

cp "$PATCH_DIR/patch/src/views/DashboardView.vue" "$FRONTEND/src/views/DashboardView.vue"
cp "$PATCH_DIR/patch/src/components/AppShell.vue" "$FRONTEND/src/components/AppShell.vue"

if ! grep -q "Distinct Agent + Customer dashboards" "$FRONTEND/src/style.css"; then
  cat "$PATCH_DIR/patch/role-dashboards.css" >> "$FRONTEND/src/style.css"
fi

echo
echo "Role-based dashboard patch applied successfully."
echo "Backup: $BACKUP"
echo
echo "No Cognito resources are changed."
echo "The SAME Cognito login is used for both roles."
echo
echo "After login:"
echo "  Agents group -> Agent Dashboard"
echo "  everyone else -> Customer Dashboard"
echo
echo "Restart Vite:"
echo "  cd \"$FRONTEND\""
echo "  npm run dev"
