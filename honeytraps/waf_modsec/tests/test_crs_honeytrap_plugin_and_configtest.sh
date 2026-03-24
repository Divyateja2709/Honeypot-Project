#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-waf_modsec:local}"
NAME="test-honeytrap-plugin-$RANDOM$RANDOM"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$NAME" -e CRSUPDATE=false "$IMAGE" >/dev/null
sleep 4

docker exec "$NAME" sh -lc '
  set -eu
  d="/etc/modsecurity.d/owasp-crs/plugins"
  test -d "$d"
  test -f "$d/honeytrap-plugin-config.conf"
  test -f "$d/honeytrap-plugin-before.conf"
  test -f "$d/honeytrap-plugin-after.conf"
  test -f "$d/honeytrap-plugin-generated-after.conf"
  grep -q "9500100" "$d/honeytrap-plugin-after.conf"
  apachectl configtest
'

echo "PASS: honeytrap CRS plugin files present and Apache configtest OK"
