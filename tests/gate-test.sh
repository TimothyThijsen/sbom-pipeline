#!/bin/sh
# Self-check of the gate on a small fixture. Needs jq in $TOOLS_DIR (run scripts/install-tools.sh first).
# Expected: CVE-1 blocks (fixed + exploited), CVE-2 warns (fixed, EPSS 0.05), the other three are ignored.
set -u
cd "$(dirname "$0")/.."
export OUT_DIR=tests/fixtures TOOLS_DIR=${TOOLS_DIR:-$PWD/.tools}
fail() { echo "FAIL: $1"; exit 1; }

out=$(sh scripts/gate.sh 2>&1); rc=$?
[ "$rc" -eq 1 ] || fail "expected exit 1, got $rc"
echo "$out" | grep -q '1 to block, 1 warnings' || fail "wrong counts: $out"
echo "$out" | grep -q 'BLOCK.*CVE-1' || fail "CVE-1 should block"
echo "$out" | grep -q 'WARN.*CVE-2' || fail "CVE-2 should warn"
echo "$out" | grep -qE 'CVE-3|CVE-4|CVE-5' && fail "CVE-3/4/5 should be ignored"

out=$(BLOCK_EXPLOITED=false sh scripts/gate.sh 2>&1); rc=$?
[ "$rc" -eq 0 ] || fail "BLOCK_EXPLOITED=false should exit 0, got $rc"

out=$(EPSS_BLOCK=0.04 sh scripts/gate.sh 2>&1)
echo "$out" | grep -q '2 to block' || fail "EPSS_BLOCK=0.04 should block CVE-2 too"
echo "gate tests passed"
