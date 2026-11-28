#!/bin/sh
# Blocking gate over grype.json. Only findings that HAVE A FIX are considered:
#   BLOCK  known exploited (KEV) or EPSS >= EPSS_BLOCK   -> exit 1 (unless BLOCK_EXPLOITED=false)
#   WARN   EPSS >= EPSS_WARN                              -> printed, never fails
# Inputs: OUT_DIR (default .), EPSS_BLOCK (0.1), EPSS_WARN (0.01), BLOCK_EXPLOITED (true)
. "$(dirname "$0")/lib.sh"

EPSS_BLOCK=${EPSS_BLOCK:-0.1}
EPSS_WARN=${EPSS_WARN:-0.01}
BLOCK_EXPLOITED=${BLOCK_EXPLOITED:-true}
report=$OUT_DIR/grype.json
[ -f "$report" ] || die "$report not found, run scan-sbom.sh first"

# One tab-separated row per finding: LEVEL id package version fixed-in severity EPSS KEV
rows=$("$TOOLS_DIR/jq" -r --argjson b "$EPSS_BLOCK" --argjson w "$EPSS_WARN" '
  .matches[] | select(.vulnerability.fix.state == "fixed")
  | ([.vulnerability.epss[]?.epss] | max // 0) as $e
  | ((.vulnerability.knownExploited // []) | length > 0) as $k
  | (if $k or $e >= $b then "BLOCK" elif $e >= $w then "WARN" else empty end) as $level
  | [$level, .vulnerability.id, .artifact.name, .artifact.version,
     ((.vulnerability.fix.versions // []) | join(",")), .vulnerability.severity,
     ($e | tostring), (if $k then "KEV" else "-" end)] | @tsv' "$report")

blocks=$(printf '%s\n' "$rows" | grep -c '^BLOCK' || true)
warns=$(printf '%s\n' "$rows" | grep -c '^WARN' || true)

log "gate: $blocks to block, $warns warnings (fix exists and KEV or EPSS >= $EPSS_BLOCK blocks, EPSS >= $EPSS_WARN warns)"
if [ -n "$rows" ]; then
  printf 'LEVEL\tID\tPACKAGE\tVERSION\tFIXED IN\tSEVERITY\tEPSS\tKEV\n'
  printf '%s\n' "$rows" | sort
fi

if [ "$blocks" -gt 0 ] && [ "$BLOCK_EXPLOITED" = "true" ]; then
  die "$blocks finding(s) have a fix and are exploited or likely to be: update the package or the base image"
fi
