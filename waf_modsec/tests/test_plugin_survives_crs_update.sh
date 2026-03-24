#!/bin/bash
# Test: Plugin files survive CRS update and restore correctly

set -eu

IMAGE="${IMAGE:-waf_modsec:latest}"
CONTAINER_NAME="test_plugin_restore_$$"

cleanup() {
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

echo "Starting container with CRSUPDATE=true..."
docker run -d --name "$CONTAINER_NAME" \
  -e CRSUPDATE=true \
  -e CRSVERSION=4.8.0 \
  -e CRS_TARBALL_URL=https://github.com/coreruleset/coreruleset/archive/refs/tags/v4.8.0.tar.gz \
  "$IMAGE" >/dev/null

sleep 8

echo "Verifying plugin files exist after CRS update..."
docker exec "$CONTAINER_NAME" test -f /etc/modsecurity.d/owasp-crs/plugins/honeytrap-plugin-config.conf
docker exec "$CONTAINER_NAME" test -f /etc/modsecurity.d/owasp-crs/plugins/honeytrap-plugin-before.conf
docker exec "$CONTAINER_NAME" test -f /etc/modsecurity.d/owasp-crs/plugins/honeytrap-plugin-after.conf

echo "Verifying plugin content is correct..."
docker exec "$CONTAINER_NAME" grep -q "9505000" /etc/modsecurity.d/owasp-crs/plugins/honeytrap-plugin-config.conf
docker exec "$CONTAINER_NAME" grep -q "9500100" /etc/modsecurity.d/owasp-crs/plugins/honeytrap-plugin-after.conf

echo "✓ Plugin files survived CRS update"
