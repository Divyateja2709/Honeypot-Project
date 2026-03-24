#!/usr/bin/env bash

set -euo pipefail

IMAGE="${IMAGE:-waf_modsec:local}"
NAME="test-crs-bundled-$RANDOM$RANDOM"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$NAME" \
  -e CRSUPDATE=false \
  -e LOGSTASH_HOST=logstash:5044 \
  "$IMAGE" >/dev/null

# Wait for container initialization
sleep 3

# Verify container is still running
if ! docker ps --filter "name=$NAME" --format "{{.Names}}" | grep -q "$NAME"; then
  echo "FAIL: Container exited during startup"
  docker logs "$NAME" 2>&1 | tail -20
  exit 1
fi

docker exec "$NAME" sh -lc '
  set -eu
  CRS_DIR="/etc/modsecurity.d/owasp-crs"

  test -f /etc/modsecurity.d/include.conf
  test -f /etc/modsecurity.d/modsecurity.conf

  # include.conf expects these paths (CRS 4.x plugin chain)
  test -d "$CRS_DIR"
  test -f "$CRS_DIR/crs-setup.conf"
  test -d "$CRS_DIR/rules"
  ls -1 "$CRS_DIR"/rules/*.conf >/dev/null
  test -d "$CRS_DIR/plugins"
  test -f "$CRS_DIR/plugins/honeytrap-plugin-after.conf"
'

echo "PASS: bundled CRS exists where include.conf expects"
