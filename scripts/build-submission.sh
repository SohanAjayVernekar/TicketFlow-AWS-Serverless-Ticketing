#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/dist-submission"
STAGE="$OUT_DIR/AWS-Ticketing-System"
ZIP_FILE="$OUT_DIR/AWS-Ticketing-System-Submission.zip"

echo "Building clean TicketFlow submission package..."
echo "Project: $ROOT"

rm -rf "$STAGE"
mkdir -p "$STAGE"
mkdir -p "$OUT_DIR"

copy_item() {
  local src="$1"
  local dst="$2"
  if [ -e "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
  fi
}

# Copy only project-relevant content.
copy_item "$ROOT/README.md" "$STAGE/README.md"
copy_item "$ROOT/docs" "$STAGE/docs"
copy_item "$ROOT/backend" "$STAGE/backend"
copy_item "$ROOT/scripts" "$STAGE/scripts"

if [ -d "$ROOT/frontend" ]; then
  mkdir -p "$STAGE/frontend"

  for item in \
    package.json \
    package-lock.json \
    vite.config.js \
    vite.config.ts \
    index.html \
    public \
    src \
    .env.example
  do
    copy_item "$ROOT/frontend/$item" "$STAGE/frontend/$item"
  done
fi

# Defensive removal of anything sensitive or unnecessary.
find "$STAGE" -type d \( \
  -name node_modules -o \
  -name .git -o \
  -name .patch-backups -o \
  -name dist -o \
  -name .vite -o \
  -name __pycache__ \
\) -prune -exec rm -rf {} + 2>/dev/null || true

find "$STAGE" -type f \( \
  -name '.env.local' -o \
  -name '.env' -o \
  -name '.cognito-resource-ids' -o \
  -name '.backend-resource-ids' -o \
  -name 'credentials' -o \
  -name '*.pem' -o \
  -name '*.key' \
\) -delete 2>/dev/null || true

# Lightweight credential-pattern guard.
BAD=0

if grep -RIlE --exclude-dir=.git \
  'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}' "$STAGE" >/tmp/ticketflow-key-files.txt 2>/dev/null; then
  echo
  echo "ERROR: Possible AWS Access Key found in:"
  cat /tmp/ticketflow-key-files.txt
  BAD=1
fi

if grep -RIlE --exclude-dir=.git \
  'aws_secret_access_key[[:space:]]*=' "$STAGE" >/tmp/ticketflow-secret-files.txt 2>/dev/null; then
  echo
  echo "ERROR: Possible AWS secret credential configuration found in:"
  cat /tmp/ticketflow-secret-files.txt
  BAD=1
fi

rm -f /tmp/ticketflow-key-files.txt /tmp/ticketflow-secret-files.txt

if [ "$BAD" -ne 0 ]; then
  echo
  echo "Submission ZIP was NOT created."
  echo "Remove the credential material and run this script again."
  exit 1
fi

rm -f "$ZIP_FILE"

(
  cd "$OUT_DIR"
  zip -qr "$(basename "$ZIP_FILE")" "$(basename "$STAGE")"
)

echo
echo "Submission package created successfully:"
echo "  $ZIP_FILE"
echo
echo "Secret/local config files were excluded."
echo "Review the ZIP manually before sending it."
