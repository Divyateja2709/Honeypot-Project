#!/bin/sh
# Apply validated SecRule text to honeytrap-plugin-generated-after.conf and reload Apache.
# Usage: apply_honeytrap_rules.sh /path/to/rules.conf
#        cat rules.conf | apply_honeytrap_rules.sh
# Requires: apachectl, write access to CRS plugins dir (run as root in container).
set -eu

STASH="${HONEYTRAP_RULE_STASH:-/opt/honeytrap-crs-plugin}"
TARGET="/etc/modsecurity.d/owasp-crs/plugins/honeytrap-plugin-generated-after.conf"
MAX_BYTES="${HONEYTRAP_RULE_MAX_BYTES:-65536}"

log() { echo "[apply-honeytrap-rules] $*" >&2; }

if [ ! -w "$(dirname "$TARGET")" ] && [ ! -w "$TARGET" ] 2>/dev/null; then
  log "error: cannot write to $TARGET (run as root in the WAF container)"
  exit 1
fi

tmp_new="$(mktemp)"
tmp_old="$(mktemp)"
cleanup() { rm -f "$tmp_new" "$tmp_old" 2>/dev/null || true; }
trap cleanup EXIT

if [ -n "${1:-}" ]; then
  cat "$1" >"$tmp_new"
else
  cat >"$tmp_new"
fi

size="$(wc -c <"$tmp_new" | tr -d ' ')"
if [ "$size" -gt "$MAX_BYTES" ]; then
  log "error: content exceeds HONEYTRAP_RULE_MAX_BYTES=$MAX_BYTES"
  exit 1
fi

if [ -f "$TARGET" ]; then
  cp -f "$TARGET" "$tmp_old"
else
  : >"$tmp_old"
fi

cp -f "$tmp_new" "$TARGET"

if ! apachectl configtest 2>/tmp/ht_configtest.err; then
  log "apache configtest failed; restoring previous file"
  cat /tmp/ht_configtest.err >&2 || true
  cp -f "$tmp_old" "$TARGET"
  exit 1
fi

# Sync stash so a later crs_update + restore keeps this content
if [ -d "$STASH" ]; then
  cp -f "$TARGET" "${STASH}/honeytrap-plugin-generated-after.conf" 2>/dev/null || true
fi

apachectl graceful
log "applied rules to $TARGET and sent graceful reload"
exit 0
