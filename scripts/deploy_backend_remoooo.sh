#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_KEY="${SSH_KEY:-/Users/remosama/project/remoooo_com/remo_mac_ssh.pem}"
REMOTE="${REMOTE:-root@remoooo.com}"
FIREBASE_CONFIG="${FIREBASE_CONFIG:-$ROOT_DIR/.firebase-config.json}"
REMOTE_ROOT="${REMOTE_ROOT:-/opt/jp-driver-api}"
NGINX_CONF="/www/server/panel/vhost/nginx/remoooo.com.conf"
NGINX_INCLUDE="/www/server/panel/vhost/nginx/jp-driver-api.inc"

if [[ ! -f "$FIREBASE_CONFIG" ]]; then
  echo "Missing Firebase config: $FIREBASE_CONFIG" >&2
  exit 1
fi

project_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["FIREBASE_PROJECT_ID"])' "$FIREBASE_CONFIG")"

ssh -i "$SSH_KEY" "$REMOTE" "mkdir -p '$REMOTE_ROOT/source' '$REMOTE_ROOT/data'"
rsync -az --delete -e "ssh -i $SSH_KEY" "$ROOT_DIR/server/" "$REMOTE:$REMOTE_ROOT/source/"
ssh -i "$SSH_KEY" "$REMOTE" "cp '$REMOTE_ROOT/source/nginx-jp-driver-api.inc' '$NGINX_INCLUDE'"

ssh -i "$SSH_KEY" "$REMOTE" bash -s -- "$REMOTE_ROOT" "$project_id" "$NGINX_CONF" "$NGINX_INCLUDE" <<'REMOTE_SCRIPT'
set -euo pipefail
remote_root="$1"
project_id="$2"
nginx_conf="$3"
nginx_include="$4"

docker build -t jp-driver-api:latest "$remote_root/source"
docker run --rm \
  -e "FIREBASE_PROJECT_ID=$project_id" \
  jp-driver-api:latest python -m unittest -v test_app.py
docker rm -f jp-driver-api >/dev/null 2>&1 || true
docker run -d \
  --name jp-driver-api \
  --restart unless-stopped \
  -p 127.0.0.1:8092:8080 \
  -v "$remote_root/data:/data" \
  -e "FIREBASE_PROJECT_ID=$project_id" \
  jp-driver-api:latest

if ! grep -Fq "include $nginx_include;" "$nginx_conf"; then
  cp "$nginx_conf" "$nginx_conf.backup-jp-driver-api-$(date +%Y%m%d%H%M%S)"
  sed -i "/include \/www\/server\/panel\/vhost\/nginx\/remo-benchmark-api.inc;/i\\    include $nginx_include;" "$nginx_conf"
fi

for _ in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:8092/health >/dev/null; then
    break
  fi
  sleep 1
done
curl -fsS http://127.0.0.1:8092/health >/dev/null
/www/server/nginx/sbin/nginx -t
/www/server/nginx/sbin/nginx -s reload
REMOTE_SCRIPT

curl -fsS https://remoooo.com/jp-driver-api/health
printf '\nBackend deployed successfully.\n'
