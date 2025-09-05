#!/usr/bin/env bash
# sab-throttle-guard.sh
# Automatically adjusts SABnzbd speed limit based on speedtest-cli results.

set -euo pipefail

# ---- Configuration ----
SAB_HOST="YOURIP:8080"       # SABnzbd host:port
API_KEY="YOURAPIKEY"  # SABnzbd API key

THRESHOLD_MBIT=300               # Threshold in Mbit/s - results below this limit will set a limit in sabnzbd 
LIMIT_VALUE="5M"                 # Limit to apply if below threshold (SAB expects K or M, e.g. "5M")
NUM_TESTS=2                      # Number of speedtests per run
SLEEP_BETWEEN=3                  # Seconds to wait between tests

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
require_cmd() { command -v "$1" >/dev/null || { log "Missing command: $1"; exit 1; }; }

require_cmd curl
require_cmd speedtest-cli

# ---- JSON -> Mbps (speedtest-cli: "download" is bit/s) ----
json_to_mbps() {
  val="$(sed -n 's/.*"download"[[:space:]]*:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' | head -n1)"
  if [[ -n "$val" ]]; then
    awk -v v="$val" 'BEGIN{printf "%.2f\n", v/1000000.0}'   # bit/s -> Mbit/s
  else
    return 1
  fi
}

run_speedtest_cli() {
  out="$(LC_ALL=C speedtest-cli --json 2>/dev/null || true)"
  [[ -z "$out" ]] && return 1
  printf '%s' "$out" | json_to_mbps || return 1
}

# ---- Main ----
log "Starting ${NUM_TESTS} speedtests (speedtest-cli)…"
results=()
for i in $(seq 1 "$NUM_TESTS"); do
  val="$(run_speedtest_cli || true)"
  if [[ -n "${val:-}" ]]; then
    results+=("$val")
    log "Test $i: ${val} Mbit/s"
  else
    log "Test $i failed (no valid JSON output from speedtest-cli)."
  fi
  sleep "$SLEEP_BETWEEN"
done

if [[ "${#results[@]}" -ne "$NUM_TESTS" ]]; then
  log "Not all speedtests were successful → aborting without changes."
  exit 1
fi

# Check: are ALL results below the threshold?
below_threshold=1
for v in "${results[@]}"; do
  awk -v vv="$v" -v t="$THRESHOLD_MBIT" 'BEGIN{exit !(vv<t)}' || { below_threshold=0; break; }
done

if [[ "$below_threshold" -eq 1 ]]; then
  log "All results < ${THRESHOLD_MBIT} Mbit/s → applying SABnzbd limit = ${LIMIT_VALUE}…"
  resp="$(curl -sS --get \
    --data-urlencode "mode=config" \
    --data-urlencode "name=speedlimit" \
    --data-urlencode "value=${LIMIT_VALUE}" \
    --data-urlencode "apikey=${API_KEY}" \
    "http://${SAB_HOST}/sabnzbd/api")"
  log "SABnzbd response: ${resp}"
else
  log "At least one result ≥ ${THRESHOLD_MBIT} Mbit/s → removing SABnzbd limit…"
  resp="$(curl -sS --get \
    --data-urlencode "mode=config" \
    --data-urlencode "name=speedlimit" \
    --data-urlencode "value=0" \
    --data-urlencode "apikey=${API_KEY}" \
    "http://${SAB_HOST}/sabnzbd/api")"
  log "SABnzbd response: ${resp}"
fi

log "Done."
