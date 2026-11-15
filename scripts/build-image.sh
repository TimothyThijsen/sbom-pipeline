#!/bin/sh
# Builds the Docker image and saves it as image.tar so later steps can read it from disk.
# Inputs (environment variables):
#   IMAGE_NAME   name of the image, e.g. the project name           (required)
#   IMAGE_TAG    tag, normally the short commit SHA                  (required)
#   CONTEXT      Docker build context folder                         (default: .)
#   DOCKERFILE   path to the Dockerfile                              (default: $CONTEXT/Dockerfile)
#   OUT_DIR      where image.tar is written                          (default: .)
. "$(dirname "$0")/lib.sh"

require IMAGE_NAME
require IMAGE_TAG
CONTEXT=${CONTEXT:-.}
DOCKERFILE=${DOCKERFILE:-$CONTEXT/Dockerfile}

mkdir -p "$OUT_DIR"
log "Project: $IMAGE_NAME  Commit: $IMAGE_TAG  Dockerfile: $DOCKERFILE"
docker build -t "$IMAGE_NAME:$IMAGE_TAG" -f "$DOCKERFILE" "$CONTEXT"
docker save "$IMAGE_NAME:$IMAGE_TAG" > "$OUT_DIR/image.tar"
log "saved $OUT_DIR/image.tar"
