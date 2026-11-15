#!/bin/sh
# Generates a CycloneDX 1.6 SBOM from image.tar with Syft.
# Inputs: IMAGE_NAME, IMAGE_TAG (required, they name the build inside the SBOM); OUT_DIR (default: .)
. "$(dirname "$0")/lib.sh"

require IMAGE_NAME
require IMAGE_TAG
[ -f "$OUT_DIR/image.tar" ] || die "$OUT_DIR/image.tar not found, run build-image.sh first"

"$TOOLS_DIR/syft" --from docker-archive "$OUT_DIR/image.tar" \
  --source-name "$IMAGE_NAME" --source-version "$IMAGE_TAG" \
  -o "cyclonedx-json@1.6=$OUT_DIR/sbom.cdx.json"
log "wrote $OUT_DIR/sbom.cdx.json"
