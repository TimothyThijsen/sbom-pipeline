#!/bin/sh
# Scans the SBOM with Grype. Prints a table, writes grype.json, then prints which database was used.
# Inputs:
#   OUT_DIR   where sbom.cdx.json is and grype.json is written     (default: .)
#   FAIL_ON   severity that fails the job: low|medium|high|critical (default: empty = only report)
. "$(dirname "$0")/lib.sh"

[ -f "$OUT_DIR/sbom.cdx.json" ] || die "$OUT_DIR/sbom.cdx.json not found, run generate-sbom.sh first"

if [ -n "${FAIL_ON:-}" ]; then
  log "blocking on severity >= $FAIL_ON"
  set -- --fail-on "$FAIL_ON"
else
  log "report only (FAIL_ON is empty)"
  set --
fi

# Do not stop here when Grype exits non-zero: the database status must still be printed.
# The exit code is returned at the end, so a blocking rule still fails the job.
status=0
"$TOOLS_DIR/grype" "sbom:$OUT_DIR/sbom.cdx.json" -o table -o "json=$OUT_DIR/grype.json" "$@" || status=$?

# The database is only downloaded during the scan, so this must come after it.
"$TOOLS_DIR/grype" db status || true

# The blocking gate (fixable and exploited findings) runs last, so its message is the last thing in the log.
gate=0
sh "$(dirname "$0")/gate.sh" || gate=$?
[ "$status" -eq 0 ] || exit "$status"
exit "$gate"
