#!/usr/bin/env bash
set -euo pipefail

PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -d "./frontend/src" ]; then
  ROOT="$(pwd)"
elif [ -d "$HOME/Documents/AWS-Ticketing-System/frontend/src" ]; then
  ROOT="$HOME/Documents/AWS-Ticketing-System"
else
  echo "ERROR: Could not find AWS-Ticketing-System project root."
  echo "Run this script from the project root."
  exit 1
fi

BACKUP="$ROOT/.patch-backups/final-submission-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

if [ -f "$ROOT/README.md" ]; then
  cp "$ROOT/README.md" "$BACKUP/README.md"
fi

mkdir -p "$ROOT/docs" "$ROOT/scripts" "$ROOT/frontend"

cp "$PATCH_DIR/patch/README.md" "$ROOT/README.md"
cp "$PATCH_DIR/patch/docs/"*.md "$ROOT/docs/"
cp "$PATCH_DIR/patch/frontend/.env.example" "$ROOT/frontend/.env.example"
cp "$PATCH_DIR/scripts/build-submission.sh" "$ROOT/scripts/build-submission.sh"

chmod +x "$ROOT/scripts/build-submission.sh"

echo
echo "Final submission documentation installed."
echo "Previous README backup: $BACKUP"
echo
echo "Review:"
echo "  README.md"
echo "  docs/ARCHITECTURE.md"
echo "  docs/DEMO_SCRIPT.md"
echo "  docs/SCREENSHOT_CHECKLIST.md"
echo "  docs/TEST_CHECKLIST.md"
echo
echo "When final testing is complete, build the clean submission ZIP:"
echo "  ./scripts/build-submission.sh"
