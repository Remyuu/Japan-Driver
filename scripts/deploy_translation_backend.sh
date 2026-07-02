#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIREBASE_CONFIG="${FIREBASE_CONFIG:-$ROOT_DIR/.firebase-config.json}"
PNPM_BIN="${PNPM_BIN:-pnpm}"

if [[ ! -f "$FIREBASE_CONFIG" ]]; then
  echo "Missing Firebase config: $FIREBASE_CONFIG" >&2
  exit 1
fi

project_id="$(jq -r '.FIREBASE_PROJECT_ID // empty' "$FIREBASE_CONFIG")"
if [[ -z "$project_id" ]]; then
  echo "FIREBASE_PROJECT_ID is missing from $FIREBASE_CONFIG" >&2
  exit 1
fi

python3 "$ROOT_DIR/scripts/generate_translation_source_hashes.py"
"$PNPM_BIN" --dir "$ROOT_DIR/functions" install --frozen-lockfile
"$PNPM_BIN" --dir "$ROOT_DIR/functions" run check
"$PNPM_BIN" --dir "$ROOT_DIR/functions" test

if command -v firebase >/dev/null 2>&1; then
  firebase deploy \
    --project "$project_id" \
    --only functions,firestore:rules
else
  "$PNPM_BIN" dlx firebase-tools deploy \
    --project "$project_id" \
    --only functions,firestore:rules
fi
