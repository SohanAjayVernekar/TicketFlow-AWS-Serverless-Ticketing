#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"
PATCH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend"
BACKUP_DIR="$ROOT_DIR/.patch-backups/bootstrap-$(date +%Y%m%d-%H%M%S)"

echo "== AWS Ticketing System bootstrap patch =="
echo "Project root: $ROOT_DIR"

if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm is not installed or not in PATH."
  exit 1
fi

if [ ! -f "$FRONTEND_DIR/package.json" ]; then
  echo "Creating Vue 3 + Vite frontend..."
  npm create vite@latest frontend -- --template vue
fi

mkdir -p "$ROOT_DIR/backend/functions" "$ROOT_DIR/backend/lib" "$ROOT_DIR/docs" "$BACKUP_DIR"

cd "$FRONTEND_DIR"
echo "Installing frontend packages..."
npm install
npm install vue-router pinia lucide-vue-next chart.js vue-chartjs tailwindcss @tailwindcss/vite

for f in vite.config.js src/App.vue src/style.css src/main.js; do
  if [ -f "$FRONTEND_DIR/$f" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$f")"
    cp "$FRONTEND_DIR/$f" "$BACKUP_DIR/$f"
  fi
done

cp "$PATCH_DIR/patch-files/vite.config.js" "$FRONTEND_DIR/vite.config.js"
cp "$PATCH_DIR/patch-files/src/App.vue" "$FRONTEND_DIR/src/App.vue"
cp "$PATCH_DIR/patch-files/src/style.css" "$FRONTEND_DIR/src/style.css"
cp "$PATCH_DIR/patch-files/src/main.js" "$FRONTEND_DIR/src/main.js"

if [ ! -f "$ROOT_DIR/backend/package.json" ]; then
  cat > "$ROOT_DIR/backend/package.json" <<'JSON'
{
  "name": "aws-ticketing-backend",
  "version": "1.0.0",
  "private": true,
  "type": "module"
}
JSON
fi

cd "$ROOT_DIR"
echo
echo "Patch applied successfully."
echo "Backup (if files existed): $BACKUP_DIR"
echo
echo "Next run:"
echo "  cd \"$FRONTEND_DIR\""
echo "  npm run dev"
