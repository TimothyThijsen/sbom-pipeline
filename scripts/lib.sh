#!/bin/sh
# Shared helpers. Sourced by the other scripts, never run on its own.
# POSIX sh on purpose: the GitLab jobs may run in a minimal (Alpine/busybox) image without bash.

set -eu

# Folder of the pipeline repo itself (where tools.env lives), wherever it is checked out.
PIPELINE_DIR=$(cd "$(dirname "$0")/.." && pwd)

# Where downloaded tools are kept, and where results are written.
TOOLS_DIR=${TOOLS_DIR:-$PWD/.tools}
OUT_DIR=${OUT_DIR:-.}

log() { printf '== %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# require VAR_NAME: stop with a clear message when an input is missing.
require() {
  eval "value=\${$1:-}"
  [ -n "$value" ] || die "missing input: $1"
}
