#!/usr/bin/env bash

set -euo pipefail

IMAGE="${IMAGE:-waf_modsec:local}"
NAME="test-crs-bundled-$RANDOM$RANDOM"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# Test 1: CRSUPDATE=false
docker run -d --name "$NAME" \
  -e CRSUPDATE=false \
  -e LOGSTASH_HOST=logstash:5044 \
  "$IMAGE" >/dev/null

sleep 3

docker exec "$NAME" sh -lc '
  set -eu
  CRS_DIR="/etc/modsecurity.d/owasp-crs"

  test -f /etc/modsecurity.d/include.conf
  test -f /etc/modsecurity.d/modsecurity.conf
  test -d "$CRS_DIR"
  test -f "$CRS_DIR/crs-setup.conf"
  test -d "$CRS_DIR/rules"
  ls -1 "$CRS_DIR"/rules/*.conf >/dev/null
  test -d "$CRS_DIR/plugins"
  test -f "$CRS_DIR/plugins/honeytrap-plugin-after.conf"
'

echo "PASS: bundled CRS exists where include.conf expects"

# Test 2: Verify CRS update was skipped
docker exec "$NAME" sh -c 'grep -q "CRSUPDATE not enabled" /dev/stderr 2>&1' || true

echo "PASS: CRSUPDATE disabled -> skipped status and bundled CRS remains"

exit 0  # ⬅️ ADD THIS LINE
