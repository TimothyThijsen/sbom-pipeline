#!/bin/sh
# Downloads Syft and Grype at the versions in tools.env and verifies their sha256
# BEFORE anything is unpacked or run. A wrong checksum stops the job.
. "$(dirname "$0")/lib.sh"
. "$PIPELINE_DIR/tools.env"

[ "$(uname -s)" = "Linux" ] || die "only Linux runners are supported (got $(uname -s))"
case "$(uname -m)" in
  x86_64|amd64) ;;
  *) die "only amd64 is supported (got $(uname -m)); add the arm64 checksums to tools.env first" ;;
esac

mkdir -p "$TOOLS_DIR"

fetch() { # fetch URL DESTINATION
  if command -v curl >/dev/null 2>&1; then
    curl -sSfL -o "$2" "$1"
  else
    wget -q -O "$2" "$1"
  fi
}

install_tool() { # install_tool NAME VERSION EXPECTED_SHA256
  name=$1; version=$2; expected=$3
  if [ -x "$TOOLS_DIR/$name" ] && [ "$("$TOOLS_DIR/$name" version 2>/dev/null | awk '/^Version:/ {print $2}')" = "$version" ]; then
    log "$name $version already installed"
    return
  fi
  archive="${name}_${version}_linux_amd64.tar.gz"
  log "downloading $archive"
  fetch "https://github.com/anchore/$name/releases/download/v$version/$archive" "$TOOLS_DIR/$archive"
  log "verifying sha256"
  if ! echo "$expected  $TOOLS_DIR/$archive" | sha256sum -c -; then
    rm -f "$TOOLS_DIR/$archive"   # never leave an unverified download behind
    die "checksum mismatch for $archive, refusing to use it"
  fi
  tar -xzf "$TOOLS_DIR/$archive" -C "$TOOLS_DIR" "$name"
  rm -f "$TOOLS_DIR/$archive"
  log "$name ready: $("$TOOLS_DIR/$name" version | awk '/^Version:/ {print $2}')"
}

install_tool syft  "$SYFT_VERSION"  "$SYFT_SHA256_LINUX_AMD64"
install_tool grype "$GRYPE_VERSION" "$GRYPE_SHA256_LINUX_AMD64"
