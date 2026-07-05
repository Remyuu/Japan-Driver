#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/Users/remosama/development/flutter/bin/flutter}"
SSH_KEY="${SSH_KEY:-/Users/remosama/project/remoooo_com/remo_mac_ssh.pem}"
REMOTE="${REMOTE:-root@remoooo.com}"
REMOTE_DIR="${REMOTE_DIR:-/usr/local/lighthouse/softwares/wordpress/jp-driver}"
FIREBASE_CONFIG="${FIREBASE_CONFIG:-$ROOT_DIR/.firebase-config.json}"

build_args=(--release --base-href /jp-driver/)
has_firebase_args=false

for arg in "$@"; do
  if [[ "$arg" == --dart-define* ]]; then
    has_firebase_args=true
    break
  fi
done

if [[ -f "$FIREBASE_CONFIG" ]]; then
  build_args+=(--dart-define-from-file="$FIREBASE_CONFIG")
elif [[ "$has_firebase_args" == false ]]; then
  echo "Missing Firebase config: $FIREBASE_CONFIG" >&2
  echo "Create it from .firebase-config.example.json before deploying." >&2
  exit 1
fi

python3 "$ROOT_DIR/scripts/generate_question_bank_manifest.py"
"$FLUTTER_BIN" build web "${build_args[@]}" "$@"

ssh -i "$SSH_KEY" "$REMOTE" "mkdir -p '$REMOTE_DIR'"
rsync -az --delete -e "ssh -i $SSH_KEY" "$ROOT_DIR/build/web/" "$REMOTE:$REMOTE_DIR/"
ssh -i "$SSH_KEY" "$REMOTE" "chown -R www:www '$REMOTE_DIR' && /www/server/nginx/sbin/nginx -t && /www/server/nginx/sbin/nginx -s reload"
